import uuid
from decimal import Decimal
from sqlalchemy.orm import Session
from app.db.models import PositionModel, ProcessedEventModel
from app.domain.position_math import apply_fill
from shared_events.inbox import has_processed_event, mark_event_processed

CONSUMER_NAME = "position-service"


def consume_fill_recorded(db: Session, event: dict):
    event_id = event["event_id"]
    if has_processed_event(db, ProcessedEventModel, CONSUMER_NAME, event_id):
        return {"status": "skipped_duplicate"}

    payload = event["payload"]
    row = db.query(PositionModel).filter(
        PositionModel.account_id == None,
        PositionModel.instrument_id == payload["instrument_id"],
    ).first()

    if not row:
        row = PositionModel(
            id=str(uuid.uuid4()),
            account_id=None,
            instrument_id=payload["instrument_id"],
            net_quantity=0,
            avg_price=0,
            market_value=0,
            unrealized_pnl=0,
            realized_pnl=0,
        )
        db.add(row)
        db.flush()

    updated = apply_fill(
        {"net_quantity": row.net_quantity, "avg_price": row.avg_price},
        payload["side"],
        Decimal(str(payload["quantity"])),
        Decimal(str(payload["price"])),
    )
    row.net_quantity = updated["net_quantity"]
    row.avg_price = updated["avg_price"]

    mark_event_processed(db, ProcessedEventModel, CONSUMER_NAME, event_id, event["event_type"])
    db.commit()
    return {"status": "processed", "position_id": row.id}
