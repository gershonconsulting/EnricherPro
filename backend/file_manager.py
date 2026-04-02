"""
File management for EnricherPro — stores CSV files per user on disk
and keeps metadata in SQLite via database.py.
"""

import os
import uuid
import datetime
from pathlib import Path
from database import (
    UPLOADS_DIR, create_file_record, update_file_record,
    get_user_files, get_file_by_id, delete_file_record
)


def _user_dir(user_id: int) -> Path:
    d = UPLOADS_DIR / str(user_id)
    d.mkdir(parents=True, exist_ok=True)
    return d


def save_original_file(user_id: int, file_name: str,
                       file_bytes: bytes, record_count: int = 0) -> int:
    """
    Persist the original CSV and create a DB record.
    Returns the new file_id.
    """
    file_id = create_file_record(user_id, file_name, record_count)
    dest = _user_dir(user_id) / f"{file_id}_original_{file_name}"
    dest.write_bytes(file_bytes)
    update_file_record(file_id,
                       original_path=str(dest),
                       status='processing')
    return file_id


def save_enriched_file(file_id: int, user_id: int,
                       enriched_bytes: bytes,
                       enriched_count: int,
                       success_rate: float,
                       avg_confidence: float,
                       processing_secs: int) -> None:
    """Save enriched CSV and mark the record as completed."""
    rec = get_file_by_id(file_id, user_id)
    if not rec:
        return
    dest = _user_dir(user_id) / f"{file_id}_enriched_{rec['file_name']}"
    dest.write_bytes(enriched_bytes)
    update_file_record(
        file_id,
        enriched_path=str(dest),
        enriched_count=enriched_count,
        success_rate=round(success_rate, 4),
        avg_confidence=round(avg_confidence, 4),
        status='completed',
        completion_date=datetime.datetime.utcnow().isoformat(),
        processing_secs=processing_secs,
    )


def mark_file_failed(file_id: int) -> None:
    update_file_record(file_id, status='failed',
                       completion_date=datetime.datetime.utcnow().isoformat())


def read_original_file(file_id: int, user_id: int) -> bytes | None:
    rec = get_file_by_id(file_id, user_id)
    if not rec or not rec.get('original_path'):
        return None
    p = Path(rec['original_path'])
    return p.read_bytes() if p.exists() else None


def read_enriched_file(file_id: int, user_id: int) -> bytes | None:
    rec = get_file_by_id(file_id, user_id)
    if not rec or not rec.get('enriched_path'):
        return None
    p = Path(rec['enriched_path'])
    return p.read_bytes() if p.exists() else None


def remove_file(file_id: int, user_id: int) -> bool:
    """Delete file(s) from disk and remove DB record."""
    rec = get_file_by_id(file_id, user_id)
    if not rec:
        return False
    for key in ('original_path', 'enriched_path'):
        path = rec.get(key)
        if path:
            p = Path(path)
            if p.exists():
                p.unlink()
    delete_file_record(file_id, user_id)
    return True


def list_user_files(user_id: int, limit: int = 50, offset: int = 0) -> list:
    return get_user_files(user_id, limit=limit, offset=offset)
