import uuid
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from app.db.models import BrokerOrderModel, FillModel, OutboxEventModel, ProcessedEventModel
from shared_events.inbox import has_processed_event, mark_event_processed
from shared_events.outbox import append_outbox_event

CONSUMER_NAME = "execution-service"


def consume_risk_completed(db: Session, event: dict):
    event_id = event["event_id"]
    if has_processed_event(db, ProcessedEventModel, CONSUMER_NAME, event_id):
        return {"status": "skipped_duplicate"}

    payload = event["payload"]
    if payload["decision"] != "pass":
        mark_event_processed(db, ProcessedEventModel, CONSUMER_NAME, event_id, event["event_type"])
        db.commit()
        return {"status": "skipped_reject"}

    source = payload.get("source_order_payload", {})
    venue_id = source.get("venue_id")
    instrument_id = source.get("instrument_id")
    quantity = source.get("quantity", "0")
    price = source.get("execution_price", "0")

    broker_order = BrokerOrderModel(
        id=str(uuid.uuid4()),
        order_intent_id=payload["order_intent_id"],
        venue_id=venue_id,
        external_order_id=f"sim-{uuid.uuid4()}",
        broker_status="filled",
        raw_request=source,
        raw_response={"status": "filled"},
        correlation_id=event.get("correlation_id"),
    )
    db.add(broker_order)
    db.flush()

    fill = FillModel(
        id=str(uuid.uuid4()),
        broker_order_id=broker_order.id,
        instrument_id=instrument_id,
        fill_price=price,
        fill_quantity=quantity,
        fee_amount="0.0",
        fee_currency="USD",
        correlation_id=event.get("correlation_id"),
        raw_payload={"simulation": True},
    )
    db.add(fill)

    append_outbox_event(
        db=db,
        model_cls=OutboxEventModel,
        aggregate_type="fill",
        aggregate_id=fill.id,
        event_type="execution.fill.recorded",
        event_version=1,
        correlation_id=event.get("correlation_id"),
        causation_id=event_id,
        payload_json={
            "broker_order_id": broker_order.id,
            "fill_id": fill.id,
            "order_intent_id": payload["order_intent_id"],
            "instrument_id": instrument_id,
            "side": source.get("side"),
            "quantity": quantity,
            "price": price,
            "fee_amount": "0.0",
            "fee_currency": "USD",
        },
    )

    mark_event_processed(db, ProcessedEventModel, CONSUMER_NAME, event_id, event["event_type"])
    db.commit()
    return {"status": "processed", "fill_id": fill.id}
