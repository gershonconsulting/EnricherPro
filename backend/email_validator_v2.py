"""Reliable, conservative email validation for EnricherPro.

The validator deliberately separates a confirmed rejection from an
inconclusive network result. SMTP servers commonly tarp-pit, rate-limit, or
accept every recipient, so an SMTP timeout must never be reported as invalid.
"""

from __future__ import annotations

import re
import secrets
import smtplib
import socket
from dataclasses import asdict, dataclass, field
from typing import Any, Dict, List, Optional, Tuple

import dns.exception
import dns.resolver
import requests

from config import (
    ENABLE_SMTP_CHECK,
    NEVERBOUNCE_API_KEY,
    SMTP_TIMEOUT_SECONDS,
    ZEROBOUNCE_API_KEY,
)

EMAIL_RE = re.compile(
    r"^(?=.{1,254}$)(?=.{1,64}@)[A-Z0-9!#$%&'*+/=?^_`{|}~-]+"
    r"(?:\.[A-Z0-9!#$%&'*+/=?^_`{|}~-]+)*@"
    r"(?:[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?\.)+[A-Z]{2,63}$",
    re.IGNORECASE,
)

ROLE_BASED_PREFIXES = {
    "abuse", "admin", "billing", "careers", "contact", "help", "hello",
    "hr", "info", "jobs", "legal", "marketing", "media", "newsletter",
    "no-reply", "noreply", "postmaster", "press", "privacy", "sales",
    "security", "support", "team", "webmaster",
}

DISPOSABLE_DOMAINS = {
    "dispostable.com", "fakeinbox.com", "getnada.com", "guerrillamail.com",
    "guerrillamailblock.com", "maildrop.cc", "mailinator.com", "mailnull.com",
    "mytemp.email", "sharklasers.com", "spam4.me", "tempmail.com",
    "throwam.com", "trashmail.com", "yopmail.com",
}


@dataclass
class ValidationResult:
    is_valid: bool = False
    status: str = "unknown"  # valid | invalid | risky | unknown
    score: float = 0.0
    layers_passed: List[str] = field(default_factory=list)
    layers_failed: List[str] = field(default_factory=list)
    details: Dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> Dict[str, Any]:
        data = asdict(self)
        data["score"] = round(self.score, 3)
        return data


def validate_email(email: str) -> ValidationResult:
    result = ValidationResult()
    normalized = str(email or "").strip().lower()
    result.details["email"] = normalized

    if not EMAIL_RE.fullmatch(normalized):
        return _invalid(result, "syntax", "Email address has an invalid format")
    result.layers_passed.append("syntax")

    local_part, domain = normalized.rsplit("@", 1)
    if local_part in ROLE_BASED_PREFIXES:
        result.details["role_based"] = True
        result.details["warning"] = "Role-based mailbox"
    else:
        result.layers_passed.append("not_role_based")

    if domain in DISPOSABLE_DOMAINS:
        return _invalid(result, "disposable", "Disposable email provider")
    result.layers_passed.append("not_disposable")

    mx_hosts, dns_state, dns_message = _resolve_mx(domain)
    if dns_state == "invalid":
        return _invalid(result, "dns_mx", dns_message)
    if dns_state == "unknown":
        result.layers_failed.append("dns_mx")
        result.details["dns_error"] = dns_message
        result.status = "unknown"
        result.score = 0.25
        return result

    result.layers_passed.append("dns_mx")
    result.details["mx_records"] = mx_hosts[:5]

    if ENABLE_SMTP_CHECK:
        smtp_state, smtp_detail = _verify_across_mx(normalized, mx_hosts)
        result.details["smtp"] = smtp_detail
        if smtp_state == "invalid":
            return _invalid(result, "smtp", "Recipient rejected by mail server")
        if smtp_state == "valid":
            result.layers_passed.append("smtp")
        else:
            result.layers_failed.append("smtp_inconclusive")
    else:
        smtp_state = "skipped"
        result.details["smtp"] = {"state": "skipped"}

    catch_all: Optional[bool] = None
    if ENABLE_SMTP_CHECK and smtp_state in {"valid", "unknown"}:
        catch_all = _detect_catch_all(domain, mx_hosts)
    result.details["catch_all"] = catch_all

    external = _external_validation(normalized)
    if external:
        result.details["external_validator"] = external
        if external["state"] == "invalid":
            return _invalid(result, "external_validator", "Rejected by validation provider")
        if external["state"] == "valid":
            result.layers_passed.append("external_validator")

    if catch_all is True:
        result.status = "risky"
        result.is_valid = True
        result.score = 0.55
        result.details["reason"] = "Domain accepts unrecognized recipients"
    elif smtp_state == "valid" or (external and external["state"] == "valid"):
        result.status = "valid"
        result.is_valid = True
        result.score = 0.96 if external and external["state"] == "valid" else 0.9
        result.details["reason"] = "Mailbox accepted by mail server"
    elif smtp_state in {"unknown", "skipped"}:
        result.status = "unknown"
        result.is_valid = False
        result.score = 0.65
        result.details["reason"] = "Domain can receive email; mailbox could not be confirmed"
    return result


def _invalid(result: ValidationResult, layer: str, reason: str) -> ValidationResult:
    result.status = "invalid"
    result.is_valid = False
    result.score = 0.0
    result.layers_failed.append(layer)
    result.details["reason"] = reason
    return result


def _resolve_mx(domain: str) -> Tuple[List[str], str, str]:
    resolver = dns.resolver.Resolver()
    resolver.timeout = min(3.0, float(SMTP_TIMEOUT_SECONDS))
    resolver.lifetime = min(5.0, float(SMTP_TIMEOUT_SECONDS))
    try:
        answers = resolver.resolve(domain, "MX")
        ordered = sorted(answers, key=lambda record: int(record.preference))
        hosts = [str(record.exchange).rstrip(".") for record in ordered]
        if not hosts or hosts == [""]:
            return [], "invalid", "Domain publishes a null MX record"
        return hosts, "valid", ""
    except (dns.resolver.NXDOMAIN, dns.resolver.NoAnswer):
        return [], "invalid", "Domain has no usable MX records"
    except (dns.exception.Timeout, dns.resolver.NoNameservers) as exc:
        return [], "unknown", f"DNS lookup was inconclusive: {exc.__class__.__name__}"
    except Exception as exc:
        return [], "unknown", f"DNS lookup failed: {exc.__class__.__name__}"


def _verify_across_mx(email: str, mx_hosts: List[str]) -> Tuple[str, Dict[str, Any]]:
    responses: List[Dict[str, Any]] = []
    for host in mx_hosts[:3]:
        state, code, message = _smtp_rcpt(host, email)
        responses.append({"host": host, "state": state, "code": code, "message": message})
        if state in {"valid", "invalid"}:
            return state, {"state": state, "attempts": responses}
    return "unknown", {"state": "unknown", "attempts": responses}


def _smtp_rcpt(host: str, recipient: str) -> Tuple[str, Optional[int], str]:
    try:
        with smtplib.SMTP(timeout=SMTP_TIMEOUT_SECONDS) as smtp:
            smtp.connect(host, 25)
            smtp.ehlo_or_helo_if_needed()
            smtp.mail("verify@enricherpro.com")
            code, raw_message = smtp.rcpt(recipient)
        message = raw_message.decode("utf-8", "replace")[:240]
        if code in {250, 251, 252}:
            return "valid", code, message
        if code in {550, 551, 553}:
            return "invalid", code, message
        return "unknown", code, message
    except (socket.timeout, TimeoutError, smtplib.SMTPServerDisconnected):
        return "unknown", None, "Mail server did not provide a conclusive response"
    except (OSError, smtplib.SMTPException) as exc:
        return "unknown", None, exc.__class__.__name__


def _detect_catch_all(domain: str, mx_hosts: List[str]) -> Optional[bool]:
    probe = f"enricherpro-{secrets.token_hex(8)}@{domain}"
    saw_conclusive = False
    for host in mx_hosts[:2]:
        state, _, _ = _smtp_rcpt(host, probe)
        if state == "valid":
            return True
        if state == "invalid":
            saw_conclusive = True
            return False
    return False if saw_conclusive else None


def _external_validation(email: str) -> Optional[Dict[str, Any]]:
    try:
        if ZEROBOUNCE_API_KEY:
            response = requests.get(
                "https://api.zerobounce.net/v2/validate",
                params={"api_key": ZEROBOUNCE_API_KEY, "email": email},
                timeout=10,
            )
            response.raise_for_status()
            payload = response.json()
            status = payload.get("status", "unknown")
            state = "valid" if status == "valid" else "invalid" if status == "invalid" else "unknown"
            return {"provider": "zerobounce", "state": state, "status": status}
        if NEVERBOUNCE_API_KEY:
            response = requests.get(
                "https://api.neverbounce.com/v4/single/check",
                params={"key": NEVERBOUNCE_API_KEY, "email": email},
                timeout=10,
            )
            response.raise_for_status()
            payload = response.json()
            status = payload.get("result", "unknown")
            state = "valid" if status == "valid" else "invalid" if status == "invalid" else "unknown"
            return {"provider": "neverbounce", "state": state, "status": status}
    except (requests.RequestException, ValueError):
        return {"provider": "configured", "state": "unknown", "status": "unavailable"}
    return None
