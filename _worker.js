/**
 * EnricherPro v5.3 — Cloudflare Pages Worker
 * ===========================================
 *
 * Serves the Flutter web build from ASSETS and handles /api/* same-origin,
 * which is what the old unified_server.py did on the sandbox. Same-origin
 * means no CORS to configure and no separate api. subdomain to maintain.
 *
 * This replaces the v2.0 Flask API, which did no lookup at all: it slugified
 * the company name, appended a TLD, prefixed first.last@ and returned that as
 * a finished result. Every rule below exists because v2.0 got it wrong.
 *
 *   1. `email` is populated ONLY after a verifier confirmed the mailbox.
 *      Everything else goes to `best_guess`, which the UI must not treat as
 *      a deliverable address.
 *   2. `catch_all` is NOT verification. A catch-all domain accepts every
 *      local part, so a positive probe proves nothing about that mailbox.
 *   3. Confidence is derived (domain evidence x name match x verifier
 *      verdict). v2.0 returned two constants, 0.85 and 0.30.
 *   4. A company we cannot resolve to a real mail domain produces NO address.
 *   5. linkedin_validated is true only for a well-formed URL the caller
 *      supplied. We never template one and never claim to have checked it.
 *
 * Secrets: MILLIONVERIFIER_API_KEY is a Pages environment variable. It is
 * never sent to the browser — only its redacted form appears in /api/settings.
 */

const VERSION = "5.3.0";

// Bounds.
//
// The Workers FREE plan allows 50 subrequests per request. One contact costs
// up to (MX lookups + 1 homepage + verification probes) subrequests, so a
// large batch would hit the ceiling and be killed mid-flight with no useful
// error. Instead we track the budget ourselves and stop cleanly, telling the
// caller exactly which contacts were not attempted.
//
// Raise SUBREQUEST_BUDGET to ~950 if this account moves to the paid plan.
const SUBREQUEST_BUDGET = 45;
const MAX_CONTACTS_PER_REQUEST = 10;
const MAX_DOMAIN_CANDIDATES = 5;
const MAX_PROBES_PER_DOMAIN = 4;
const MV_TIMEOUT_SECONDS = 15;

/** Spend one subrequest. Returns false when the budget is gone. */
function spend(budget, n = 1) {
  if (budget.left < n) return false;
  budget.left -= n;
  return true;
}

// ───────────────────────────── verification ──────────────────────────────

const RESULT_MAP = {
  ok:         ["verified",    0.95],
  catch_all:  ["unconfirmed", 0.45],
  unknown:    ["unconfirmed", 0.20],
  unverified: ["unconfirmed", 0.15],
  disposable: ["rejected",    0.0],
  invalid:    ["rejected",    0.0],
  error:      ["error",       0.0],
};

const NAME_MATCH_WEIGHTS = {
  FULL: 1.0, INITIAL_LAST: 0.9, LAST_ONLY: 0.65, FIRST_ONLY: 0.5, NONE: 0.3,
};

const ROLE_PENALTY = 0.55;
const FREE_PENALTY = 0.85;

/**
 * Verify one address with MillionVerifier.
 *
 * We branch on the `result` STRING, never `resultcode`: the live API returns
 * codes that contradict the published table (a result="disposable" response
 * carried resultcode=3, which the docs list as "unknown").
 */
async function mvVerify(email, nameMatch, apiKey, cache, budget) {
  if (cache.has(email)) return cache.get(email);   // cached hits are free
  if (!spend(budget)) {
    return { verdict: "error", confidence: 0, result: "", catchAll: false,
             error: "subrequest budget exhausted", credits: null };
  }

  const url = new URL("https://api.millionverifier.com/api/v3/");
  url.searchParams.set("api", apiKey);
  url.searchParams.set("email", email);
  url.searchParams.set("timeout", String(MV_TIMEOUT_SECONDS));

  let data;
  try {
    const r = await fetch(url.toString(), {
      headers: { "User-Agent": "EnricherPro/5.3 (+https://enricherpro.com)" },
    });
    if (!r.ok) throw new Error("HTTP " + r.status);
    data = await r.json();
  } catch (e) {
    // Never invent a verdict out of our own failure.
    return { verdict: "error", confidence: 0, result: "", catchAll: false,
             error: String(e && e.message || e), credits: null };
  }

  const result = String(data.result || "").toLowerCase();
  const [mapped, base] = RESULT_MAP[result] || ["unconfirmed", 0.15];

  let verdict = mapped;
  let confidence = base;

  if (verdict === "verified" || verdict === "unconfirmed") {
    confidence *= NAME_MATCH_WEIGHTS[String(nameMatch).toUpperCase()] ?? 0.3;
    if (data.role) confidence *= ROLE_PENALTY;
    if (data.free) confidence *= FREE_PENALTY;
    // A confirmed mailbox we cannot attribute to the requested person is not
    // a find for THIS contact.
    if (verdict === "verified" && String(nameMatch).toUpperCase() === "NONE") {
      verdict = "unconfirmed";
    }
  }

  const out = {
    verdict,
    confidence: Math.round(Math.min(1, Math.max(0, confidence)) * 1000) / 1000,
    result,
    quality: String(data.quality || "").toLowerCase(),
    subresult: String(data.subresult || ""),
    role: !!data.role,
    free: !!data.free,
    catchAll: result === "catch_all",
    credits: typeof data.credits === "number" ? data.credits : null,
    error: String(data.error || ""),
  };
  if (verdict !== "error") cache.set(email, out);
  return out;
}

async function mvCredits(apiKey) {
  const url = `https://api.millionverifier.com/api/v3/credits?api=${encodeURIComponent(apiKey)}`;
  const r = await fetch(url);
  const data = await r.json();
  if (data.result === "error") throw new Error(data.error || "apikey_not_found");
  return data;
}

// ────────────────────────────── name matching ────────────────────────────

/** Strip accents, keep letters only. 'Schäfer' -> 'schafer'. */
function fold(s) {
  return String(s || "").toLowerCase().normalize("NFKD")
    .replace(/[̀-ͯ]/g, "").replace(/[^a-z]/g, "");
}

/** German transliteration: 'Schäfer' -> 'schaefer', 'Weiß' -> 'weiss'. */
function foldGerman(s) {
  return String(s || "").toLowerCase()
    .replace(/ä/g, "ae").replace(/ö/g, "oe").replace(/ü/g, "ue")
    .replace(/ß/g, "ss").normalize("NFKD")
    .replace(/[̀-ͯ]/g, "").replace(/[^a-z]/g, "");
}

function variants(s) {
  return [...new Set([fold(s), foldGerman(s)].filter(Boolean))];
}

/**
 * Grade how well an address's local part matches the person.
 *
 * Token-boundary matching, not substring. The old code tested
 * `"ross" in "cross@..."` and returned a stranger's real mailbox at 0.70.
 */
function matchEmail(email, first, last) {
  const local = String(email).split("@")[0].toLowerCase();
  const tokens = local.split(/[._\-+0-9]+/).filter(Boolean);
  const joined = local.replace(/[._\-+0-9]/g, "");

  const F = variants(first), L = variants(last);
  if (!F.length || !L.length) return "NONE";

  const hasTok = (cands) => cands.some((c) => c && tokens.includes(c));
  const hasFirst = hasTok(F);
  const hasLast = hasTok(L);

  if (hasFirst && hasLast) return "FULL";
  // flast / f.last — first initial glued to a full last name
  for (const f of F) for (const l of L) {
    if (!f || !l) continue;
    if (joined === f[0] + l || tokens.includes(f[0] + l)) return "INITIAL_LAST";
    if (joined === f + l || joined === l + f) return "FULL";
  }
  if (hasLast) return "LAST_ONLY";
  if (hasFirst) return "FIRST_ONLY";
  return "NONE";
}

/** FIRST_ONLY and NONE are not defensible identity matches — never probe them. */
const USABLE = new Set(["FULL", "INITIAL_LAST", "LAST_ONLY"]);

function candidateAddresses(first, last, domain) {
  const out = [];
  const F = variants(first), L = variants(last);
  for (const f of F) for (const l of L) {
    if (!f || !l) continue;
    out.push(`${f}.${l}@${domain}`, `${f[0]}${l}@${domain}`,
             `${f}${l}@${domain}`, `${f}_${l}@${domain}`,
             `${l}.${f}@${domain}`, `${f}@${domain}`);
  }
  return [...new Set(out)];
}

// ──────────────────────── company name -> mail domain ────────────────────

const PUBLIC_MAIL = new Set([
  "gmail.com", "yahoo.com", "hotmail.com", "outlook.com", "aol.com",
  "icloud.com", "gmx.com", "mail.com", "protonmail.com", "live.com",
]);

/** MX lookup over DNS-over-HTTPS. Workers have no DNS resolver of their own. */
async function hasMX(domain, budget) {
  if (!spend(budget)) return false;
  try {
    const r = await fetch(
      `https://cloudflare-dns.com/dns-query?name=${encodeURIComponent(domain)}&type=MX`,
      { headers: { accept: "application/dns-json" } }
    );
    const d = await r.json();
    return Array.isArray(d.Answer) && d.Answer.some((a) => a.type === 15);
  } catch { return false; }
}

/** The company's words joined, with legal suffixes stripped. */
function slugBase(company) {
  const clean = String(company || "").toLowerCase()
    .replace(/\b(inc|llc|ltd|limited|gmbh|ag|sa|sas|sarl|bv|nv|plc|corp|corporation|co|company|group|holdings?|international|srl|spa|oy|ab|as|kk)\b/g, " ")
    .replace(/[^a-z0-9 ]/g, " ").trim();
  return clean.split(/\s+/).filter(Boolean).join("");
}

function slugCandidates(company) {
  const clean = String(company || "").toLowerCase()
    // Drop legal suffixes before slugifying: "Volkswagen AG" and "Volkswagen
    // Group" must both reach volkswagen.*, not volkswagenag.*.
    .replace(/\b(inc|llc|ltd|limited|gmbh|ag|sa|sas|sarl|bv|nv|plc|corp|corporation|co|company|group|holdings?|international|srl|spa|oy|ab|as|kk)\b/g, " ")
    .replace(/[^a-z0-9 ]/g, " ").trim();
  const words = clean.split(/\s+/).filter(Boolean);
  if (!words.length) return [];

  const joined = words.join("");
  const first = words[0];
  // Acronyms below 4 letters collide with real, unrelated companies far too
  // often (an invented "Wolkvagen Frobnitz Holdings" yields "wf", and wf.com
  // is a real business with real MX records). Not worth the false positives.
  const acr = words.length > 1 ? words.map((w) => w[0]).join("") : "";
  const acronym = acr.length >= 4 ? acr : "";

  const bases = [...new Set([joined, first, acronym].filter((b) => b && b.length >= 2))];
  const tlds = [".com", ".io", ".co", ".net", ".de", ".fr"];
  // TLD-major order: every base is tried on .com before anything is tried on
  // .io. Under a tight subrequest budget the first few lookups must be the
  // most likely ones, and .com dwarfs the rest for B2B.
  const out = [];
  for (const t of tlds) for (const b of bases) out.push(b + t);
  return [...new Set(out)];
}

/**
 * Resolve a company NAME to a mail DOMAIN, evidence-gated.
 *
 * This is the step that did not exist anywhere in v2.0, and its absence is
 * where the fabrication lived. If nothing clears the evidence bar we return
 * `unresolved`, and an unresolved company MUST produce no email at all.
 */
async function resolveCompany(company, budget, domainCache) {
  const key = String(company).toLowerCase().trim();
  if (domainCache.has(key)) return domainCache.get(key);  // same company twice costs once

  const cands = slugCandidates(company).slice(0, MAX_DOMAIN_CANDIDATES);
  const tried = [];

  for (const domain of cands) {
    if (PUBLIC_MAIL.has(domain)) continue;
    if (budget.left <= 0) break;
    const mx = await hasMX(domain, budget);
    tried.push({ domain, mx });
    if (!mx) continue;

    // MX alone is weak — parked domains have MX. Require the homepage to load
    // and to look like it belongs to this company.
    let confidence = 0.55;
    let titleHit = false;
    try {
      if (!spend(budget)) throw new Error("budget");
      const r = await fetch(`https://${domain}/`, {
        redirect: "follow",
        headers: { "User-Agent": "Mozilla/5.0 (compatible; EnricherPro/5.3)" },
        cf: { cacheTtl: 300 },
      });
      if (r.ok) {
        confidence += 0.15;
        const finalHost = new URL(r.url).hostname.replace(/^www\./, "");
        if (finalHost === domain || finalHost.endsWith("." + domain)) confidence += 0.10;
        const html = (await r.text()).slice(0, 4000);
        const m = html.match(/<title[^>]*>([\s\S]{0,200})<\/title>/i);
        const title = fold(m ? m[1] : "");
        const words = String(company).toLowerCase()
          .replace(/[^a-z0-9 ]/g, " ").split(/\s+/).filter((w) => w.length > 3);
        if (words.some((w) => title.includes(fold(w)))) { confidence += 0.20; titleHit = true; }
      }
    } catch { /* homepage unreachable — MX-only evidence stands */ }

    // The decisive gate. MX + a homepage that loads is NOT evidence that this
    // domain belongs to this company -- every parked domain passes that. We
    // require either the company name on the page, or a domain whose base IS
    // the company's full name (in which case the domain is the evidence).
    const baseIsFullName = domain.split(".")[0] === fold(company).slice(0, domain.split(".")[0].length)
      && domain.split(".")[0].length >= 6
      && domain.split(".")[0] === slugBase(company);

    if (confidence >= 0.70 && (titleHit || baseIsFullName)) {
      const hit = { status: "resolved", domain,
                    confidence: Math.round(Math.min(0.95, confidence) * 1000) / 1000,
                    titleHit, baseIsFullName, tried };
      domainCache.set(key, hit);
      return hit;
    }
  }
  const miss = { status: "unresolved", domain: null, confidence: 0, tried };
  domainCache.set(key, miss);
  return miss;
}

// ───────────────────────────── enrichment core ───────────────────────────

function looksLikeLinkedIn(url) {
  // True only for a well-formed URL the CALLER supplied. We do not template
  // one, and we do not claim to have fetched the profile — LinkedIn blocks
  // server-side profile reads, so any such claim would be a lie.
  return /^https?:\/\/([a-z]{2,3}\.)?linkedin\.com\/in\/[^\/\s?]+/i.test(String(url || ""));
}

async function enrichOne(contact, env, cache, budget, domainCache) {
  const started = Date.now();
  const first = String(contact.firstname || contact.first_name || "").trim();
  const last = String(contact.lastname || contact.last_name || "").trim();
  const company = String(contact.company || "").trim();
  const linkedinIn = String(contact.linkedin_url || "").trim();

  const out = {
    firstname: first, lastname: last, company, title: contact.title || "",
    email: null,
    email_status: "no_result",
    email_confidence: 0.0,
    best_guess: null,
    best_guess_basis: null,
    verification_method: null,
    verification_detail: null,
    // Echoed back exactly as supplied. Never templated.
    linkedin_url: linkedinIn || null,
    linkedin_validated: looksLikeLinkedIn(linkedinIn),
    domain: null,
    notes: [],
    elapsed_ms: 0,
  };

  if (!first || !last || !company) {
    out.notes.push("Need firstname, lastname and company.");
    out.elapsed_ms = Date.now() - started;
    return out;
  }

  const apiKey = env.MILLIONVERIFIER_API_KEY || "";
  if (!apiKey) {
    out.email_status = "verifier_unavailable";
    out.notes.push(
      "No verifier configured (MILLIONVERIFIER_API_KEY unset). Nothing can be " +
      "confirmed, so no address is returned."
    );
    out.elapsed_ms = Date.now() - started;
    return out;
  }

  // Step 1 — company name to a real mail domain.
  const res = await resolveCompany(company, budget, domainCache);
  if (res.status !== "resolved") {
    out.email_status = "unresolved_company";
    out.notes.push(
      `Could not resolve "${company}" to a mail domain on the evidence ` +
      `available, so no address was generated.`
    );
    out.elapsed_ms = Date.now() - started;
    return out;
  }
  out.domain = res.domain;

  // Step 2 — probe candidates and be honest about the outcome.
  let best = null;
  const candidates = candidateAddresses(first, last, res.domain)
    .map((addr) => ({ addr, grade: matchEmail(addr, first, last) }))
    .filter((c) => USABLE.has(c.grade))
    .slice(0, MAX_PROBES_PER_DOMAIN);

  for (const { addr, grade } of candidates) {
    const v = await mvVerify(addr, grade, apiKey, cache, budget);
    if (v.error === "subrequest budget exhausted") break;

    if (v.verdict === "verified") {
      out.email = addr;
      out.email_status = "verified";
      out.email_confidence = Math.round(Math.min(0.97, res.confidence * v.confidence) * 1000) / 1000;
      out.verification_method = "millionverifier";
      out.verification_detail = v.result;
      out.notes.push(`Mailbox confirmed deliverable on ${res.domain}.`);
      out.elapsed_ms = Date.now() - started;
      return out;
    }

    if (v.verdict === "unconfirmed" && (!best || v.confidence > best.confidence)) {
      best = { addr, confidence: v.confidence, detail: v.result, grade };
    }

    if (v.catchAll) {
      // Every further probe on this domain returns catch_all too; continuing
      // spends credits for no new information.
      out.notes.push(
        `${res.domain} is a catch-all domain — no address on it can be ` +
        `confirmed by verification alone.`
      );
      break;
    }
  }

  // Step 3 — nothing verified.
  if (best) {
    out.best_guess = best.addr;
    out.best_guess_basis =
      `pattern match (${best.grade}) on ${res.domain}; verification ` +
      `inconclusive (millionverifier: ${best.detail})`;
    out.email_status = "unverified_guess";
    out.email_confidence = 0.0; // unverified is not a confidence, it is a gap
    out.notes.push("best_guess only — do not send to it without verification.");
  } else {
    out.notes.push(`No candidate on ${res.domain} passed verification.`);
  }

  out.elapsed_ms = Date.now() - started;
  return out;
}

// ──────────────────────────────── HTTP layer ─────────────────────────────

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj, null, 2), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "access-control-allow-origin": "*",
      "cache-control": "no-store",
    },
  });

function redact(key) {
  if (!key) return "(not set)";
  return key.length > 12 ? `${key.slice(0, 4)}…${key.slice(-4)} (${key.length} chars)` : "(set)";
}

async function handleApi(request, env, url) {
  const path = url.pathname;
  const hasKey = !!(env.MILLIONVERIFIER_API_KEY || "");

  if (request.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "access-control-allow-origin": "*",
        "access-control-allow-methods": "GET, POST, OPTIONS",
        "access-control-allow-headers": "content-type",
      },
    });
  }

  if (path === "/api/health" || path === "/health") {
    return json({
      status: "healthy",
      service: "EnricherPro API",
      version: VERSION,
      runtime: "cloudflare-worker",
      verifier: hasKey ? "MillionVerifier" : "unavailable",
      // The field that matters. When false this instance is structurally
      // incapable of returning a verified address. Monitor this, not `status`.
      can_claim_verified: hasKey,
    });
  }

  if (path === "/api/settings") {
    const live = url.searchParams.get("live") === "true";
    const block = {
      provider: "MillionVerifier",
      configured: hasKey,
      api_key: redact(env.MILLIONVERIFIER_API_KEY || ""),
      timeout: MV_TIMEOUT_SECONDS,
    };
    if (live && hasKey) {
      try {
        const c = await mvCredits(env.MILLIONVERIFIER_API_KEY);
        block.key_valid = true;
        block.credits_remaining = c.credits;
      } catch (e) {
        block.key_valid = false;
        block.error = String(e.message || e);
      }
    }
    const out = {
      service: "EnricherPro API",
      version: VERSION,
      verification: block,
      can_claim_verified: hasKey,
      batch_max_contacts: MAX_CONTACTS_PER_REQUEST,
      max_probes_per_domain: MAX_PROBES_PER_DOMAIN,
    };
    if (!hasKey) {
      out.warning =
        "No verifier configured. No address can be confirmed — every result " +
        "returns without an email. Set MILLIONVERIFIER_API_KEY.";
    }
    return json(out);
  }

  if (path === "/api/credits") {
    if (!hasKey) return json({ error: "MILLIONVERIFIER_API_KEY unset" }, 503);
    try { return json(await mvCredits(env.MILLIONVERIFIER_API_KEY)); }
    catch (e) { return json({ error: String(e.message || e) }, 502); }
  }

  // The Flutter app calls this on startup; answer it so the UI does not error.
  if (path === "/api/config/snovio") {
    return json({ configured: false, provider: "snovio", enabled: false });
  }

  if (path === "/api/enrich/batch" || path === "/api/enrich") {
    if (request.method !== "POST") return json({ error: "POST required" }, 405);

    let body;
    try { body = await request.json(); }
    catch { return json({ error: "invalid JSON body" }, 400); }

    let contacts = body.contacts || (body.firstname || body.lastname ? [body] : []);
    if (!Array.isArray(contacts) || contacts.length === 0) {
      return json({ error: "no contacts supplied" }, 400);
    }

    const originalCount = contacts.length;
    const truncated = contacts.length > MAX_CONTACTS_PER_REQUEST;
    contacts = contacts.slice(0, MAX_CONTACTS_PER_REQUEST);

    // Shared across the batch so repeated domains and addresses cost once.
    const cache = new Map();
    const domainCache = new Map();
    const budget = { left: SUBREQUEST_BUDGET };

    const results = [];
    let skipped = 0;
    for (const c of contacts) {
      if (budget.left <= 0) {
        // Report the untouched contacts explicitly rather than returning a
        // silently short list the caller might read as "nothing found".
        skipped += 1;
        results.push({
          firstname: c.firstname || "", lastname: c.lastname || "",
          company: c.company || "", title: c.title || "",
          email: null, email_status: "not_attempted", email_confidence: 0.0,
          best_guess: null, best_guess_basis: null,
          verification_method: null, verification_detail: null,
          linkedin_url: c.linkedin_url || null,
          linkedin_validated: looksLikeLinkedIn(c.linkedin_url),
          domain: null,
          notes: ["Not attempted — request lookup budget exhausted. Re-send " +
                  "this contact in a smaller batch."],
          elapsed_ms: 0,
        });
        continue;
      }
      results.push(await enrichOne(c, env, cache, budget, domainCache));
    }

    const verified = results.filter((r) => r.email_status === "verified").length;
    const guesses = results.filter((r) => r.email_status === "unverified_guess").length;

    const payload = {
      status: "success",
      total: results.length,
      results,
      summary: {
        verified,
        unverified_guess: guesses,
        not_attempted: skipped,
        no_result: results.length - verified - guesses - skipped,
        lookups_used: SUBREQUEST_BUDGET - budget.left,
        verified_rate_pct: Math.round((1000 * verified) / Math.max(results.length, 1)) / 10,
        verifier: hasKey ? "millionverifier" : "none",
      },
    };
    const warnings = [];
    if (truncated) {
      warnings.push(`Only the first ${MAX_CONTACTS_PER_REQUEST} of ` +
                    `${originalCount} contacts were accepted.`);
    }
    if (skipped) {
      warnings.push(`${skipped} contact(s) were not attempted because the ` +
                    `per-request lookup budget ran out. Send fewer per call.`);
    }
    if (warnings.length) payload.warning = warnings.join(" ");
    return json(payload);
  }

  return json({ error: "not found", path }, 404);
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname.startsWith("/api/") || url.pathname === "/health") {
      try {
        return await handleApi(request, env, url);
      } catch (e) {
        return json({ error: "internal error", detail: String(e && e.message || e) }, 500);
      }
    }

    // Everything else is the Flutter app. SPA fallback so deep links return
    // index.html rather than a 404 — required by the release checklist.
    const res = await env.ASSETS.fetch(request);
    if (res.status === 404 && request.method === "GET" &&
        !url.pathname.includes(".")) {
      return env.ASSETS.fetch(new Request(new URL("/index.html", url), request));
    }
    return res;
  },
};
