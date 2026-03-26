#!/usr/bin/env bash
set -euo pipefail

# Event-driven upgrade bootstrap writer.
# Run inside the existing trading-platform repo root.

ROOT="$(pwd)"
if [ ! -f "$ROOT/docker-compose.yml" ]; then
  echo "Run this inside the trading-platform repo root."
  exit 1
fi

mkdir -p \
  packages/shared-events/shared_events \
  apps/order-service/app/events/{outbox,publishers,consumers} \
  apps/risk-service/app/events/{consumers,outbox,publishers} \
  apps/execution-service/app/events/{consumers,outbox,publishers} \
  apps/position-service/app/events/{consumers,outbox,publishers} \
  sql

cat > packages/shared-events/shared_events/__init__.py <<'EOF'
EOF

cat > packages/shared-events/shared_events/envelope.py <<'EOF'
from pydantic import BaseModel
from typing import Any


class EventEnvelope(BaseModel):
    event_id: str
    event_type: str
    event_version: int
    source_service: str
    environment: str
    occurred_at: str
    correlation_id: str | None = None
    causation_id: str | None = None
    actor_type: str = "system"
    actor_id: str | None = None
    payload: dict[str, Any]
EOF

cat > packages/shared-events/shared_events/outbox.py <<'EOF'
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
EOF

cat > packages/shared-events/shared_events/inbox.py <<'EOF'
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
EOF

cat > sql/007_event_driven.sql <<'EOF'
CREATE TABLE IF NOT EXISTS outbox_events (
    id UUID PRIMARY KEY,
    aggregate_type VARCHAR(100) NOT NULL,
    aggregate_id UUID NOT NULL,
    event_type VARCHAR(150) NOT NULL,
    event_version INT NOT NULL,
    correlation_id UUID,
    causation_id UUID,
    payload_json JSONB NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    retry_count INT NOT NULL DEFAULT 0,
    next_attempt_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    published_at TIMESTAMPTZ,
    last_error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS processed_events (
    id UUID PRIMARY KEY,
    consumer_service VARCHAR(100) NOT NULL,
    event_id UUID NOT NULL,
    event_type VARCHAR(150) NOT NULL,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(consumer_service, event_id)
);
EOF

python - <<'PY'
from pathlib import Path
p = Path('scripts/migrate/run_all.sh')
text = p.read_text()
if 'sql/007_event_driven.sql' not in text:
    text = text.replace('sql/006_hardening.sql', 'sql/006_hardening.sql \\\n         sql/007_event_driven.sql')
    p.write_text(text)
PY

cat > apps/order-service/app/db/models.py <<'EOF'
from sqlalchemy import String, Numeric, DateTime, JSON, Integer, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base


class OrderIntentModel(Base):
    __tablename__ = "order_intents"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    strategy_deployment_id: Mapped[str] = mapped_column(String, nullable=True)
    account_id: Mapped[str] = mapped_column(String, nullable=True)
    instrument_id: Mapped[str] = mapped_column(String, nullable=False)
    signal_id: Mapped[str] = mapped_column(String, nullable=True)
    side: Mapped[str] = mapped_column(String(10), nullable=False)
    order_type: Mapped[str] = mapped_column(String(20), nullable=False)
    quantity: Mapped[float] = mapped_column(Numeric(24, 10), nullable=False)
    limit_price: Mapped[float] = mapped_column(Numeric(24, 10), nullable=True)
    stop_price: Mapped[float] = mapped_column(Numeric(24, 10), nullable=True)
    tif: Mapped[str] = mapped_column(String(20), nullable=False)
    intent_status: Mapped[str] = mapped_column(String(50), nullable=False, default="draft")
    correlation_id: Mapped[str] = mapped_column(String, nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())


class OrderStateHistoryModel(Base):
    __tablename__ = "order_state_history"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    order_intent_id: Mapped[str] = mapped_column(String, nullable=False)
    from_state: Mapped[str] = mapped_column(String(50), nullable=True)
    to_state: Mapped[str] = mapped_column(String(50), nullable=False)
    transition_reason: Mapped[str] = mapped_column(String(255), nullable=True)
    actor_type: Mapped[str] = mapped_column(String(50), nullable=False)
    actor_id: Mapped[str] = mapped_column(String, nullable=True)
    metadata_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())


class IdempotencyKeyModel(Base):
    __tablename__ = "idempotency_keys"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    scope: Mapped[str] = mapped_column(String(100), nullable=False)
    idempotency_key: Mapped[str] = mapped_column(String(255), nullable=False)
    response_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())


class OutboxEventModel(Base):
    __tablename__ = "outbox_events"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    aggregate_type: Mapped[str] = mapped_column(String(100), nullable=False)
    aggregate_id: Mapped[str] = mapped_column(String, nullable=False)
    event_type: Mapped[str] = mapped_column(String(150), nullable=False)
    event_version: Mapped[int] = mapped_column(Integer, nullable=False)
    correlation_id: Mapped[str] = mapped_column(String, nullable=True)
    causation_id: Mapped[str] = mapped_column(String, nullable=True)
    payload_json: Mapped[dict] = mapped_column(JSON, nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="pending")
    retry_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    next_attempt_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    published_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
    last_error: Mapped[str] = mapped_column(String, nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())


class ProcessedEventModel(Base):
    __tablename__ = "processed_events"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    consumer_service: Mapped[str] = mapped_column(String(100), nullable=False)
    event_id: Mapped[str] = mapped_column(String, nullable=False)
    event_type: Mapped[str] = mapped_column(String(150), nullable=False)
    processed_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
EOF

cat > apps/order-service/app/events/publishers/outbox_publisher.py <<'EOF'
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
EOF

cat > apps/order-service/app/events/consumers/risk_completed_consumer.py <<'EOF'
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
EOF

cat > apps/order-service/app/api/routes/orders.py <<'EOF'
import uuid
from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.db.models import OrderIntentModel, OutboxEventModel
from app.api.schemas import OrderIntentCreate
from app.domain.idempotency import get_idempotent_response, store_idempotent_response
from app.domain.state_machine import transition_order
from app.config import settings
from shared_auth.dependencies import require_user_context
from shared_observability.correlation import get_or_create_correlation_id
from shared_events.outbox import append_outbox_event

router = APIRouter()


@router.get("/")
def list_orders(
    db: Session = Depends(get_db),
    user=Depends(require_user_context(settings.jwt_secret, settings.jwt_algorithm)),
):
    rows = db.query(OrderIntentModel).order_by(OrderIntentModel.created_at.desc()).all()
    return [
        {
            "id": x.id,
            "instrument_id": x.instrument_id,
            "side": x.side,
            "order_type": x.order_type,
            "quantity": str(x.quantity),
            "intent_status": x.intent_status,
            "correlation_id": x.correlation_id,
            "created_at": x.created_at,
        }
        for x in rows
    ]


@router.post("/submit")
async def submit_order(
    payload: OrderIntentCreate,
    db: Session = Depends(get_db),
    user=Depends(require_user_context(settings.jwt_secret, settings.jwt_algorithm)),
    correlation_id: str = Depends(get_or_create_correlation_id),
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
):
    if idempotency_key:
        cached = get_idempotent_response(db, "order_submit_async", idempotency_key)
        if cached:
            return cached

    row = OrderIntentModel(
        id=str(uuid.uuid4()),
        strategy_deployment_id=payload.strategy_deployment_id,
        account_id=payload.account_id,
        instrument_id=payload.instrument_id,
        signal_id=payload.signal_id,
        side=payload.side,
        order_type=payload.order_type,
        quantity=payload.quantity,
        limit_price=payload.limit_price,
        stop_price=payload.stop_price,
        tif=payload.tif,
        intent_status="draft",
        correlation_id=correlation_id,
    )
    db.add(row)
    db.flush()

    append_outbox_event(
        db=db,
        model_cls=OutboxEventModel,
        aggregate_type="order_intent",
        aggregate_id=row.id,
        event_type="order_intent.created",
        event_version=1,
        correlation_id=correlation_id,
        causation_id=None,
        payload_json={
            "order_intent_id": row.id,
            "account_id": row.account_id,
            "instrument_id": row.instrument_id,
            "side": row.side,
            "order_type": row.order_type,
            "quantity": str(row.quantity),
            "tif": row.tif,
            "venue_id": payload.venue_id,
            "execution_price": str(payload.execution_price),
        },
    )
    transition_order(db, row, "risk_pending", reason="event_pipeline_started")
    db.commit()
    db.refresh(row)

    response = {
        "order_id": row.id,
        "status": "accepted",
        "intent_status": row.intent_status,
        "correlation_id": correlation_id,
    }
    if idempotency_key:
        store_idempotent_response(db, "order_submit_async", idempotency_key, response)
        db.commit()
    return response
EOF

cat > apps/risk-service/app/db/models.py <<'EOF'
from sqlalchemy import String, DateTime, JSON, Integer, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base


class RiskEvaluationModel(Base):
    __tablename__ = "risk_evaluations"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    order_intent_id: Mapped[str] = mapped_column(String, nullable=False)
    decision: Mapped[str] = mapped_column(String(20), nullable=False)
    next_state: Mapped[str] = mapped_column(String(50), nullable=False)
    rule_results: Mapped[dict] = mapped_column(JSON, nullable=False)
    evaluated_by_service: Mapped[str] = mapped_column(String(100), nullable=False)
    correlation_id: Mapped[str] = mapped_column(String, nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())


class OutboxEventModel(Base):
    __tablename__ = "outbox_events"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    aggregate_type: Mapped[str] = mapped_column(String(100), nullable=False)
    aggregate_id: Mapped[str] = mapped_column(String, nullable=False)
    event_type: Mapped[str] = mapped_column(String(150), nullable=False)
    event_version: Mapped[int] = mapped_column(Integer, nullable=False)
    correlation_id: Mapped[str] = mapped_column(String, nullable=True)
    causation_id: Mapped[str] = mapped_column(String, nullable=True)
    payload_json: Mapped[dict] = mapped_column(JSON, nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="pending")
    retry_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    next_attempt_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    published_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
    last_error: Mapped[str] = mapped_column(String, nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())


class ProcessedEventModel(Base):
    __tablename__ = "processed_events"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    consumer_service: Mapped[str] = mapped_column(String(100), nullable=False)
    event_id: Mapped[str] = mapped_column(String, nullable=False)
    event_type: Mapped[str] = mapped_column(String(150), nullable=False)
    processed_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
EOF

cat > apps/risk-service/app/events/consumers/order_created_consumer.py <<'EOF'
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
EOF

cat > apps/execution-service/app/db/models.py <<'EOF'
from sqlalchemy import String, Numeric, DateTime, JSON, Integer, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base


class BrokerOrderModel(Base):
    __tablename__ = "broker_orders"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    order_intent_id: Mapped[str] = mapped_column(String, nullable=False)
    venue_id: Mapped[str] = mapped_column(String, nullable=False)
    external_order_id: Mapped[str] = mapped_column(String(255), nullable=True)
    broker_status: Mapped[str] = mapped_column(String(50), nullable=False)
    raw_request: Mapped[dict] = mapped_column(JSON, nullable=True)
    raw_response: Mapped[dict] = mapped_column(JSON, nullable=True)
    correlation_id: Mapped[str] = mapped_column(String, nullable=True)
    submitted_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
    acknowledged_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)


class FillModel(Base):
    __tablename__ = "fills"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    broker_order_id: Mapped[str] = mapped_column(String, nullable=False)
    instrument_id: Mapped[str] = mapped_column(String, nullable=False)
    fill_price: Mapped[float] = mapped_column(Numeric(24, 10), nullable=False)
    fill_quantity: Mapped[float] = mapped_column(Numeric(24, 10), nullable=False)
    fee_amount: Mapped[float] = mapped_column(Numeric(24, 10), nullable=False, default=0)
    fee_currency: Mapped[str] = mapped_column(String(20), nullable=True)
    correlation_id: Mapped[str] = mapped_column(String, nullable=True)
    fill_time: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
    raw_payload: Mapped[dict] = mapped_column(JSON, nullable=True)


class OutboxEventModel(Base):
    __tablename__ = "outbox_events"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    aggregate_type: Mapped[str] = mapped_column(String(100), nullable=False)
    aggregate_id: Mapped[str] = mapped_column(String, nullable=False)
    event_type: Mapped[str] = mapped_column(String(150), nullable=False)
    event_version: Mapped[int] = mapped_column(Integer, nullable=False)
    correlation_id: Mapped[str] = mapped_column(String, nullable=True)
    causation_id: Mapped[str] = mapped_column(String, nullable=True)
    payload_json: Mapped[dict] = mapped_column(JSON, nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="pending")
    retry_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    next_attempt_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    published_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
    last_error: Mapped[str] = mapped_column(String, nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())


class ProcessedEventModel(Base):
    __tablename__ = "processed_events"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    consumer_service: Mapped[str] = mapped_column(String(100), nullable=False)
    event_id: Mapped[str] = mapped_column(String, nullable=False)
    event_type: Mapped[str] = mapped_column(String(150), nullable=False)
    processed_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
EOF

cat > apps/execution-service/app/events/consumers/risk_completed_consumer.py <<'EOF'
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
EOF

cat > apps/position-service/app/db/models.py <<'EOF'
from sqlalchemy import String, Numeric, DateTime, Integer, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base


class PositionModel(Base):
    __tablename__ = "positions"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    account_id: Mapped[str] = mapped_column(String, nullable=True)
    instrument_id: Mapped[str] = mapped_column(String, nullable=False)
    net_quantity: Mapped[float] = mapped_column(Numeric(24, 10), nullable=False, default=0)
    avg_price: Mapped[float] = mapped_column(Numeric(24, 10), nullable=False, default=0)
    market_value: Mapped[float] = mapped_column(Numeric(24, 10), nullable=False, default=0)
    unrealized_pnl: Mapped[float] = mapped_column(Numeric(24, 10), nullable=False, default=0)
    realized_pnl: Mapped[float] = mapped_column(Numeric(24, 10), nullable=False, default=0)
    updated_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class ProcessedEventModel(Base):
    __tablename__ = "processed_events"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    consumer_service: Mapped[str] = mapped_column(String(100), nullable=False)
    event_id: Mapped[str] = mapped_column(String, nullable=False)
    event_type: Mapped[str] = mapped_column(String(150), nullable=False)
    processed_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
EOF

cat > apps/position-service/app/events/consumers/fill_recorded_consumer.py <<'EOF'
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
EOF

cat > apps/order-service/app/events/demo_runner.py <<'EOF'
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
EOF

cat > scripts/smoke/event_pipeline_smoke.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
TOKEN=$(curl -s -X POST http://localhost:8001/api/auth/login -H "Content-Type: application/json" -d '{"email":"admin@example.com","password":"admin123"}' | python -c 'import sys,json; print(json.load(sys.stdin)["access_token"])')
INSTRUMENT_ID=$(PGPASSWORD=docker compose exec -T postgres psql -h localhost -U postgres -d trading_platform -t -A -c "SELECT id FROM instruments WHERE canonical_symbol='EURUSD' LIMIT 1;")
VENUE_ID=$(PGPASSWORD=docker compose exec -T postgres psql -h localhost -U postgres -d trading_platform -t -A -c "SELECT id FROM venues WHERE code='oanda-demo' LIMIT 1;")
curl -s -X POST http://localhost:8005/api/orders/submit \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: event-smoke-1" \
  -d "{\"instrument_id\":\"$INSTRUMENT_ID\",\"side\":\"buy\",\"order_type\":\"market\",\"quantity\":\"1000\",\"tif\":\"IOC\",\"venue_id\":\"$VENUE_ID\",\"execution_price\":\"1.0850\"}"
echo
EOF
chmod +x scripts/smoke/event_pipeline_smoke.sh

echo "Event-driven bootstrap applied."
echo "Next: bash scripts/migrate/run_all.sh && restart services."
