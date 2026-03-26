import json
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from app.db.models import OutboxEventModel


def publish_pending_outbox(db: Session, limit: int = 100) -> list[dict]:
    rows = (
        db.query(OutboxEventModel)
        .filter(OutboxEventModel.status == "pending")
        .order_by(OutboxEventModel.created_at.asc())
        .limit(limit)
        .all()
    )
    published = []
    for row in rows:
        row.status = "published"
        row.published_at = datetime.now(timezone.utc)
        published.append({
            "event_id": row.id,
            "event_type": row.event_type,
            "correlation_id": row.correlation_id,
            "payload": row.payload_json,
        })
    db.commit()
    return published
