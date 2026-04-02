"""
SQLite database setup for EnricherPro user management and file tracking.
"""

import sqlite3
import os
from pathlib import Path

DB_PATH = Path(__file__).parent / 'enricherpro.db'
UPLOADS_DIR = Path(__file__).parent / 'user_uploads'


def get_db():
    """Get a database connection with row factory."""
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def init_db():
    """Create all tables if they don't exist."""
    UPLOADS_DIR.mkdir(exist_ok=True)
    conn = get_db()
    cursor = conn.cursor()

    cursor.executescript("""
        CREATE TABLE IF NOT EXISTS users (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            first_name  TEXT NOT NULL,
            last_name   TEXT NOT NULL,
            company     TEXT NOT NULL,
            title       TEXT NOT NULL,
            email       TEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL,
            plan        TEXT NOT NULL DEFAULT 'free',
            is_active   INTEGER NOT NULL DEFAULT 1,
            created_at  TEXT NOT NULL DEFAULT (datetime('now')),
            last_login  TEXT
        );

        CREATE TABLE IF NOT EXISTS user_files (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id         INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            file_name       TEXT NOT NULL,
            original_path   TEXT,
            enriched_path   TEXT,
            record_count    INTEGER DEFAULT 0,
            enriched_count  INTEGER DEFAULT 0,
            success_rate    REAL DEFAULT 0.0,
            avg_confidence  REAL DEFAULT 0.0,
            status          TEXT NOT NULL DEFAULT 'pending',
            upload_date     TEXT NOT NULL DEFAULT (datetime('now')),
            completion_date TEXT,
            processing_secs INTEGER DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS api_keys (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            provider    TEXT NOT NULL,
            api_key     TEXT NOT NULL,
            is_active   INTEGER NOT NULL DEFAULT 1,
            created_at  TEXT NOT NULL DEFAULT (datetime('now'))
        );

        CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
        CREATE INDEX IF NOT EXISTS idx_user_files_user ON user_files(user_id);
    """)

    conn.commit()
    conn.close()
    print("✅ Database initialised at", DB_PATH)


# ── User helpers ──────────────────────────────────────────────────────────────

def create_user(first_name, last_name, company, title, email, password_hash, plan='free'):
    conn = get_db()
    try:
        cursor = conn.execute(
            """INSERT INTO users (first_name, last_name, company, title, email, password_hash, plan)
               VALUES (?, ?, ?, ?, ?, ?, ?)""",
            (first_name, last_name, company, title, email.lower().strip(), password_hash, plan)
        )
        conn.commit()
        return cursor.lastrowid
    finally:
        conn.close()


def get_user_by_email(email):
    conn = get_db()
    try:
        row = conn.execute(
            "SELECT * FROM users WHERE email = ? AND is_active = 1",
            (email.lower().strip(),)
        ).fetchone()
        return dict(row) if row else None
    finally:
        conn.close()


def get_user_by_id(user_id):
    conn = get_db()
    try:
        row = conn.execute(
            "SELECT * FROM users WHERE id = ? AND is_active = 1", (user_id,)
        ).fetchone()
        return dict(row) if row else None
    finally:
        conn.close()


def update_last_login(user_id):
    conn = get_db()
    try:
        conn.execute(
            "UPDATE users SET last_login = datetime('now') WHERE id = ?", (user_id,)
        )
        conn.commit()
    finally:
        conn.close()


def email_exists(email):
    conn = get_db()
    try:
        row = conn.execute(
            "SELECT id FROM users WHERE email = ?", (email.lower().strip(),)
        ).fetchone()
        return row is not None
    finally:
        conn.close()


# ── File helpers ──────────────────────────────────────────────────────────────

def create_file_record(user_id, file_name, record_count=0):
    conn = get_db()
    try:
        cursor = conn.execute(
            """INSERT INTO user_files (user_id, file_name, record_count, status)
               VALUES (?, ?, ?, 'pending')""",
            (user_id, file_name, record_count)
        )
        conn.commit()
        return cursor.lastrowid
    finally:
        conn.close()


def update_file_record(file_id, **kwargs):
    """Update arbitrary columns on a file record."""
    allowed = {
        'original_path', 'enriched_path', 'enriched_count', 'success_rate',
        'avg_confidence', 'status', 'completion_date', 'processing_secs', 'record_count'
    }
    fields = {k: v for k, v in kwargs.items() if k in allowed}
    if not fields:
        return
    set_clause = ', '.join(f"{k} = ?" for k in fields)
    values = list(fields.values()) + [file_id]
    conn = get_db()
    try:
        conn.execute(f"UPDATE user_files SET {set_clause} WHERE id = ?", values)
        conn.commit()
    finally:
        conn.close()


def get_user_files(user_id, limit=50, offset=0):
    conn = get_db()
    try:
        rows = conn.execute(
            """SELECT * FROM user_files WHERE user_id = ?
               ORDER BY upload_date DESC LIMIT ? OFFSET ?""",
            (user_id, limit, offset)
        ).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


def get_file_by_id(file_id, user_id=None):
    conn = get_db()
    try:
        if user_id:
            row = conn.execute(
                "SELECT * FROM user_files WHERE id = ? AND user_id = ?",
                (file_id, user_id)
            ).fetchone()
        else:
            row = conn.execute(
                "SELECT * FROM user_files WHERE id = ?", (file_id,)
            ).fetchone()
        return dict(row) if row else None
    finally:
        conn.close()


def delete_file_record(file_id, user_id):
    conn = get_db()
    try:
        conn.execute(
            "DELETE FROM user_files WHERE id = ? AND user_id = ?", (file_id, user_id)
        )
        conn.commit()
    finally:
        conn.close()


# ── API key helpers ───────────────────────────────────────────────────────────

def upsert_api_key(user_id, provider, api_key):
    conn = get_db()
    try:
        existing = conn.execute(
            "SELECT id FROM api_keys WHERE user_id = ? AND provider = ?",
            (user_id, provider)
        ).fetchone()
        if existing:
            conn.execute(
                "UPDATE api_keys SET api_key = ?, is_active = 1 WHERE user_id = ? AND provider = ?",
                (api_key, user_id, provider)
            )
        else:
            conn.execute(
                "INSERT INTO api_keys (user_id, provider, api_key) VALUES (?, ?, ?)",
                (user_id, provider, api_key)
            )
        conn.commit()
    finally:
        conn.close()


def get_api_key(user_id, provider):
    conn = get_db()
    try:
        row = conn.execute(
            "SELECT api_key FROM api_keys WHERE user_id = ? AND provider = ? AND is_active = 1",
            (user_id, provider)
        ).fetchone()
        return row['api_key'] if row else None
    finally:
        conn.close()


if __name__ == '__main__':
    init_db()
