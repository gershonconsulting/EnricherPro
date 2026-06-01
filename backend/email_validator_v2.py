"""
email_validator_v2.py — EnricherPro v5.0
7-layer email validation pipeline:
  1. Syntax check
    2. DNS / MX record lookup
      3. Role-based address detection
        4. Disposable domain check
          5. SMTP verification
            6. Catch-all domain detection
              7. ZeroBounce / NeverBounce AI scoring (if keys configured)
              """

import re
import dns.resolver
import smtplib
import socket
import requests
from typing import Dict, Any, List
from config import (
    ZEROBOUNCE_API_KEY,
    NEVERBOUNCE_API_KEY,
    ENABLE_SMTP_CHECK,
    SMTP_TIMEOUT_SECONDS,
)

# ── Layer 3: Role-based prefixes ───────────────────────────────────────────────
ROLE_BASED_PREFIXES = {
      "admin", "info", "support", "sales", "contact", "hello", "help",
      "noreply", "no-reply", "postmaster", "webmaster", "billing",
      "hr", "jobs", "careers", "press", "media", "legal", "abuse",
      "security", "privacy", "marketing", "newsletter", "team",
}

# ── Layer 4: Disposable domain list (sample — extend as needed) ────────────────
DISPOSABLE_DOMAINS = {
      "mailinator.com", "guerrillamail.com", "tempmail.com", "throwam.com",
      "yopmail.com", "sharklasers.com", "guerrillamailblock.com",
      "trashmail.com", "maildrop.cc", "dispostable.com", "fakeinbox.com",
      "getnada.com", "mailnull.com", "spam4.me", "mytemp.email",
}


class ValidationResult:
      def __init__(self):
                self.is_valid: bool = False
                self.status: str = "unknown"   # valid | invalid | catch_all | unknown
        self.score: float = 0.0        # 0.0–1.0 confidence
        self.layers_passed: List[str] = []
        self.layers_failed: List[str] = []
        self.details: Dict[str, Any] = {}

    def to_dict(self) -> Dict[str, Any]:
              return {
                            "is_valid": self.is_valid,
                            "status": self.status,
                            "score": round(self.score, 3),
                            "layers_passed": self.layers_passed,
                            "layers_failed": self.layers_failed,
                            "details": self.details,
              }


def validate_email(email: str) -> ValidationResult:
      """Run all 7 validation layers and return a ValidationResult."""
    result = ValidationResult()
    email = email.strip().lower()

    # ── Layer 1: Syntax ────────────────────────────────────────────────────────
    syntax_pattern = r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$'
    if not re.match(syntax_pattern, email):
              result.layers_failed.append("syntax")
              result.status = "invalid"
              result.details["syntax_error"] = "Email does not match valid format"
              return result
          result.layers_passed.append("syntax")

    local_part, domain = email.rsplit("@", 1)

    # ── Layer 2: DNS / MX record ───────────────────────────────────────────────
    try:
              mx_records = dns.resolver.resolve(domain, "MX")
              mx_hosts = [str(r.exchange).rstrip(".") for r in mx_records]
              result.layers_passed.append("dns_mx")
              result.details["mx_records"] = mx_hosts[:3]
except Exception as e:
        result.layers_failed.append("dns_mx")
        result.status = "invalid"
        result.details["dns_error"] = str(e)
        return result

    # ── Layer 3: Role-based ────────────────────────────────────────────────────
    if local_part in ROLE_BASED_PREFIXES:
              result.layers_failed.append("role_based")
              result.details["role_based"] = True
              result.status = "invalid"
              return result
          result.layers_passed.append("role_based")

    # ── Layer 4: Disposable ────────────────────────────────────────────────────
    if domain in DISPOSABLE_DOMAINS:
              result.layers_failed.append("disposable")
              result.status = "invalid"
              result.details["disposable"] = True
              return result
          result.layers_passed.append("disposable")

    # ── Layer 5: SMTP verification ─────────────────────────────────────────────
    catch_all = False
    if ENABLE_SMTP_CHECK and mx_hosts:
              try:
                            smtp_valid, is_catch_all = _smtp_verify(email, mx_hosts[0])
                            if is_catch_all:
                                              catch_all = True
                                              result.layers_passed.append("smtp")
                                              result.details["smtp_catch_all"] = True
    elif smtp_valid:
                result.layers_passed.append("smtp")
else:
                result.layers_failed.append("smtp")
                  result.status = "invalid"
                return result
except Exception as e:
            result.layers_passed.append("smtp")  # inconclusive, don't fail
            result.details["smtp_error"] = str(e)
else:
        result.layers_passed.append("smtp")  # skipped

    # ── Layer 6: Catch-all detection ───────────────────────────────────────────
    if not catch_all:
              catch_all = _is_catch_all(domain, mx_hosts)
    result.layers_passed.append("catch_all")
    result.details["catch_all"] = catch_all

    # ── Layer 7: ZeroBounce / NeverBounce ─────────────────────────────────────
    if ZEROBOUNCE_API_KEY:
              zb = _zerobounce_check(email)
        result.details["zerobounce"] = zb
        result.layers_passed.append("zerobounce")
        if zb.get("status") == "valid":
                      result.score = max(result.score, 0.95)
elif zb.get("status") == "invalid":
            result.status = "invalid"
            return result
elif NEVERBOUNCE_API_KEY:
        nb = _neverbounce_check(email)
        result.details["neverbounce"] = nb
        result.layers_passed.append("neverbounce")
        if nb.get("result") == "valid":
                      result.score = max(result.score, 0.90)
elif nb.get("result") == "invalid":
            result.status = "invalid"
            return result

    # ── Final status ───────────────────────────────────────────────────────────
    if catch_all:
              result.status = "catch_all"
        result.is_valid = True
        result.score = max(result.score, 0.5)
else:
        result.status = "valid"
        result.is_valid = True
        result.score = max(result.score, 0.85)

    return result


# ── SMTP helpers ───────────────────────────────────────────────────────────────

def _smtp_verify(email: str, mx_host: str):
      """Return (is_valid, is_catch_all). Raises on connection error."""
    probe = f"probe_{email}"
    responses = {}
    for addr in [email, probe]:
              try:
                            with smtplib.SMTP(timeout=SMTP_TIMEOUT_SECONDS) as smtp:
                                              smtp.connect(mx_host, 25)
                                              smtp.helo(socket.getfqdn())
                                              smtp.mail("verify@enricherpro.com")
                                              code, _ = smtp.rcpt(addr)
                                              responses[addr] = code
              except smtplib.SMTPConnectError:
            raise
except Exception:
            responses[addr] = 550
    real_ok = responses.get(email, 550) == 250
    probe_ok = responses.get(probe, 550) == 250
    is_catch_all = probe_ok  # if a random address is accepted, domain is catch-all
    return (real_ok or is_catch_all), is_catch_all


def _is_catch_all(domain: str, mx_hosts: list) -> bool:
      """Quick catch-all probe without full SMTP dialog."""
    if not mx_hosts:
              return False
    probe = f"zzz_probe_9x8y7z@{domain}"
    try:
              _, is_catch_all = _smtp_verify(probe, mx_hosts[0])
        return is_catch_all
except Exception:
        return False


# ── External validator helpers ─────────────────────────────────────────────────

def _zerobounce_check(email: str) -> Dict[str, Any]:
      try:
                resp = requests.get(
                    "https://api.zerobounce.net/v2/validate",
                    params={"api_key": ZEROBOUNCE_API_KEY, "email": email},
                    timeout=10,
      )
        return resp.json()
except Exception as e:
        return {"error": str(e)}


def _neverbounce_check(email: str) -> Dict[str, Any]:
      try:
                resp = requests.get(
                    "https://api.neverbounce.com/v4/single/check",
                    params={"key": NEVERBOUNCE_API_KEY, "email": email},
                    timeout=10,
      )
        return resp.json()
except Exception as e:
        return {"error": str(e)}
