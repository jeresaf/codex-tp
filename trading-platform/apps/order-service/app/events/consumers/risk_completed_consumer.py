from sqlalchemy.orm import Session
from app.db.models import OrderIntentModel, ProcessedEventModel
from app.domain.state_machine import transition_order
from shared_events.inbox import has_processed_event, mark_event_processed


CONSUMER_NAME = "order-service"


def consume_risk_completed(db: Session, event: dict):
    event_id = event["event_id"]
    if has_processed_event(db, ProcessedEventModel, CONSUMER_NAME, event_id):
        return {"status": "skipped_duplicate"}

    payload = event["payload"]
    order = db.query(OrderIntentModel).filter(OrderIntentModel.id == payload["order_intent_id"]).first()
    if not order:
        return {"status": "missing_order"}

    if payload["decision"] == "pass":
        if order.intent_status == "risk_pending":
            transition_order(db, order, "risk_passed", reason="event_risk_passed")
    else:
        if order.intent_status == "risk_pending":
            transition_order(db, order, "risk_failed", reason="event_risk_failed")

    mark_event_processed(db, ProcessedEventModel, CONSUMER_NAME, event_id, event["event_type"])
    db.commit()
    return {"status": "processed"}
