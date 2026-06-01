"""
api_server_v5.py — EnricherPro v5.0
FastAPI server — drop-in replacement for api_server_working.py
Same endpoints, same request/response shapes.
New: richer response fields, batch up to 200, /api/validate, /api/providers.
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import uvicorn

from config import get_active_providers, get_active_validators, MAX_BATCH_SIZE
from email_finder_waterfall import find_email
from email_validator_v2 import validate_email

app = FastAPI(
      title="EnricherPro API",
      description="Multi-provider email enrichment with 7-layer validation",
      version="5.0.0",
)

app.add_middleware(
      CORSMiddleware,
      allow_origins=["*"],
      allow_methods=["*"],
      allow_headers=["*"],
)


# ── Request / Response models ──────────────────────────────────────────────────────

class EnrichRequest(BaseModel):
      first_name: str
      last_name: str
      domain: str
      company: Optional[str] = ""
      linkedin_url: Optional[str] = ""

class ContactRequest(BaseModel):
      first_name: str
      last_name: str
      domain: str
      company: Optional[str] = ""
      linkedin_url: Optional[str] = ""

class BatchEnrichRequest(BaseModel):
      contacts: List[ContactRequest]

class ValidateRequest(BaseModel):
      email: str


# ── Endpoints ─────────────────────────────────────────────────────────────────────

@app.get("/api/health")
def health():
      """Health check — same as v2 but richer."""
      return {
          "status": "ok",
          "version": "5.0.0",
          "service": "EnricherPro API v5.0",
          "providers": get_active_providers(),
          "validators": get_active_validators(),
          "features": [
              "Multi-provider waterfall (up to 6 finders)",
              "7-layer email validation",
              "Catch-all domain detection",
              "Domain pattern engine",
              "Batch up to 200 contacts",
          ],
      }


@app.get("/api/providers")
def providers():
      """Show which providers and validators are active."""
      return {
          "active_providers": get_active_providers(),
          "active_validators": get_active_validators(),
      }


@app.post("/api/enrich")
def enrich(req: EnrichRequest):
      """Enrich a single contact — find and validate their email."""
      # 1. Find
      finder = find_email(
          first=req.first_name,
          last=req.last_name,
          domain=req.domain,
          company=req.company or "",
      )

    # 2. Validate if found
      validation = None
      if finder.found and finder.email:
                val_result = validate_email(finder.email)
                validation = val_result.to_dict()

      return {
          "email": finder.email,
          "found": finder.found,
          "provider": finder.provider,
          "confidence": finder.confidence,
          "status": validation["status"] if validation else "not_found",
          "validation": validation,
          "finder_attempts": finder.attempts,
      }


@app.post("/api/enrich/batch")
def enrich_batch(req: BatchEnrichRequest):
      """Enrich a batch of contacts (up to 200)."""
      if len(req.contacts) > MAX_BATCH_SIZE:
                raise HTTPException(
                              status_code=400,
                              detail=f"Batch size {len(req.contacts)} exceeds maximum of {MAX_BATCH_SIZE}",
                )

      results = []
      found_count = 0
      valid_count = 0

    for contact in req.contacts:
              finder = find_email(
                            first=contact.first_name,
                            last=contact.last_name,
                            domain=contact.domain,
                            company=contact.company or "",
              )
              validation = None
              if finder.found and finder.email:
                            found_count += 1
                            val_result = validate_email(finder.email)
                            validation = val_result.to_dict()
                            if val_result.is_valid:
                                              valid_count += 1

                        results.append({
                                      "input": {
                                                        "first_name": contact.first_name,
                                                        "last_name": contact.last_name,
                                                        "domain": contact.domain,
                                      },
                                      "email": finder.email,
                                      "found": finder.found,
                                      "provider": finder.provider,
                                      "confidence": finder.confidence,
                                      "status": validation["status"] if validation else "not_found",
                                      "validation": validation,
                        })

    total = len(req.contacts)
    return {
              "results": results,
              "summary": {
                            "total": total,
                            "found": found_count,
                            "valid": valid_count,
                            "find_rate_pct": round(found_count / total * 100, 1) if total else 0,
                            "valid_rate_pct": round(valid_count / total * 100, 1) if total else 0,
              },
    }


@app.post("/api/validate")
def validate(req: ValidateRequest):
      """Validate an email address without finding it (new in v5)."""
    result = validate_email(req.email)
    return result.to_dict()


# ── Entry point ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
      from config import API_HOST, API_PORT
    uvicorn.run("api_server_v5:app", host=API_HOST, port=API_PORT, reload=False)
