import uuid
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from app.db.models import PortfolioTargetModel, OutboxEventModel, ProcessedEventModel
from shared_events.inbox import has_processed_event, mark_event_processed
from shared_events.outbox import append_outbox_event
from shared_portfolio.allocation import weighted_direction_score, target_quantity_from_score

CONSUMER_NAME = "portfolio-service"


def consume_signal_generated(db: Session, event: dict):
    event_id = event["event_id"]
    if has_processed_event(db, ProcessedEventModel, CONSUMER_NAME, event_id):
        return {"status": "skipped_duplicate"}

    payload = event["payload"]
    strategy_weight = 0.2
    score = weighted_direction_score(
        direction=payload["direction"],
        strength=float(payload["strength"]),
        confidence=float(payload["confidence"]),
        strategy_weight=strategy_weight,
    )
    target_qty = target_quantity_from_score(score, base_quantity=1000.0)
    current_qty = 0.0
    delta_qty = target_qty - current_qty

    target = PortfolioTargetModel(
        id=str(uuid.uuid4()),
        account_id=None,
        instrument_id=payload["instrument_id"],
        target_quantity=target_qty,
        current_quantity=current_qty,
        delta_quantity=delta_qty,
        source_signal_ids={"signal_ids": [payload["signal_id"]]},
        allocation_snapshot={"strategy_weight": strategy_weight, "capital_budget": 10000},
        correlation_id=event.get("correlation_id"),
        target_timestamp=datetime.now(timezone.utc),
    )
    db.add(target)
    db.flush()

    append_outbox_event(
        db=db,
        model_cls=OutboxEventModel,
        aggregate_type="portfolio_target",
        aggregate_id=target.id,
        event_type="portfolio.target.generated",
        event_version=1,
        correlation_id=event.get("correlation_id"),
        causation_id=event_id,
        payload_json={
            "target_id": target.id,
            "account_id": None,
            "instrument_id": payload["instrument_id"],
            "target_quantity": str(target_qty),
            "current_quantity": str(current_qty),
            "delta_quantity": str(delta_qty),
            "source_signal_ids": [payload["signal_id"]],
            "allocation_snapshot": {"strategy_weight": strategy_weight, "capital_budget": 10000},
        },
    )

    mark_event_processed(db, ProcessedEventModel, CONSUMER_NAME, event_id, event["event_type"])
    db.commit()
    return {"status": "processed", "target_id": target.id}
