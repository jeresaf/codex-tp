#!/usr/bin/env bash
set -euo pipefail

# Hardening bootstrap writer for the first vertical slice.
# Run from inside the existing trading-platform repo created by the first bootstrap.

ROOT="$(pwd)"
if [ ! -f "$ROOT/docker-compose.yml" ]; then
  echo "Run this inside the trading-platform repo root."
  exit 1
fi

mkdir -p \
  packages/shared-auth/shared_auth \
  packages/shared-observability/shared_observability \
  apps/order-service/app/domain \
  apps/order-service/app/api \
  apps/order-service/app/api/routes \
  apps/order-service/app/db \
  apps/order-service/app/observability \
  apps/risk-service/app/db \
  apps/risk-service/app/api/routes \
  sql

cat > packages/shared-auth/shared_auth/dependencies.py <<'EOF'
from fastapi import Header, HTTPException
import jwt

JWT_ISSUER = "trading-platform"


def get_bearer_token(authorization: str | None = Header(default=None)) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    return authorization.replace("Bearer ", "", 1)


def decode_token(token: str, secret: str, algorithm: str) -> dict:
    try:
        return jwt.decode(token, secret, algorithms=[algorithm], issuer=JWT_ISSUER)
    except Exception as exc:
        raise HTTPException(status_code=401, detail=f"Invalid token: {exc}")


def require_user_context(secret: str, algorithm: str):
    def _dep(authorization: str | None = Header(default=None)) -> dict:
        token = get_bearer_token(authorization)
        return decode_token(token, secret, algorithm)
    return _dep


def validate_internal_service(expected_token: str):
    def _dep(
        x_service_name: str | None = Header(default=None),
        x_service_token: str | None = Header(default=None),
    ) -> dict:
        if not x_service_name or not x_service_token:
            raise HTTPException(status_code=401, detail="Missing internal auth headers")
        if x_service_token != expected_token:
            raise HTTPException(status_code=401, detail="Invalid internal service token")
        return {"service_name": x_service_name}
    return _dep
EOF

cat > packages/shared-observability/shared_observability/__init__.py <<'EOF'
EOF

cat > packages/shared-observability/shared_observability/correlation.py <<'EOF'
import uuid
from fastapi import Header


def get_or_create_correlation_id(x_correlation_id: str | None = Header(default=None)) -> str:
    return x_correlation_id or str(uuid.uuid4())
EOF

cat > sql/006_hardening.sql <<'EOF'
CREATE TABLE IF NOT EXISTS order_state_history (
    id UUID PRIMARY KEY,
    order_intent_id UUID NOT NULL REFERENCES order_intents(id),
    from_state VARCHAR(50),
    to_state VARCHAR(50) NOT NULL,
    transition_reason VARCHAR(255),
    actor_type VARCHAR(50) NOT NULL,
    actor_id UUID,
    metadata_json JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS risk_evaluations (
    id UUID PRIMARY KEY,
    order_intent_id UUID NOT NULL REFERENCES order_intents(id),
    decision VARCHAR(20) NOT NULL,
    next_state VARCHAR(50) NOT NULL,
    rule_results JSONB NOT NULL,
    evaluated_by_service VARCHAR(100) NOT NULL,
    correlation_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS idempotency_keys (
    id UUID PRIMARY KEY,
    scope VARCHAR(100) NOT NULL,
    idempotency_key VARCHAR(255) NOT NULL,
    response_json JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(scope, idempotency_key)
);

ALTER TABLE order_intents ADD COLUMN IF NOT EXISTS correlation_id UUID;
ALTER TABLE broker_orders ADD COLUMN IF NOT EXISTS correlation_id UUID;
ALTER TABLE fills ADD COLUMN IF NOT EXISTS correlation_id UUID;
ALTER TABLE audit_events ADD COLUMN IF NOT EXISTS correlation_id UUID;
EOF

python - <<'PY'
from pathlib import Path
p = Path('scripts/migrate/run_all.sh')
text = p.read_text()
if 'sql/006_hardening.sql' not in text:
    text = text.replace('sql/005_positions_audit.sql', 'sql/005_positions_audit.sql \\\n         sql/006_hardening.sql')
    p.write_text(text)
PY

cat > apps/order-service/app/config.py <<'EOF'
from shared_config.settings import Settings


class OrderServiceSettings(Settings):
    risk_service_url: str = "http://risk-service:8000"
    execution_service_url: str = "http://execution-service:8000"
    position_service_url: str = "http://position-service:8000"
    audit_service_url: str = "http://audit-service:8000"
    internal_service_token: str = "internal-dev-token"


settings = OrderServiceSettings(app_name="order-service", port=8000)
EOF

cat > apps/order-service/app/db/models.py <<'EOF'
from sqlalchemy import String, Numeric, DateTime, JSON, func
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
EOF

cat > apps/order-service/app/domain/history.py <<'EOF'
import uuid
from app.db.models import OrderStateHistoryModel


def record_order_transition(
    db,
    order_intent_id: str,
    from_state: str | None,
    to_state: str,
    transition_reason: str | None,
    actor_type: str,
    actor_id: str | None = None,
    metadata_json: dict | None = None,
):
    row = OrderStateHistoryModel(
        id=str(uuid.uuid4()),
        order_intent_id=order_intent_id,
        from_state=from_state,
        to_state=to_state,
        transition_reason=transition_reason,
        actor_type=actor_type,
        actor_id=actor_id,
        metadata_json=metadata_json,
    )
    db.add(row)
EOF

cat > apps/order-service/app/domain/idempotency.py <<'EOF'
import uuid
from app.db.models import IdempotencyKeyModel


def get_idempotent_response(db, scope: str, key: str):
    row = db.query(IdempotencyKeyModel).filter(
        IdempotencyKeyModel.scope == scope,
        IdempotencyKeyModel.idempotency_key == key,
    ).first()
    return None if not row else row.response_json


def store_idempotent_response(db, scope: str, key: str, response_json: dict):
    row = IdempotencyKeyModel(
        id=str(uuid.uuid4()),
        scope=scope,
        idempotency_key=key,
        response_json=response_json,
    )
    db.add(row)
EOF

cat > apps/order-service/app/domain/state_machine.py <<'EOF'
from app.domain.history import record_order_transition
from shared_domain.order_state import can_transition


def transition_order(db, row, next_state: str, reason: str | None = None):
    current_state = row.intent_status
    if not can_transition(current_state, next_state):
        raise ValueError(f"Illegal order state transition: {current_state} -> {next_state}")
    row.intent_status = next_state
    record_order_transition(
        db=db,
        order_intent_id=row.id,
        from_state=current_state,
        to_state=next_state,
        transition_reason=reason,
        actor_type="system",
        metadata_json=None,
    )
    return row
EOF

cat > apps/order-service/app/integrations/clients.py <<'EOF'
import httpx
from app.config import settings


def internal_headers(correlation_id: str) -> dict:
    return {
        "X-Service-Name": "order-service",
        "X-Service-Token": settings.internal_service_token,
        "X-Correlation-ID": correlation_id,
    }


async def call_risk_service(payload: dict, correlation_id: str) -> dict:
    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.post(
            f"{settings.risk_service_url}/api/risk/evaluate",
            json=payload,
            headers=internal_headers(correlation_id),
        )
        response.raise_for_status()
        return response.json()


async def call_execution_service(payload: dict, correlation_id: str) -> dict:
    async with httpx.AsyncClient(timeout=15.0) as client:
        response = await client.post(
            f"{settings.execution_service_url}/api/execution/simulate",
            json=payload,
            headers=internal_headers(correlation_id),
        )
        response.raise_for_status()
        return response.json()


async def call_position_service(payload: dict, correlation_id: str) -> dict:
    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.post(
            f"{settings.position_service_url}/api/positions/apply-fill",
            json=payload,
            headers=internal_headers(correlation_id),
        )
        response.raise_for_status()
        return response.json()


async def call_audit_service(payload: dict, correlation_id: str) -> dict:
    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.post(
            f"{settings.audit_service_url}/api/audit",
            json=payload,
            headers=internal_headers(correlation_id),
        )
        response.raise_for_status()
        return response.json()
EOF

cat > apps/order-service/app/api/schemas.py <<'EOF'
from decimal import Decimal
from pydantic import BaseModel


class OrderIntentCreate(BaseModel):
    strategy_deployment_id: str | None = None
    account_id: str | None = None
    instrument_id: str
    signal_id: str | None = None
    side: str
    order_type: str
    quantity: Decimal
    limit_price: Decimal | None = None
    stop_price: Decimal | None = None
    tif: str
    venue_id: str
    execution_price: Decimal


class OrderSubmitResponse(BaseModel):
    order_id: str
    final_status: str
    risk_decision: str
    execution: dict | None = None
    position: dict | None = None
    correlation_id: str
    error: dict | None = None
EOF

cat > apps/order-service/app/api/routes/orders.py <<'EOF'
import uuid
from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.db.models import OrderIntentModel
from app.api.schemas import OrderIntentCreate, OrderSubmitResponse
from app.domain.idempotency import get_idempotent_response, store_idempotent_response
from app.domain.state_machine import transition_order
from app.integrations.clients import (
    call_risk_service,
    call_execution_service,
    call_position_service,
    call_audit_service,
)
from app.config import settings
from shared_auth.dependencies import require_user_context
from shared_observability.correlation import get_or_create_correlation_id

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


@router.get("/{order_id}")
def get_order_detail(
    order_id: str,
    db: Session = Depends(get_db),
    user=Depends(require_user_context(settings.jwt_secret, settings.jwt_algorithm)),
):
    order = db.query(OrderIntentModel).filter(OrderIntentModel.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    history = db.execute(
        "SELECT id, from_state, to_state, transition_reason, created_at FROM order_state_history WHERE order_intent_id = :oid ORDER BY created_at ASC",
        {"oid": order_id},
    ).mappings().all()
    return {
        "order": {
            "id": order.id,
            "instrument_id": order.instrument_id,
            "side": order.side,
            "order_type": order.order_type,
            "quantity": str(order.quantity),
            "intent_status": order.intent_status,
            "correlation_id": order.correlation_id,
        },
        "state_history": [dict(x) for x in history],
    }


@router.post("/submit", response_model=OrderSubmitResponse)
async def submit_order(
    payload: OrderIntentCreate,
    db: Session = Depends(get_db),
    user=Depends(require_user_context(settings.jwt_secret, settings.jwt_algorithm)),
    correlation_id: str = Depends(get_or_create_correlation_id),
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
):
    if idempotency_key:
        cached = get_idempotent_response(db, "order_submit", idempotency_key)
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
    db.commit()
    db.refresh(row)

    await call_audit_service(
        {
            "actor_type": "user",
            "actor_id": user["sub"],
            "event_type": "order_intent.created",
            "resource_type": "order_intent",
            "resource_id": row.id,
            "after_json": {
                "instrument_id": row.instrument_id,
                "side": row.side,
                "quantity": str(row.quantity),
                "status": row.intent_status,
                "correlation_id": correlation_id,
            },
        },
        correlation_id,
    )

    try:
        transition_order(db, row, "risk_pending", reason="submitted_for_risk")
        db.commit()
        db.refresh(row)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))

    risk_result = await call_risk_service(
        {
            "order_intent_id": row.id,
            "quantity": str(row.quantity),
            "side": row.side,
            "instrument_id": row.instrument_id,
            "account_id": row.account_id,
        },
        correlation_id,
    )

    if risk_result["decision"] == "reject":
        transition_order(db, row, "risk_failed", reason="risk_reject")
        db.commit()
        db.refresh(row)

        response = {
            "order_id": row.id,
            "final_status": row.intent_status,
            "risk_decision": "reject",
            "execution": None,
            "position": None,
            "correlation_id": correlation_id,
            "error": {
                "code": "RISK_REJECTED",
                "message": "Order rejected by risk policy",
                "correlation_id": correlation_id,
            },
        }
        if idempotency_key:
            store_idempotent_response(db, "order_submit", idempotency_key, response)
            db.commit()
        return response

    try:
        transition_order(db, row, "risk_passed", reason="risk_pass")
        db.commit()
        db.refresh(row)
        transition_order(db, row, "submitted", reason="sent_for_execution")
        db.commit()
        db.refresh(row)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))

    try:
        execution_result = await call_execution_service(
            {
                "order_intent_id": row.id,
                "venue_id": payload.venue_id,
                "instrument_id": row.instrument_id,
                "quantity": str(row.quantity),
                "price": str(payload.execution_price),
                "fee_amount": "0.0",
                "fee_currency": "USD",
            },
            correlation_id,
        )
    except Exception:
        response = {
            "order_id": row.id,
            "final_status": "execution_failed",
            "risk_decision": "pass",
            "execution": None,
            "position": None,
            "correlation_id": correlation_id,
            "error": {
                "code": "EXECUTION_FAILED",
                "message": "Execution service unavailable",
                "correlation_id": correlation_id,
            },
        }
        if idempotency_key:
            store_idempotent_response(db, "order_submit", idempotency_key, response)
            db.commit()
        return response

    row.intent_status = "filled"
    db.commit()
    db.refresh(row)

    position_result = await call_position_service(
        {
            "account_id": row.account_id,
            "instrument_id": row.instrument_id,
            "side": row.side,
            "fill_quantity": str(row.quantity),
            "fill_price": str(payload.execution_price),
        },
        correlation_id,
    )

    await call_audit_service(
        {
            "actor_type": "system",
            "actor_id": None,
            "event_type": "order_intent.filled",
            "resource_type": "order_intent",
            "resource_id": row.id,
            "after_json": {
                "status": row.intent_status,
                "execution_result": execution_result,
                "position_result": position_result,
                "correlation_id": correlation_id,
            },
        },
        correlation_id,
    )

    response = {
        "order_id": row.id,
        "final_status": row.intent_status,
        "risk_decision": "pass",
        "execution": execution_result,
        "position": position_result,
        "correlation_id": correlation_id,
        "error": None,
    }
    if idempotency_key:
        store_idempotent_response(db, "order_submit", idempotency_key, response)
        db.commit()
    return response
EOF

cat > apps/order-service/app/main.py <<'EOF'
from fastapi import FastAPI
from app.api.routes.orders import router as orders_router

app = FastAPI(title="order-service", version="0.2.0")
app.include_router(orders_router, prefix="/api/orders", tags=["orders"])

@app.get("/health/live")
def health_live():
    return {"status": "ok", "service": "order-service"}

@app.get("/health/ready")
def health_ready():
    return {"status": "ready", "service": "order-service"}
EOF

cat > apps/risk-service/app/config.py <<'EOF'
from shared_config.settings import Settings


class RiskServiceSettings(Settings):
    internal_service_token: str = "internal-dev-token"


settings = RiskServiceSettings(app_name="risk-service", port=8000)
EOF

cat > apps/risk-service/app/db/models.py <<'EOF'
from sqlalchemy import String, DateTime, JSON, func
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
EOF

cat > apps/risk-service/app/api/routes/risk.py <<'EOF'
import uuid
from decimal import Decimal
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.db.models import RiskEvaluationModel
from app.config import settings
from shared_auth.dependencies import validate_internal_service
from shared_observability.correlation import get_or_create_correlation_id

router = APIRouter()


class RiskEvaluationRequest(BaseModel):
    order_intent_id: str
    quantity: Decimal
    side: str
    instrument_id: str
    account_id: str | None = None


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


@router.post("/evaluate")
def evaluate_order(
    payload: RiskEvaluationRequest,
    db: Session = Depends(get_db),
    internal=Depends(validate_internal_service(settings.internal_service_token)),
    correlation_id: str = Depends(get_or_create_correlation_id),
):
    results = [evaluate_max_position_size(payload.quantity, Decimal("100000"))]
    failed = [r for r in results if not r["passed"]]
    decision = "reject" if failed else "pass"
    next_state = "risk_failed" if failed else "risk_passed"

    row = RiskEvaluationModel(
        id=str(uuid.uuid4()),
        order_intent_id=payload.order_intent_id,
        decision=decision,
        next_state=next_state,
        rule_results={"rule_results": results},
        evaluated_by_service="risk-service",
        correlation_id=correlation_id,
    )
    db.add(row)
    db.commit()

    return {
        "order_intent_id": payload.order_intent_id,
        "decision": decision,
        "rule_results": results,
        "next_state": next_state,
        "correlation_id": correlation_id,
    }
EOF

cat > apps/risk-service/app/main.py <<'EOF'
from fastapi import FastAPI
from app.api.routes.risk import router as risk_router

app = FastAPI(title="risk-service", version="0.2.0")
app.include_router(risk_router, prefix="/api/risk", tags=["risk"])

@app.get("/health/live")
def health_live():
    return {"status": "ok", "service": "risk-service"}

@app.get("/health/ready")
def health_ready():
    return {"status": "ready", "service": "risk-service"}
EOF

cat > apps/position-service/app/main.py <<'EOF'
from fastapi import FastAPI
from app.api.routes.positions import router as positions_router

app = FastAPI(title="position-service", version="0.2.0")
app.include_router(positions_router, prefix="/api/positions", tags=["positions"])

@app.get("/health/live")
def health_live():
    return {"status": "ok", "service": "position-service"}

@app.get("/health/ready")
def health_ready():
    return {"status": "ready", "service": "position-service"}
EOF

python - <<'PY'
from pathlib import Path
for svc in ['identity-service','market-registry-service','instrument-master-service','strategy-service','audit-service','position-service','risk-service','execution-service','order-service','broker-adapter-simulator']:
    p = Path(f'apps/{svc}/Dockerfile')
    txt = p.read_text()
    if 'shared-observability' not in txt:
        txt = txt.replace('COPY packages /workspace/packages\n', 'COPY packages /workspace/packages\n')
        if 'pyjwt' not in txt:
            txt = txt.replace('httpx pyjwt', 'httpx pyjwt')
        p.write_text(txt)
PY

cat > apps/web-admin/src/views/OrderDetailHint.vue <<'EOF'
<template>
  <div>
    <h2>Order hardening now available</h2>
    <p>Use the API endpoint <code>/api/orders/:id</code> to view order state history.</p>
  </div>
</template>
EOF

echo "Hardening bootstrap applied."
echo "Next: bash scripts/migrate/run_all.sh && restart services."
