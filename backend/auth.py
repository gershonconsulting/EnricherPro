"""
JWT authentication helpers for EnricherPro.
"""

import os
import jwt
import datetime
from werkzeug.security import generate_password_hash, check_password_hash
from functools import wraps
from flask import request, jsonify
from database import get_user_by_id

# Secret key — override via JWT_SECRET env var in production
JWT_SECRET = os.environ.get('JWT_SECRET', 'change-me-in-production-use-a-long-random-string')
JWT_ALGORITHM = 'HS256'
JWT_EXPIRY_HOURS = 24 * 7  # 7 days


def hash_password(password: str) -> str:
    return generate_password_hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    return check_password_hash(password_hash, password)


def create_token(user_id: int, email: str) -> str:
    payload = {
        'sub': user_id,
        'email': email,
        'iat': datetime.datetime.utcnow(),
        'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=JWT_EXPIRY_HOURS),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def decode_token(token: str) -> dict | None:
    try:
        return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None


def _extract_token() -> str | None:
    auth_header = request.headers.get('Authorization', '')
    if auth_header.startswith('Bearer '):
        return auth_header[7:]
    return None


def require_auth(f):
    """Decorator that injects current_user into the route function."""
    @wraps(f)
    def decorated(*args, **kwargs):
        token = _extract_token()
        if not token:
            return jsonify({'error': 'Missing authorization token'}), 401

        payload = decode_token(token)
        if not payload:
            return jsonify({'error': 'Invalid or expired token'}), 401

        user = get_user_by_id(payload['sub'])
        if not user:
            return jsonify({'error': 'User not found'}), 401

        return f(current_user=user, *args, **kwargs)
    return decorated


def validate_password_strength(password: str) -> str | None:
    """Return an error message or None if password is acceptable."""
    if len(password) < 8:
        return 'Password must be at least 8 characters'
    if not any(c.isdigit() for c in password):
        return 'Password must contain at least one number'
    if not any(c.isalpha() for c in password):
        return 'Password must contain at least one letter'
    return None
