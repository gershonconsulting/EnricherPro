"""
config.py — EnricherPro v5.0
Central configuration: loads all API keys from environment,
defines provider priority order for the waterfall engine.
"""

import os
from dotenv import load_dotenv

load_dotenv()

# ── Provider API keys ──────────────────────────────────────────────────────────
HUNTER_API_KEY         = os.getenv("HUNTER_API_KEY", "")
PROSPEO_API_KEY        = os.getenv("PROSPEO_API_KEY", "")
ANYMAILFINDER_API_KEY  = os.getenv("ANYMAILFINDER_API_KEY", "")
APOLLO_API_KEY         = os.getenv("APOLLO_API_KEY", "")
DROPCONTACT_API_KEY    = os.getenv("DROPCONTACT_API_KEY", "")
SNOVIO_CLIENT_ID       = os.getenv("SNOVIO_CLIENT_ID", "")
SNOVIO_CLIENT_SECRET   = os.getenv("SNOVIO_CLIENT_SECRET", "")

# ── Validation API keys ────────────────────────────────────────────────────────
ZEROBOUNCE_API_KEY     = os.getenv("ZEROBOUNCE_API_KEY", "")
NEVERBOUNCE_API_KEY    = os.getenv("NEVERBOUNCE_API_KEY", "")

# ── Waterfall provider priority order ─────────────────────────────────────────
# Providers are tried in this order; first successful result wins.
PROVIDER_PRIORITY = [
      "hunter",        # 1st — best domain pattern detection
      "prospeo",       # 2nd
      "anymailfinder", # 3rd
      "apollo",        # 4th — generous free tier
      "dropcontact",   # 5th
      "snovio",        # 6th — last resort (lowest accuracy)
]

# ── Validation layer toggles ───────────────────────────────────────────────────
ENABLE_SMTP_CHECK       = os.getenv("ENABLE_SMTP_CHECK", "true").lower() == "true"
SMTP_TIMEOUT_SECONDS    = int(os.getenv("SMTP_TIMEOUT_SECONDS", "10"))

# ── Server config ──────────────────────────────────────────────────────────────
API_HOST  = os.getenv("API_HOST", "0.0.0.0")
API_PORT  = int(os.getenv("API_PORT", "5000"))

# ── Batch limits ───────────────────────────────────────────────────────────────
MAX_BATCH_SIZE = 200  # up from 50 in v4.x

def get_active_providers():
      """Return list of providers that have API keys configured."""
      active = []
      key_map = {
          "hunter":        HUNTER_API_KEY,
          "prospeo":       PROSPEO_API_KEY,
          "anymailfinder": ANYMAILFINDER_API_KEY,
          "apollo":        APOLLO_API_KEY,
          "dropcontact":   DROPCONTACT_API_KEY,
          "snovio":        SNOVIO_CLIENT_ID and SNOVIO_CLIENT_SECRET,
      }
      for provider in PROVIDER_PRIORITY:
                if key_map.get(provider):
                              active.append(provider)
                      return active

def get_active_validators():
      """Return list of validation services that have API keys configured."""
      validators = ["syntax", "dns_mx", "role_based", "disposable", "smtp", "catch_all"]
      if ZEROBOUNCE_API_KEY:
                validators.append("zerobounce")
            if NEVERBOUNCE_API_KEY:
                      validators.append("neverbounce")
                  return validators
