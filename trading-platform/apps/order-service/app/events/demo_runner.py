from sqlalchemy.orm import Session
from app.events.publishers.outbox_publisher import publish_pending_outbox
from app.events.consumers.risk_completed_consumer import consume_risk_completed as order_consume_risk_completed
from app.db.session import SessionLocal as OrderSessionLocal
from risk_service_bridge import risk_consume_order_created, risk_publish_outbox
from execution_service_bridge import execution_consume_risk_completed, execution_publish_outbox
from position_service_bridge import position_consume_fill_recorded


def run_event_pipeline_once():
    # publish order outbox
    with OrderSessionLocal() as db:
        order_events = publish_pending_outbox(db)

    # risk consumes order created
    risk_events = []
    for event in order_events:
        if event["event_type"] == "order_intent.created":
            risk_consume_order_created(event)
    risk_events = risk_publish_outbox()

    # order + execution consume risk completed
    exec_events = []
    for event in risk_events:
        if event["event_type"] == "risk.evaluation.completed":
            with OrderSessionLocal() as db:
                order_consume_risk_completed(db, event)
            execution_consume_risk_completed(event)
    exec_events = execution_publish_outbox()

    # position consumes fill recorded
    for event in exec_events:
        if event["event_type"] == "execution.fill.recorded":
            position_consume_fill_recorded(event)
