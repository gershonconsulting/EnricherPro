# EnricherPro production domain

The intended public URLs are:

- `https://enricherpro.com` — Flutter web application
- `https://www.enricherpro.com` — redirects to the apex domain
- `https://enricherpro.com/api/*` — FastAPI service through the existing
  same-origin proxy

## DNS

Create these records with the DNS provider after the production hosts are known:

| Type | Name | Target |
| --- | --- | --- |
| A/ALIAS | `@` | Frontend host value |
| CNAME | `www` | `enricherpro.com` |

Do not copy placeholder IP addresses into DNS. Use the exact values supplied by
the selected frontend and backend hosts.

## Production requirements

1. Build Flutter web in release mode.
2. Serve `build/web` with SPA fallback to `index.html`.
3. Run the FastAPI application behind the same HTTPS reverse proxy.
4. Route `/api/*` and `/health` to FastAPI and all other paths to Flutter.
5. Keep the frontend API base URL as `/api`; this avoids browser CORS issues.
6. Configure `verify@enricherpro.com` with valid SPF and a resolvable hostname
   for SMTP handshakes.
7. Set `ENABLE_SMTP_CHECK=true` only on a host that permits outbound TCP port
   25. Many cloud platforms block it.
8. Add uptime checks for `/health` and a synthetic validation request.

## DNS email authentication

SMTP recipient checks do not send message content, but receiving servers still
judge the sender domain. Publish SPF for the validation server and configure
forward and reverse DNS for its public IP. DKIM and DMARC are also recommended
for any real application email sent from the domain.

## Release check

- Apex and `www` load with valid TLS.
- `www` redirects once to the apex.
- API requests stay on HTTPS and pass browser CORS checks.
- Deep links return the Flutter application, not a server 404.
- Invalid, risky, unknown, and valid email states are visually distinct.
- No API keys or `.env` files are included in the web bundle.
