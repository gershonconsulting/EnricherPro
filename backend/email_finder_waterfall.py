"""
email_finder_waterfall.py — EnricherPro v5.0
Waterfall engine: tries up to 6 email finder providers in priority order.
First successful, validated result wins.
Providers: Hunter → Prospeo → Anymailfinder → Apollo → Dropcontact → Snov.io
"""

import requests
import time
from typing import Optional, Dict, Any
from config import (
    HUNTER_API_KEY, PROSPEO_API_KEY, ANYMAILFINDER_API_KEY,
    APOLLO_API_KEY, DROPCONTACT_API_KEY,
    SNOVIO_CLIENT_ID, SNOVIO_CLIENT_SECRET,
    PROVIDER_PRIORITY, get_active_providers,
)
from domain_pattern_engine import cache_pattern


class FinderResult:
      def __init__(self):
                self.email: Optional[str] = None
                self.provider: Optional[str] = None
                self.confidence: float = 0.0
                self.found: bool = False
                self.attempts: list = []

      def to_dict(self) -> Dict[str, Any]:
                return {
                              "email": self.email,
                              "provider": self.provider,
                              "confidence": round(self.confidence, 3),
                              "found": self.found,
                              "attempts": self.attempts,
                }


def find_email(first: str, last: str, domain: str, company: str = "") -> FinderResult:
      """
          Try each configured provider in priority order.
              Returns the first successful FinderResult.
                  """
      result = FinderResult()
      active = get_active_providers()

    for provider in PROVIDER_PRIORITY:
              if provider not in active:
                            result.attempts.append({"provider": provider, "status": "skipped_no_key"})
                            continue

              attempt = {"provider": provider}
              try:
                            email, confidence = _call_provider(provider, first, last, domain, company)
                            attempt["status"] = "found" if email else "not_found"
                            attempt["email"] = email
                            attempt["confidence"] = confidence
                            result.attempts.append(attempt)

                  if email:
                                    result.email = email
                                    result.provider = provider
                                    result.confidence = confidence
                                    result.found = True
                                    return result
except Exception as e:
            attempt["status"] = "error"
            attempt["error"] = str(e)
            result.attempts.append(attempt)

    return result  # not found after all providers


def _call_provider(provider: str, first: str, last: str, domain: str, company: str) -> tuple:
      """Dispatch to the correct provider function. Returns (email, confidence)."""
    dispatch = {
              "hunter":        _hunter_find,
              "prospeo":       _prospeo_find,
              "anymailfinder": _anymailfinder_find,
              "apollo":        _apollo_find,
              "dropcontact":   _dropcontact_find,
              "snovio":        _snovio_find,
    }
    fn = dispatch.get(provider)
    if fn:
              return fn(first, last, domain, company)
    return None, 0.0


# ── Provider implementations ───────────────────────────────────────────────────────────

def _hunter_find(first, last, domain, company):
      resp = requests.get(
                "https://api.hunter.io/v2/email-finder",
                params={
                              "domain": domain,
                              "first_name": first,
                              "last_name": last,
                              "api_key": HUNTER_API_KEY,
                },
                timeout=10,
      )
    data = resp.json().get("data", {})
    email = data.get("email")
    confidence = data.get("score", 0) / 100.0  # Hunter scores 0–100
    # Cache the pattern if Hunter returned one
    pattern = data.get("pattern")
    if pattern and domain:
              cache_pattern(domain, pattern)
    return email, confidence


def _prospeo_find(first, last, domain, company):
      resp = requests.post(
                "https://api.prospeo.io/email-finder",
                json={"first_name": first, "last_name": last, "domain": domain},
                headers={"X-KEY": PROSPEO_API_KEY, "Content-Type": "application/json"},
                timeout=10,
      )
    data = resp.json()
    email = data.get("response", {}).get("email")
    confidence = 0.80 if email else 0.0
    return email, confidence


def _anymailfinder_find(first, last, domain, company):
      resp = requests.get(
                "https://api.anymailfinder.com/v5.0/search/person.json",
                params={
                              "person_name": f"{first} {last}",
                              "company_domain": domain,
                },
                headers={"Authorization": f"Bearer {ANYMAILFINDER_API_KEY}"},
                timeout=10,
      )
    data = resp.json()
    email = data.get("email")
    confidence = 0.85 if email else 0.0  # Anymailfinder only returns verified emails
    return email, confidence


def _apollo_find(first, last, domain, company):
      resp = requests.post(
                "https://api.apollo.io/v1/people/match",
                json={
                              "first_name": first,
                              "last_name": last,
                              "domain": domain,
                              "organization_name": company,
                              "reveal_personal_emails": False,
},
                headers={"Content-Type": "application/json", "Cache-Control": "no-cache"},
                params={"api_key": APOLLO_API_KEY},
                timeout=12,
      )
    person = resp.json().get("person") or {}
    email = person.get("email")
    confidence = 0.75 if email else 0.0
    return email, confidence


def _dropcontact_find(first, last, domain, company):
    resp = requests.post(
              "https://api.dropcontact.io/b2b-api/enrich",
              json={
                            "data": [{"first_name": first, "last_name": last, "website": domain}],
                            "siren": False,
              },
              headers={"X-Access-Token": DROPCONTACT_API_KEY, "Content-Type": "application/json"},
              timeout=15,
    )
    results = resp.json().get("data", [{}])
    email_list = results[0].get("email", []) if results else []
    email = email_list[0].get("email") if email_list else None
    confidence = 0.78 if email else 0.0
    return email, confidence


def _snovio_find(first, last, domain, company):
      # Step 1: get access token
      token_resp = requests.post(
                "https://api.snov.io/v1/oauth/access_token",
                json={
                              "grant_type": "client_credentials",
                              "client_id": SNOVIO_CLIENT_ID,
                              "client_secret": SNOVIO_CLIENT_SECRET,
                },
                timeout=10,
      )
    token = token_resp.json().get("access_token")
    if not token:
              return None, 0.0

    # Step 2: find email
    resp = requests.post(
              "https://api.snov.io/v1/get-emails-from-names",
              json={
                            "firstName": first,
                            "lastName": last,
                            "domain": domain,
                            "access_token": token,
              },
              timeout=12,
    )
    data = resp.json()
    emails = data.get("data", {}).get("emails", [])
    if emails:
              return emails[0].get("email"), 0.60  # lower confidence for Snov.io
    return None, 0.0
