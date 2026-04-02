"""
EnricherPro API Server
Handles: auth, contact enrichment, email search, file management.
"""

import io
import csv
import time
import json
import os
from pathlib import Path
from flask import Flask, request, jsonify, send_file
from flask_cors import CORS

from database import init_db, email_exists, create_user, get_user_by_email, \
    update_last_login, upsert_api_key, get_api_key
from auth import hash_password, verify_password, create_token, require_auth, \
    validate_password_strength
from file_manager import (save_original_file, save_enriched_file,
                           mark_file_failed, read_original_file,
                           read_enriched_file, remove_file, list_user_files)
from email_providers import EmailSearchEngine
from fast_contact_enricher import FastContactEnricher
from email_validator import EmailValidator

# ── Initialise ────────────────────────────────────────────────────────────────
init_db()

app = Flask(__name__)
CORS(app)

_fast_enricher = FastContactEnricher()
_email_validator = EmailValidator()

# ── Helpers ───────────────────────────────────────────────────────────────────

def _load_env():
    env_path = Path(__file__).parent / '.env'
    if env_path.exists():
        with open(env_path) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    k, v = line.split('=', 1)
                    os.environ.setdefault(k.strip(), v.strip())

_load_env()


def _engine_for_user(user_id: int) -> EmailSearchEngine:
    """Build an EmailSearchEngine with whatever API keys the user has stored."""
    providers = ['hunter', 'zerobounce', 'neverbounce', 'apollo',
                 'clearbit', 'snovio_client_id', 'snovio_client_secret']
    keys = {p: get_api_key(user_id, p) for p in providers}
    keys = {k: v for k, v in keys.items() if v}
    return EmailSearchEngine(api_keys=keys)


def _safe_json(body):
    try:
        return request.get_json(force=True) or {}
    except Exception:
        return {}


# ─────────────────────────────────────────────────────────────────────────────
# AUTH ENDPOINTS
# ─────────────────────────────────────────────────────────────────────────────

@app.route('/api/auth/register', methods=['POST'])
def register():
    data = _safe_json(request.data)
    required = ['first_name', 'last_name', 'company', 'title', 'email', 'password']
    missing = [f for f in required if not data.get(f, '').strip()]
    if missing:
        return jsonify({'error': f'Missing fields: {", ".join(missing)}'}), 400

    email = data['email'].lower().strip()
    import re
    if not re.match(r'^[^@]+@[^@]+\.[^@]+$', email):
        return jsonify({'error': 'Invalid email address'}), 400

    if email_exists(email):
        return jsonify({'error': 'An account with that email already exists'}), 409

    pw_error = validate_password_strength(data['password'])
    if pw_error:
        return jsonify({'error': pw_error}), 400

    user_id = create_user(
        first_name=data['first_name'].strip(),
        last_name=data['last_name'].strip(),
        company=data['company'].strip(),
        title=data['title'].strip(),
        email=email,
        password_hash=hash_password(data['password']),
        plan=data.get('plan', 'free'),
    )

    token = create_token(user_id, email)
    return jsonify({
        'token': token,
        'user': {
            'id': user_id,
            'first_name': data['first_name'].strip(),
            'last_name': data['last_name'].strip(),
            'email': email,
            'plan': data.get('plan', 'free'),
        }
    }), 201


@app.route('/api/auth/login', methods=['POST'])
def login():
    data = _safe_json(request.data)
    email = (data.get('email') or '').lower().strip()
    password = data.get('password', '')

    if not email or not password:
        return jsonify({'error': 'Email and password are required'}), 400

    user = get_user_by_email(email)
    if not user or not verify_password(password, user['password_hash']):
        return jsonify({'error': 'Invalid email or password'}), 401

    update_last_login(user['id'])
    token = create_token(user['id'], user['email'])
    return jsonify({
        'token': token,
        'user': {
            'id': user['id'],
            'first_name': user['first_name'],
            'last_name': user['last_name'],
            'email': user['email'],
            'plan': user['plan'],
        }
    }), 200


@app.route('/api/auth/me', methods=['GET'])
@require_auth
def me(current_user):
    u = current_user
    return jsonify({
        'id': u['id'],
        'first_name': u['first_name'],
        'last_name': u['last_name'],
        'company': u['company'],
        'title': u['title'],
        'email': u['email'],
        'plan': u['plan'],
        'created_at': u['created_at'],
        'last_login': u['last_login'],
    }), 200


# ─────────────────────────────────────────────────────────────────────────────
# API KEY MANAGEMENT
# ─────────────────────────────────────────────────────────────────────────────

@app.route('/api/keys', methods=['POST'])
@require_auth
def save_api_key(current_user):
    """Store a provider API key for the authenticated user."""
    data = _safe_json(request.data)
    provider = data.get('provider', '').strip()
    api_key = data.get('api_key', '').strip()

    valid_providers = ['hunter', 'zerobounce', 'neverbounce', 'apollo',
                       'clearbit', 'snovio_client_id', 'snovio_client_secret']
    if provider not in valid_providers:
        return jsonify({'error': f'Unknown provider. Valid: {valid_providers}'}), 400
    if not api_key:
        return jsonify({'error': 'api_key is required'}), 400

    upsert_api_key(current_user['id'], provider, api_key)
    return jsonify({'status': 'saved', 'provider': provider}), 200


@app.route('/api/keys/providers', methods=['GET'])
@require_auth
def list_providers(current_user):
    """Return which paid providers the user has configured."""
    engine = _engine_for_user(current_user['id'])
    return jsonify(engine.available_providers()), 200


# ─────────────────────────────────────────────────────────────────────────────
# ENRICHMENT ENDPOINTS
# ─────────────────────────────────────────────────────────────────────────────

@app.route('/api/enrich', methods=['POST'])
def enrich_contact():
    data = _safe_json(request.data)
    required = ['firstname', 'lastname', 'title', 'company']
    if not all(data.get(f) for f in required):
        return jsonify({'error': 'Missing required fields'}), 400

    # Detect authenticated user for paid providers (optional)
    user_id = _get_optional_user_id()
    if user_id:
        engine = _engine_for_user(user_id)
        result = engine.search(data['firstname'], data['lastname'], data['company'])
        enriched = _merge_enrichment(data, result)
    else:
        enriched = _fast_enricher.enrich_contact(
            data['firstname'], data['lastname'], data['title'], data['company'])
    return jsonify(enriched), 200


@app.route('/api/enrich/batch', methods=['POST'])
def enrich_batch():
    data = _safe_json(request.data)
    contacts = data.get('contacts')
    if not isinstance(contacts, list):
        return jsonify({'error': 'Expected {"contacts": [...]}'}), 400

    user_id = _get_optional_user_id()
    engine = _engine_for_user(user_id) if user_id else None

    results = []
    for c in contacts:
        try:
            if all(c.get(k) for k in ['firstname', 'lastname', 'title', 'company']):
                if engine:
                    r = engine.search(c['firstname'], c['lastname'], c['company'])
                    results.append(_merge_enrichment(c, r))
                else:
                    results.append(_fast_enricher.enrich_contact(
                        c['firstname'], c['lastname'], c['title'], c['company']))
            else:
                results.append({**c, 'email': '', 'email_confidence': 0.0,
                                 'linkedin_url': '', 'enrichment_status': 'missing_fields'})
        except Exception as e:
            results.append({**c, 'email': '', 'email_confidence': 0.0,
                             'linkedin_url': '', 'enrichment_status': f'error: {e}'})

    return jsonify({'results': results, 'total': len(results), 'status': 'completed'}), 200


def _get_optional_user_id():
    """Return user_id from Bearer token if present, else None."""
    auth = request.headers.get('Authorization', '')
    if auth.startswith('Bearer '):
        from auth import decode_token
        payload = decode_token(auth[7:])
        if payload:
            return payload.get('sub')
    return None


def _merge_enrichment(contact: dict, result) -> dict:
    """Combine raw contact dict with an EmailResult."""
    linkedin = _fast_enricher.generate_linkedin_urls(
        contact.get('firstname', ''), contact.get('lastname', ''), contact.get('company', ''))
    search = _fast_enricher.generate_linkedin_search_url(
        contact.get('firstname', ''), contact.get('lastname', ''), contact.get('company', ''))
    return {
        **contact,
        'email': result.email,
        'email_confidence': round(result.confidence, 4),
        'email_source': result.source,
        'email_verified': result.verified,
        'email_all_patterns': result.all_patterns,
        'linkedin_url': linkedin[0] if linkedin else '',
        'linkedin_alternatives': linkedin[1:],
        'linkedin_search': search,
        'enrichment_status': 'completed',
    }


# ─────────────────────────────────────────────────────────────────────────────
# FILE MANAGEMENT ENDPOINTS
# ─────────────────────────────────────────────────────────────────────────────

@app.route('/api/files', methods=['GET'])
@require_auth
def get_files(current_user):
    limit = min(int(request.args.get('limit', 50)), 100)
    offset = int(request.args.get('offset', 0))
    files = list_user_files(current_user['id'], limit=limit, offset=offset)
    # Strip filesystem paths before returning
    for f in files:
        f.pop('original_path', None)
        f.pop('enriched_path', None)
    return jsonify({'files': files, 'total': len(files)}), 200


@app.route('/api/files/upload', methods=['POST'])
@require_auth
def upload_file(current_user):
    """
    Upload a CSV for enrichment.
    Multipart form: field 'file' = CSV bytes, 'record_count' = int (optional).
    """
    if 'file' not in request.files:
        return jsonify({'error': 'No file part'}), 400
    f = request.files['file']
    if not f.filename:
        return jsonify({'error': 'No file selected'}), 400

    file_bytes = f.read()
    record_count = int(request.form.get('record_count', 0))

    file_id = save_original_file(
        user_id=current_user['id'],
        file_name=f.filename,
        file_bytes=file_bytes,
        record_count=record_count,
    )

    # Kick off enrichment synchronously (for now; use a task queue in production)
    _enrich_file_sync(file_id, current_user['id'], file_bytes)

    return jsonify({'file_id': file_id, 'status': 'processing'}), 202


def _enrich_file_sync(file_id: int, user_id: int, csv_bytes: bytes):
    """Read CSV, enrich every contact row, save enriched CSV."""
    start = time.time()
    try:
        text = csv_bytes.decode('utf-8-sig', errors='replace')
        reader = list(csv.DictReader(io.StringIO(text)))
        if not reader:
            mark_file_failed(file_id)
            return

        engine = _engine_for_user(user_id)
        enriched_rows = []
        total_confidence = 0.0
        enriched_count = 0

        for row in reader:
            first = (row.get('First Name') or row.get('firstname') or row.get('first_name') or '').strip()
            last  = (row.get('Last Name')  or row.get('lastname')  or row.get('last_name')  or '').strip()
            company = (row.get('Company') or row.get('company') or '').strip()
            title = (row.get('Title') or row.get('title') or '').strip()

            if first and last and company:
                result = engine.search(first, last, company)
                row['Email']            = result.email
                row['Email Confidence'] = f'{result.confidence:.0%}'
                row['Email Source']     = result.source
                row['Email Verified']   = str(result.verified)
                if result.email:
                    enriched_count += 1
                    total_confidence += result.confidence
            enriched_rows.append(row)

        # Serialise back to CSV
        out = io.StringIO()
        if enriched_rows:
            writer = csv.DictWriter(out, fieldnames=list(enriched_rows[0].keys()))
            writer.writeheader()
            writer.writerows(enriched_rows)

        success_rate = enriched_count / len(reader) if reader else 0.0
        avg_conf = total_confidence / enriched_count if enriched_count else 0.0

        save_enriched_file(
            file_id=file_id,
            user_id=user_id,
            enriched_bytes=out.getvalue().encode('utf-8'),
            enriched_count=enriched_count,
            success_rate=success_rate,
            avg_confidence=avg_conf,
            processing_secs=int(time.time() - start),
        )
    except Exception as e:
        print(f'Enrichment error for file {file_id}: {e}')
        mark_file_failed(file_id)


@app.route('/api/files/<int:file_id>/download/original', methods=['GET'])
@require_auth
def download_original(current_user, file_id):
    content = read_original_file(file_id, current_user['id'])
    if content is None:
        return jsonify({'error': 'File not found'}), 404
    return send_file(
        io.BytesIO(content),
        mimetype='text/csv',
        as_attachment=True,
        download_name=f'original_{file_id}.csv',
    )


@app.route('/api/files/<int:file_id>/download/enriched', methods=['GET'])
@require_auth
def download_enriched(current_user, file_id):
    content = read_enriched_file(file_id, current_user['id'])
    if content is None:
        return jsonify({'error': 'Enriched file not found or not ready yet'}), 404
    return send_file(
        io.BytesIO(content),
        mimetype='text/csv',
        as_attachment=True,
        download_name=f'enriched_{file_id}.csv',
    )


@app.route('/api/files/<int:file_id>', methods=['DELETE'])
@require_auth
def delete_file(current_user, file_id):
    removed = remove_file(file_id, current_user['id'])
    if not removed:
        return jsonify({'error': 'File not found'}), 404
    return jsonify({'status': 'deleted'}), 200


# ─────────────────────────────────────────────────────────────────────────────
# LEGACY / VALIDATION ENDPOINTS (unchanged, no auth required)
# ─────────────────────────────────────────────────────────────────────────────

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'EnricherPro API', 'version': '5.0.0'}), 200


@app.route('/api/validate/email', methods=['POST'])
def validate_email():
    data = _safe_json(request.data)
    if 'email' not in data:
        return jsonify({'error': 'Missing email field'}), 400
    r = _email_validator.validate_email_comprehensive(data['email'])
    return jsonify({
        'email': r.email,
        'is_valid': r.is_valid,
        'confidence_score': round(r.confidence_score, 2),
        'mx_valid': r.mx_valid,
        'smtp_valid': r.smtp_valid,
        'is_catchall': r.is_catchall,
        'bounce_probability': round(r.bounce_probability, 2),
        'details': r.details,
    }), 200


@app.route('/api/patterns/email', methods=['POST'])
def email_patterns():
    data = _safe_json(request.data)
    if not all(data.get(k) for k in ['firstname', 'lastname', 'company']):
        return jsonify({'error': 'Missing required fields'}), 400
    patterns = _fast_enricher.generate_email_patterns(
        data['firstname'], data['lastname'], data['company'])
    return jsonify({'patterns': patterns, 'count': len(patterns)}), 200


@app.route('/api/patterns/linkedin', methods=['POST'])
def linkedin_patterns():
    data = _safe_json(request.data)
    if not all(data.get(k) for k in ['firstname', 'lastname', 'company']):
        return jsonify({'error': 'Missing required fields'}), 400
    urls = _fast_enricher.generate_linkedin_urls(
        data['firstname'], data['lastname'], data['company'])
    search = _fast_enricher.generate_linkedin_search_url(
        data['firstname'], data['lastname'], data['company'])
    return jsonify({'linkedin_urls': urls, 'linkedin_search': search, 'count': len(urls)}), 200


# Legacy Snovio config endpoint
@app.route('/api/config/snovio', methods=['POST'])
def config_snovio():
    data = _safe_json(request.data)
    credentials = data.get('api_key', '')
    if not credentials:
        return jsonify({'error': 'Missing api_key'}), 400
    # Store globally via env so existing code still works
    if credentials.startswith('oauth:'):
        parts = credentials.split(':')
        if len(parts) == 3:
            os.environ['SNOVIO_CLIENT_ID'] = parts[1]
            os.environ['SNOVIO_CLIENT_SECRET'] = parts[2]
    else:
        os.environ['SNOVIO_API_KEY'] = credentials
    return jsonify({'status': 'success', 'snovio_enabled': True}), 200


# ─────────────────────────────────────────────────────────────────────────────
if __name__ == '__main__':
    print('\n' + '='*60)
    print('EnricherPro API v5.0 — with Auth & File Management')
    print('='*60)
    app.run(host='0.0.0.0', port=5000, debug=False)
