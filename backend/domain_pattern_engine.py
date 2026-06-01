"""
domain_pattern_engine.py — EnricherPro v5.0
Detects email format pattern per company domain
(e.g. first.last, flast, firstl, first, etc.)
and caches results to avoid redundant API calls.
"""

import re
from typing import Optional, Dict, List, Tuple
from functools import lru_cache
import requests
from config import HUNTER_API_KEY

# ── Pattern definitions ─────────────────────────────────────────────────────────────
PATTERN_TEMPLATES = {
      "first.last":   lambda f, l: f"{f}.{l}",
      "firstlast":    lambda f, l: f"{f}{l}",
      "flast":        lambda f, l: f"{f[0]}{l}",
      "first":        lambda f, l: f"{f}",
      "last":         lambda f, l: f"{l}",
      "f.last":       lambda f, l: f"{f[0]}.{l}",
      "last.first":   lambda f, l: f"{l}.{f}",
      "lastfirst":    lambda f, l: f"{l}{f}",
      "firstl":       lambda f, l: f"{f}{l[0]}",
      "first_last":   lambda f, l: f"{f}_{l}",
}

# In-memory cache: domain → pattern name
_pattern_cache: Dict[str, Optional[str]] = {}


def build_email(first: str, last: str, domain: str, pattern: Optional[str] = None) -> Optional[str]:
      """
          Build an email address for a person at a given domain.
              If pattern is provided, use it directly.
                  Otherwise, detect the pattern for the domain first.
                      Returns None if pattern cannot be determined.
                          """
      first = _normalize(first)
      last = _normalize(last)
      if not first or not last or not domain:
                return None

      if pattern is None:
                pattern = get_domain_pattern(domain)

      if pattern and pattern in PATTERN_TEMPLATES:
                local = PATTERN_TEMPLATES[pattern](first, last)
                return f"{local}@{domain}"
            return None


def get_domain_pattern(domain: str) -> Optional[str]:
      """
          Return the dominant email pattern for a domain.
              Checks cache first, then queries Hunter.io if key is configured.
                  """
    domain = domain.lower().strip()
    if domain in _pattern_cache:
              return _pattern_cache[domain]

    pattern = None
    if HUNTER_API_KEY:
              pattern = _detect_via_hunter(domain)

    _pattern_cache[domain] = pattern
    return pattern


def generate_candidates(first: str, last: str, domain: str) -> List[str]:
      """
          Generate all possible email candidates for a person at a domain.
              Returns a list ordered by likelihood (known pattern first, then all others).
                  """
    first = _normalize(first)
    last = _normalize(last)
    if not first or not last or not domain:
              return []

    known_pattern = get_domain_pattern(domain)
    candidates = []

    # Put the detected pattern first
    if known_pattern and known_pattern in PATTERN_TEMPLATES:
              email = f"{PATTERN_TEMPLATES[known_pattern](first, last)}@{domain}"
              candidates.append(email)

    # Then all other patterns
    for name, template in PATTERN_TEMPLATES.items():
              if name == known_pattern:
                            continue
                        email = f"{template(first, last)}@{domain}"
        if email not in candidates:
                      candidates.append(email)

    return candidates


def cache_pattern(domain: str, pattern: str) -> None:
      """Manually cache a confirmed pattern for a domain."""
    _pattern_cache[domain.lower().strip()] = pattern


# ── Hunter.io domain search helper ──────────────────────────────────────────────────

def _detect_via_hunter(domain: str) -> Optional[str]:
      """
          Query Hunter.io domain search to detect the most common email pattern.
              Returns pattern name string or None.
                  """
    try:
              resp = requests.get(
                  "https://api.hunter.io/v2/domain-search",
                  params={"domain": domain, "api_key": HUNTER_API_KEY, "limit": 10},
                  timeout=8,
    )
        data = resp.json()
        pattern_raw = data.get("data", {}).get("pattern")
        if pattern_raw:
                      return _normalize_hunter_pattern(pattern_raw)
                  # Fallback: infer pattern from returned emails
                  emails = data.get("data", {}).get("emails", [])
        if emails:
                      return _infer_pattern_from_emails(emails)
except Exception:
        pass
    return None


def _normalize_hunter_pattern(raw: str) -> Optional[str]:
      """Map Hunter.io pattern strings to our internal pattern names."""
    mapping = {
              "{first}.{last}": "first.last",
              "{first}{last}": "firstlast",
              "{f}{last}": "flast",
              "{first}": "first",
              "{last}": "last",
              "{f}.{last}": "f.last",
              "{last}.{first}": "last.first",
              "{last}{first}": "lastfirst",
              "{first}{l}": "firstl",
              "{first}_{last}": "first_last",
    }
    return mapping.get(raw)


def _infer_pattern_from_emails(emails: list) -> Optional[str]:
      """Infer email pattern by analysing a list of Hunter email objects."""
    pattern_counts: Dict[str, int] = {}
    for entry in emails:
              addr = entry.get("value", "")
              fn = _normalize(entry.get("first_name", ""))
              ln = _normalize(entry.get("last_name", ""))
              if not fn or not ln or "@" not in addr:
                            continue
                        local = addr.split("@")[0]
        for name, template in PATTERN_TEMPLATES.items():
                      try:
                                        if template(fn, ln) == local:
                                                              pattern_counts[name] = pattern_counts.get(name, 0) + 1
                                                              break
                      except Exception:
                                        continue
                            if pattern_counts:
                  return max(pattern_counts, key=pattern_counts.get)
    return None


# ── Utilities ────────────────────────────────────────────────────────────────────

def _normalize(name: str) -> str:
      """Lowercase, strip accents-ish, remove non-alpha chars."""
    if not name:
              return ""
    name = name.lower().strip()
    # Basic accent removal
    replacements = {
              "àáâãäå": "a", "èéêë": "e", "ìíîï": "i",
              "òóôõö": "o", "ùúûü": "u", "ñ": "n", "ç": "c",
    }
    for chars, replacement in replacements.items():
              for ch in chars:
                            name = name.replace(ch, replacement)
                    return re.sub(r'[^a-z]', '', name)
