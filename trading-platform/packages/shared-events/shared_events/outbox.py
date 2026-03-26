import uuid
from datetime import datetime, timezone


def append_outbox_event(
    db,
    model_cls,
    aggregate_type: str,
    aggregate_id: str,
    event_type: str,
    event_version: int,
    correlation_id: str | None,
    causation_id: str | None,
    payload_json: dict,
):
    row = model_cls(
        id=str(uuid.uuid4()),
        aggregate_type=aggregate_type,
        aggregate_id=aggregate_id,
        event_type=event_type,
        event_version=event_version,
        correlation_id=correlation_id,
        causation_id=causation_id,
        payload_json=payload_json,
        status="pending",
        next_attempt_at=datetime.now(timezone.utc),
    )
    db.add(row)
    return row
