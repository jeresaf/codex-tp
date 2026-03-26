import uuid
from datetime import datetime, timezone
from decimal import Decimal
from sqlalchemy.orm import Session
from app.db.models import RiskEvaluationModel, OutboxEventModel, ProcessedEventModel
from shared_events.inbox import has_processed_event, mark_event_processed
from shared_events.outbox import append_outbox_event

CONSUMER_NAME = "risk-service"


def evaluate_max_position_size(order_quantity: Decimal, max_allowed: Decimal):
    if order_quantity > max_allowed:
        return {
            "passed": False,
            "rule_type": "max_position_size",
            "message": "Order exceeds max position size",
            "severity": "high",
        }
    return {
        "passed": True,
        "rule_type": "max_position_size",
        "message": "Passed",
        "severity": "info",
    }


def consume_order_created(db: Session, event: dict):
    event_id = event["event_id"]
    if has_processed_event(db, ProcessedEventModel, CONSUMER_NAME, event_id):
        return {"status": "skipped_duplicate"}

    payload = event["payload"]
    results = [evaluate_max_position_size(Decimal(payload["quantity"]), Decimal("100000"))]
    failed = [r for r in results if not r["passed"]]
    decision = "reject" if failed else "pass"
    next_state = "risk_failed" if failed else "risk_passed"

    eval_row = RiskEvaluationModel(
        id=str(uuid.uuid4()),
        order_intent_id=payload["order_intent_id"],
        decision=decision,
        next_state=next_state,
        rule_results={"rule_results": results},
        evaluated_by_service="risk-service",
        correlation_id=event.get("correlation_id"),
    )
    db.add(eval_row)

    append_outbox_event(
        db=db,
        model_cls=OutboxEventModel,
        aggregate_type="risk_evaluation",
        aggregate_id=eval_row.id,
        event_type="risk.evaluation.completed",
        event_version=1,
        correlation_id=event.get("correlation_id"),
        causation_id=event_id,
        payload_json={
            "risk_evaluation_id": eval_row.id,
            "order_intent_id": payload["order_intent_id"],
            "decision": decision,
            "next_state": next_state,
            "rule_results": results,
        },
    )

    mark_event_processed(db, ProcessedEventModel, CONSUMER_NAME, event_id, event["event_type"])
    db.commit()
    return {"status": "processed", "decision": decision}
