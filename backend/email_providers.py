"""
Multi-provider email search engine for EnricherPro.

Tier structure
--------------
FREE  — pattern generation + MX/SMTP verification (no API key required)
PAID  — Hunter.io · ZeroBounce · NeverBounce · Apollo.io · Clearbit · Snovio

The enricher tries providers in priority order and stops at the first
confident result (confidence >= threshold).
"""

import re
import socket
import smtplib
import dns.resolver
import requests
import logging
from typing import Optional
from dataclasses import dataclass, field

logger = logging.getLogger(__name__)


# ── Result model ──────────────────────────────────────────────────────────────

@dataclass
class EmailResult:
    email: str = ''
    confidence: float = 0.0
    source: str = 'none'
    verified: bool = False
    mx_valid: bool = False
    smtp_valid: bool = False
    is_catchall: bool = False
    all_patterns: list = field(default_factory=list)
    details: str = ''


# ── Helpers ───────────────────────────────────────────────────────────────────

def _clean(name: str) -> str:
    name = re.sub(r'[^a-zA-Z\s-]', '', name).lower().strip()
    return re.sub(r'[\s-]+', ' ', name)


def _domain_from_company(company: str) -> str:
    suffixes = ['inc', 'llc', 'ltd', 'corp', 'corporation', 'company', 'co', 'group', 'solutions']
    cleaned = company.lower()
    for s in suffixes:
        cleaned = re.sub(rf'\b{s}\.?\b', '', cleaned)
    cleaned = re.sub(r'[^a-z0-9]', '', cleaned).strip()
    return f"{cleaned or 'unknown'}.com"


def _generate_patterns(first: str, last: str, domain: str) -> list[str]:
    f = _clean(first).split()[0] if _clean(first).split() else ''
    l = _clean(last).split()[-1] if _clean(last).split() else ''
    if not f or not l:
        return []
    fi = f[0]
    patterns = [
        f"{f}.{l}@{domain}",
        f"{f}{l}@{domain}",
        f"{fi}{l}@{domain}",
        f"{f}@{domain}",
        f"{fi}.{l}@{domain}",
        f"{l}.{f}@{domain}",
        f"{l}{fi}@{domain}",
        f"{f}_{l}@{domain}",
        f"{f}-{l}@{domain}",
        f"{fi}{l[0]}@{domain}" if l else '',
    ]
    return list(dict.fromkeys(p for p in patterns if p))


def _check_mx(domain: str) -> bool:
    try:
        records = dns.resolver.resolve(domain, 'MX', lifetime=5)
        return len(records) > 0
    except Exception:
        return False


def _check_smtp(email: str, domain: str) -> tuple[bool, bool]:
    """Returns (smtp_valid, is_catchall)."""
    try:
        mx_records = dns.resolver.resolve(domain, 'MX', lifetime=5)
        mx_host = str(sorted(mx_records, key=lambda r: r.preference)[0].exchange).rstrip('.')
    except Exception:
        return False, False

    try:
        with smtplib.SMTP(mx_host, 25, timeout=8) as smtp:
            smtp.ehlo_or_helo_if_needed()
            smtp.mail('verify@enricherpro.com')
            code_real, _ = smtp.rcpt(email)
            smtp.mail('verify@enricherpro.com')
            code_fake, _ = smtp.rcpt(f'zzz_fake_9876543@{domain}')
            smtp_valid = (code_real == 250)
            is_catchall = (code_fake == 250)
            return smtp_valid, is_catchall
    except Exception:
        return False, False


# ── Free tier ─────────────────────────────────────────────────────────────────

class FreeEmailFinder:
    """Pattern generation + optional MX/SMTP verification — no API keys."""

    def find(self, first: str, last: str, company: str,
             verify: bool = True) -> EmailResult:
        domain = _domain_from_company(company)
        patterns = _generate_patterns(first, last, domain)
        if not patterns:
            return EmailResult(details='Could not generate patterns')

        mx_valid = _check_mx(domain) if verify else False
        base_confidence = 0.55 if not mx_valid else 0.65

        best_email = patterns[0]
        best_confidence = base_confidence
        smtp_valid = False
        is_catchall = False

        if verify and mx_valid:
            smtp_valid, is_catchall = _check_smtp(best_email, domain)
            if smtp_valid and not is_catchall:
                best_confidence = 0.85
            elif is_catchall:
                best_confidence = 0.65

        return EmailResult(
            email=best_email,
            confidence=best_confidence,
            source='free_pattern',
            verified=smtp_valid,
            mx_valid=mx_valid,
            smtp_valid=smtp_valid,
            is_catchall=is_catchall,
            all_patterns=patterns,
            details='MX+SMTP verified' if smtp_valid else 'Pattern-based',
        )


# ── Paid providers ────────────────────────────────────────────────────────────

class HunterProvider:
    """
    Hunter.io — Domain Search + Email Finder
    Free plan: 25 searches/month · Paid from $49/month
    Docs: https://hunter.io/api-documentation
    """
    BASE = 'https://api.hunter.io/v2'

    def __init__(self, api_key: str):
        self.api_key = api_key

    def find(self, first: str, last: str, company: str) -> Optional[EmailResult]:
        try:
            domain = _domain_from_company(company)
            # Try Email Finder first (more precise)
            resp = requests.get(
                f'{self.BASE}/email-finder',
                params={
                    'domain': domain,
                    'first_name': first,
                    'last_name': last,
                    'api_key': self.api_key,
                },
                timeout=10,
            )
            if resp.status_code == 200:
                data = resp.json().get('data', {})
                email = data.get('email', '')
                score = (data.get('score', 0) or 0) / 100.0
                if email and score > 0:
                    return EmailResult(
                        email=email,
                        confidence=score,
                        source='hunter_finder',
                        verified=True,
                        details=f"Hunter score {data.get('score')}",
                    )
        except Exception as e:
            logger.warning('Hunter API error: %s', e)
        return None


class ZeroBounceProvider:
    """
    ZeroBounce — Email validation & discovery
    Paid from $15/month · Free trial credits available
    Docs: https://www.zerobounce.net/docs/
    """
    BASE = 'https://api.zerobounce.net/v2'

    def __init__(self, api_key: str):
        self.api_key = api_key

    def validate(self, email: str) -> Optional[EmailResult]:
        try:
            resp = requests.get(
                f'{self.BASE}/validate',
                params={'api_key': self.api_key, 'email': email},
                timeout=10,
            )
            if resp.status_code == 200:
                data = resp.json()
                status = data.get('status', '')
                # valid / invalid / catch-all / unknown / spamtrap / abuse / do_not_mail
                valid = status == 'valid'
                catchall = status == 'catch-all'
                confidence = 0.90 if valid else (0.60 if catchall else 0.10)
                return EmailResult(
                    email=email,
                    confidence=confidence,
                    source='zerobounce',
                    verified=valid,
                    is_catchall=catchall,
                    details=f"ZeroBounce status: {status}",
                )
        except Exception as e:
            logger.warning('ZeroBounce API error: %s', e)
        return None


class NeverBounceProvider:
    """
    NeverBounce — Real-time email verification
    Pay-as-you-go from $0.008/email or monthly plans
    Docs: https://developers.neverbounce.com/
    """
    BASE = 'https://api.neverbounce.com/v4'

    def __init__(self, api_key: str):
        self.api_key = api_key

    def validate(self, email: str) -> Optional[EmailResult]:
        try:
            resp = requests.get(
                f'{self.BASE}/single/check',
                params={'key': self.api_key, 'email': email},
                timeout=10,
            )
            if resp.status_code == 200:
                data = resp.json()
                result_code = data.get('result', '')
                # 0=valid, 1=invalid, 2=disposable, 3=catchall, 4=unknown
                confidence_map = {'valid': 0.92, 'catchall': 0.60,
                                  'unknown': 0.40, 'invalid': 0.05, 'disposable': 0.05}
                confidence = confidence_map.get(result_code, 0.30)
                return EmailResult(
                    email=email,
                    confidence=confidence,
                    source='neverbounce',
                    verified=(result_code == 'valid'),
                    is_catchall=(result_code == 'catchall'),
                    details=f"NeverBounce result: {result_code}",
                )
        except Exception as e:
            logger.warning('NeverBounce API error: %s', e)
        return None


class ApolloProvider:
    """
    Apollo.io — Contact enrichment & email finding
    Free plan: 50 exports/month · Paid from $49/month
    Docs: https://apolloio.github.io/apollo-api-docs/
    """
    BASE = 'https://api.apollo.io/v1'

    def __init__(self, api_key: str):
        self.api_key = api_key

    def find(self, first: str, last: str, company: str) -> Optional[EmailResult]:
        try:
            resp = requests.post(
                f'{self.BASE}/people/match',
                json={
                    'first_name': first,
                    'last_name': last,
                    'organization_name': company,
                    'reveal_personal_emails': False,
                },
                headers={'Content-Type': 'application/json',
                         'Cache-Control': 'no-cache',
                         'X-Api-Key': self.api_key},
                timeout=12,
            )
            if resp.status_code == 200:
                person = resp.json().get('person') or {}
                email = person.get('email', '')
                if email:
                    return EmailResult(
                        email=email,
                        confidence=0.88,
                        source='apollo',
                        verified=True,
                        details='Apollo.io match',
                    )
        except Exception as e:
            logger.warning('Apollo API error: %s', e)
        return None


class ClearbitProvider:
    """
    Clearbit Enrichment — People & company data
    Paid — contact Clearbit for pricing
    Docs: https://dashboard.clearbit.com/docs
    """
    BASE = 'https://person.clearbit.com/v2/combined/find'

    def __init__(self, api_key: str):
        self.api_key = api_key

    def find(self, first: str, last: str, company: str) -> Optional[EmailResult]:
        domain = _domain_from_company(company)
        try:
            resp = requests.get(
                self.BASE,
                params={
                    'given_name': first,
                    'family_name': last,
                    'domain': domain,
                },
                auth=(self.api_key, ''),
                timeout=12,
            )
            if resp.status_code == 200:
                data = resp.json()
                person = data.get('person') or {}
                email = person.get('email', '')
                if email:
                    return EmailResult(
                        email=email,
                        confidence=0.90,
                        source='clearbit',
                        verified=True,
                        details='Clearbit enrichment',
                    )
        except Exception as e:
            logger.warning('Clearbit API error: %s', e)
        return None


class SnovioProvider:
    """
    Snov.io — Email finder & verifier
    Free plan: 50 credits/month · Paid from $39/month
    Docs: https://snov.io/api
    """
    AUTH_URL = 'https://api.snov.io/v1/oauth/access_token'
    BASE = 'https://api.snov.io/v1'

    def __init__(self, client_id: str, client_secret: str):
        self.client_id = client_id
        self.client_secret = client_secret
        self._token: str | None = None

    def _get_token(self) -> str | None:
        try:
            resp = requests.post(
                self.AUTH_URL,
                data={
                    'grant_type': 'client_credentials',
                    'client_id': self.client_id,
                    'client_secret': self.client_secret,
                },
                timeout=10,
            )
            if resp.status_code == 200:
                self._token = resp.json().get('access_token')
                return self._token
        except Exception as e:
            logger.warning('Snov.io auth error: %s', e)
        return None

    def find(self, first: str, last: str, company: str) -> Optional[EmailResult]:
        token = self._token or self._get_token()
        if not token:
            return None
        domain = _domain_from_company(company)
        try:
            resp = requests.post(
                f'{self.BASE}/get-emails-from-names',
                data={
                    'access_token': token,
                    'firstName': first,
                    'lastName': last,
                    'domain': domain,
                    'limit': 1,
                },
                timeout=12,
            )
            if resp.status_code == 200:
                data = resp.json()
                emails = data.get('data', [])
                if emails:
                    e = emails[0]
                    email_addr = e.get('email', '')
                    if email_addr:
                        return EmailResult(
                            email=email_addr,
                            confidence=0.85,
                            source='snovio',
                            verified=True,
                            details='Snov.io email finder',
                        )
        except Exception as e:
            logger.warning('Snov.io find error: %s', e)
        return None


# ── Orchestrator ──────────────────────────────────────────────────────────────

class EmailSearchEngine:
    """
    Tries providers in priority order, stops at first confident result.

    providers dict keys: 'hunter', 'zerobounce', 'neverbounce', 'apollo',
                         'clearbit', 'snovio'
    """

    CONFIDENCE_THRESHOLD = 0.75  # Stop searching above this confidence

    def __init__(self, api_keys: dict = None):
        keys = api_keys or {}
        self.free_finder = FreeEmailFinder()

        # Instantiate paid providers only when key is present
        self.hunter = HunterProvider(keys['hunter']) if keys.get('hunter') else None
        self.zerobounce = ZeroBounceProvider(keys['zerobounce']) if keys.get('zerobounce') else None
        self.neverbounce = NeverBounceProvider(keys['neverbounce']) if keys.get('neverbounce') else None
        self.apollo = ApolloProvider(keys['apollo']) if keys.get('apollo') else None
        self.clearbit = ClearbitProvider(keys['clearbit']) if keys.get('clearbit') else None
        self.snovio = (
            SnovioProvider(keys['snovio_client_id'], keys['snovio_client_secret'])
            if keys.get('snovio_client_id') and keys.get('snovio_client_secret')
            else None
        )

    def search(self, first: str, last: str, company: str,
               verify_free: bool = True) -> EmailResult:
        """
        Run the full provider cascade and return the best result.
        """
        # 1. Generate patterns up front (used as fallback)
        domain = _domain_from_company(company)
        patterns = _generate_patterns(first, last, domain)

        # 2. Try paid finders first (highest accuracy)
        paid_finders = [
            ('apollo', self.apollo),
            ('clearbit', self.clearbit),
            ('hunter', self.hunter),
            ('snovio', self.snovio),
        ]
        for name, provider in paid_finders:
            if provider:
                try:
                    result = provider.find(first, last, company)
                    if result and result.confidence >= self.CONFIDENCE_THRESHOLD:
                        result.all_patterns = patterns
                        # Optionally validate the found email with a verifier
                        if result.email and (self.zerobounce or self.neverbounce):
                            result = self._validate_found(result)
                        return result
                except Exception as e:
                    logger.warning('%s finder failed: %s', name, e)

        # 3. Free tier: pattern + MX/SMTP
        free_result = self.free_finder.find(first, last, company, verify=verify_free)
        free_result.all_patterns = patterns

        # 4. If we have a verifier and free result has an email, run verification
        if free_result.email and not free_result.smtp_valid:
            free_result = self._validate_found(free_result)

        return free_result

    def _validate_found(self, result: EmailResult) -> EmailResult:
        """Run ZeroBounce or NeverBounce on an already-found email."""
        verifier = self.zerobounce or self.neverbounce
        if not verifier:
            return result
        try:
            validated = verifier.validate(result.email)
            if validated:
                result.verified = validated.verified
                result.is_catchall = validated.is_catchall
                result.confidence = max(result.confidence, validated.confidence)
                result.source += f'+{validated.source}'
                result.details += f' | {validated.details}'
        except Exception as e:
            logger.warning('Validation error: %s', e)
        return result

    def available_providers(self) -> dict:
        """Return which providers are active."""
        return {
            'free_pattern_mx_smtp': True,
            'hunter': self.hunter is not None,
            'zerobounce': self.zerobounce is not None,
            'neverbounce': self.neverbounce is not None,
            'apollo': self.apollo is not None,
            'clearbit': self.clearbit is not None,
            'snovio': self.snovio is not None,
        }
