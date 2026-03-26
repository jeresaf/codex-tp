import uuid


def has_processed_event(db, model_cls, consumer_service: str, event_id: str) -> bool:
    row = db.query(model_cls).filter(
        model_cls.consumer_service == consumer_service,
        model_cls.event_id == event_id,
    ).first()
    return row is not None


def mark_event_processed(db, model_cls, consumer_service: str, event_id: str, event_type: str):
    row = model_cls(
        id=str(uuid.uuid4()),
        consumer_service=consumer_service,
        event_id=event_id,
        event_type=event_type,
    )
    db.add(row)
    return row
