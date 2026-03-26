#!/usr/bin/env bash
set -euo pipefail

# Risk controls, execution quality, and reconciliation bootstrap writer.
# Run inside the existing trading-platform repo root.

ROOT="$(pwd)"
if [ ! -f "$ROOT/docker-compose.yml" ]; then
  echo "Run this inside the trading-platform repo root."
  exit 1
fi

mkdir -p \
  sql \
  packages/shared-risk/shared_risk \
  packages/shared-execution/shared_execution \
  apps/risk-service/app/{domain,api/routes,db} \
  apps/execution-service/app/{domain,api/routes,db} \
  apps/reconciliation-service/app/{api/routes,db,domain}

cat > sql/010_risk_controls.sql <<'EOF'
CREATE TABLE IF NOT EXISTS risk_breaches (
    id UUID PRIMARY KEY,
    risk_policy_id UUID NOT NULL REFERENCES risk_policies(id),
    scope_type VARCHAR(50) NOT NULL,
    scope_id UUID NOT NULL,
    breach_type VARCHAR(100) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    measured_value NUMERIC(24,10),
    threshold_value NUMERIC(24,10),
    details_json JSONB,
    action_taken VARCHAR(100),
    status VARCHAR(50) NOT NULL DEFAULT 'open',
    correlation_id UUID,
    detected_at TIMESTAMPTZ NOT NULL,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS kill_switches (
    id UUID PRIMARY KEY,
    scope_type VARCHAR(50) NOT NULL,
    scope_id UUID,
    switch_action VARCHAR(100) NOT NULL,
    reason TEXT,
    triggered_by_actor_type VARCHAR(50) NOT NULL,
    triggered_by_actor_id UUID,
    status VARCHAR(50) NOT NULL DEFAULT 'active',
    correlation_id UUID,
    triggered_at TIMESTAMPTZ NOT NULL,
    released_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS risk_exposure_snapshots (
    id UUID PRIMARY KEY,
    scope_type VARCHAR(50) NOT NULL,
    scope_id UUID NOT NULL,
    exposure_type VARCHAR(100) NOT NULL,
    instrument_id UUID,
    currency_code VARCHAR(20),
    gross_exposure NUMERIC(24,10),
    net_exposure NUMERIC(24,10),
    notional_value NUMERIC(24,10),
    leverage_value NUMERIC(24,10),
    margin_used NUMERIC(24,10),
    unrealized_pnl NUMERIC(24,10),
    realized_pnl NUMERIC(24,10),
    snapshot_time TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS drawdown_trackers (
    id UUID PRIMARY KEY,
    scope_type VARCHAR(50) NOT NULL,
    scope_id UUID NOT NULL,
    equity_high_watermark NUMERIC(24,10) NOT NULL,
    current_equity NUMERIC(24,10) NOT NULL,
    drawdown_amount NUMERIC(24,10) NOT NULL,
    drawdown_percent NUMERIC(12,6) NOT NULL,
    snapshot_time TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
EOF

cat > sql/011_execution_reconciliation.sql <<'EOF'
CREATE TABLE IF NOT EXISTS execution_policies (
    id UUID PRIMARY KEY,
    policy_code VARCHAR(100) UNIQUE NOT NULL,
    scope_type VARCHAR(50) NOT NULL,
    scope_id UUID,
    preferred_venue_id UUID,
    preferred_account_id UUID,
    allowed_order_types JSONB,
    max_slippage_bps NUMERIC(12,6),
    max_retry_count INT NOT NULL DEFAULT 0,
    cancel_timeout_seconds INT,
    replace_timeout_seconds INT,
    ambiguous_handling_mode VARCHAR(50) NOT NULL DEFAULT 'manual_review',
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS broker_order_state_history (
    id UUID PRIMARY KEY,
    broker_order_id UUID NOT NULL REFERENCES broker_orders(id),
    from_state VARCHAR(50),
    to_state VARCHAR(50) NOT NULL,
    transition_reason VARCHAR(255),
    metadata_json JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS execution_quality_metrics (
    id UUID PRIMARY KEY,
    broker_order_id UUID NOT NULL REFERENCES broker_orders(id),
    order_intent_id UUID NOT NULL REFERENCES order_intents(id),
    strategy_deployment_id UUID,
    instrument_id UUID NOT NULL REFERENCES instruments(id),
    venue_id UUID NOT NULL REFERENCES venues(id),
    intended_price NUMERIC(24,10),
    submitted_price NUMERIC(24,10),
    avg_fill_price NUMERIC(24,10),
    slippage_amount NUMERIC(24,10),
    slippage_bps NUMERIC(12,6),
    total_fee_amount NUMERIC(24,10),
    fee_currency VARCHAR(20),
    ack_latency_ms INT,
    full_fill_latency_ms INT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS reconciliation_runs (
    id UUID PRIMARY KEY,
    run_type VARCHAR(50) NOT NULL,
    account_id UUID,
    venue_id UUID,
    status VARCHAR(50) NOT NULL DEFAULT 'running',
    summary_json JSONB,
    started_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS reconciliation_issues (
    id UUID PRIMARY KEY,
    reconciliation_run_id UUID REFERENCES reconciliation_runs(id),
    issue_type VARCHAR(100) NOT NULL,
    account_id UUID,
    venue_id UUID,
    severity VARCHAR(20) NOT NULL,
    internal_ref VARCHAR(255),
    external_ref VARCHAR(255),
    difference_json JSONB,
    recommended_action VARCHAR(100),
    status VARCHAR(50) NOT NULL DEFAULT 'open',
    correlation_id UUID,
    detected_at TIMESTAMPTZ NOT NULL,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
EOF

python - <<'PY'
from pathlib import Path
p = Path('scripts/migrate/run_all.sh')
text = p.read_text()
if 'sql/010_risk_controls.sql' not in text:
    text = text.replace('sql/009_market_data_features_research.sql', 'sql/009_market_data_features_research.sql \\\n         sql/010_risk_controls.sql \\\n         sql/011_execution_reconciliation.sql')
    p.write_text(text)
PY

cat > packages/shared-risk/shared_risk/__init__.py <<'EOF'
EOF

cat > packages/shared-risk/shared_risk/exposure.py <<'EOF'
def gross_exposure(notional_values: list[float]) -> float:
    return sum(abs(x) for x in notional_values)


def net_exposure(signed_notional_values: list[float]) -> float:
    return sum(signed_notional_values)


def drawdown(current_equity: float, high_watermark: float) -> tuple[float, float]:
    amount = high_watermark - current_equity
    pct = 0.0 if high_watermark == 0 else amount / high_watermark
    return amount, pct
EOF

cat > packages/shared-risk/shared_risk/policies.py <<'EOF'
def max_position_size_check(quantity: float, threshold: float) -> dict:
    if quantity > threshold:
        return {
            'passed': False,
            'rule_type': 'max_position_size',
            'message': 'Order exceeds configured max position size',
            'severity': 'high',
            'threshold': threshold,
            'measured': quantity,
        }
    return {
        'passed': True,
        'rule_type': 'max_position_size',
        'message': 'Passed',
        'severity': 'info',
        'threshold': threshold,
        'measured': quantity,
    }
EOF

cat > packages/shared-execution/shared_execution/__init__.py <<'EOF'
EOF

cat > packages/shared-execution/shared_execution/quality.py <<'EOF'
def slippage_amount(intended_price: float, fill_price: float, side: str) -> float:
    if side == 'buy':
        return fill_price - intended_price
    return intended_price - fill_price


def slippage_bps(intended_price: float, fill_price: float, side: str) -> float:
    if intended_price == 0:
        return 0.0
    amt = slippage_amount(intended_price, fill_price, side)
    return (amt / intended_price) * 10000.0
EOF

cat > apps/risk-service/app/db/models.py <<'EOF'
from sqlalchemy import String, DateTime, JSON, Integer, Numeric, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base


class RiskEvaluationModel(Base):
    __tablename__ = 'risk_evaluations'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    order_intent_id: Mapped[str] = mapped_column(String, nullable=False)
    decision: Mapped[str] = mapped_column(String(20), nullable=False)
    next_state: Mapped[str] = mapped_column(String(50), nullable=False)
    rule_results: Mapped[dict] = mapped_column(JSON, nullable=False)
    evaluated_by_service: Mapped[str] = mapped_column(String(100), nullable=False)
    correlation_id: Mapped[str] = mapped_column(String, nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())


class RiskBreachModel(Base):
    __tablename__ = 'risk_breaches'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    risk_policy_id: Mapped[str] = mapped_column(String, nullable=False)
    scope_type: Mapped[str] = mapped_column(String(50), nullable=False)
    scope_id: Mapped[str] = mapped_column(String, nullable=False)
    breach_type: Mapped[str] = mapped_column(String(100), nullable=False)
    severity: Mapped[str] = mapped_column(String(20), nullable=False)
    measured_value: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    threshold_value: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    details_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    action_taken: Mapped[str] = mapped_column(String(100), nullable=True)
    status: Mapped[str] = mapped_column(String(50), nullable=False, default='open')
    correlation_id: Mapped[str] = mapped_column(String, nullable=True)
    detected_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    resolved_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())


class KillSwitchModel(Base):
    __tablename__ = 'kill_switches'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    scope_type: Mapped[str] = mapped_column(String(50), nullable=False)
    scope_id: Mapped[str] = mapped_column(String, nullable=True)
    switch_action: Mapped[str] = mapped_column(String(100), nullable=False)
    reason: Mapped[str] = mapped_column(String, nullable=True)
    triggered_by_actor_type: Mapped[str] = mapped_column(String(50), nullable=False)
    triggered_by_actor_id: Mapped[str] = mapped_column(String, nullable=True)
    status: Mapped[str] = mapped_column(String(50), nullable=False, default='active')
    correlation_id: Mapped[str] = mapped_column(String, nullable=True)
    triggered_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    released_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())


class RiskExposureSnapshotModel(Base):
    __tablename__ = 'risk_exposure_snapshots'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    scope_type: Mapped[str] = mapped_column(String(50), nullable=False)
    scope_id: Mapped[str] = mapped_column(String, nullable=False)
    exposure_type: Mapped[str] = mapped_column(String(100), nullable=False)
    instrument_id: Mapped[str] = mapped_column(String, nullable=True)
    currency_code: Mapped[str] = mapped_column(String(20), nullable=True)
    gross_exposure: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    net_exposure: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    notional_value: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    leverage_value: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    margin_used: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    unrealized_pnl: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    realized_pnl: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    snapshot_time: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())


class DrawdownTrackerModel(Base):
    __tablename__ = 'drawdown_trackers'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    scope_type: Mapped[str] = mapped_column(String(50), nullable=False)
    scope_id: Mapped[str] = mapped_column(String, nullable=False)
    equity_high_watermark: Mapped[float] = mapped_column(Numeric(24,10), nullable=False)
    current_equity: Mapped[float] = mapped_column(Numeric(24,10), nullable=False)
    drawdown_amount: Mapped[float] = mapped_column(Numeric(24,10), nullable=False)
    drawdown_percent: Mapped[float] = mapped_column(Numeric(12,6), nullable=False)
    snapshot_time: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
EOF

cat > apps/risk-service/app/domain/controls.py <<'EOF'
import uuid
from datetime import datetime, timezone
from shared_risk.policies import max_position_size_check
from shared_risk.exposure import drawdown
from app.db.models import RiskBreachModel, KillSwitchModel, DrawdownTrackerModel


def evaluate_pretrade(quantity: float, threshold: float = 100000.0) -> dict:
    return max_position_size_check(quantity, threshold)


def create_breach(db, *, risk_policy_id: str, scope_type: str, scope_id: str, breach_type: str, severity: str, measured_value: float, threshold_value: float, correlation_id: str | None, action_taken: str | None = None, details_json: dict | None = None):
    row = RiskBreachModel(
        id=str(uuid.uuid4()),
        risk_policy_id=risk_policy_id,
        scope_type=scope_type,
        scope_id=scope_id,
        breach_type=breach_type,
        severity=severity,
        measured_value=measured_value,
        threshold_value=threshold_value,
        details_json=details_json or {},
        action_taken=action_taken,
        status='open',
        correlation_id=correlation_id,
        detected_at=datetime.now(timezone.utc),
    )
    db.add(row)
    return row


def activate_kill_switch(db, *, scope_type: str, scope_id: str | None, action: str, reason: str, actor_type: str, actor_id: str | None, correlation_id: str | None):
    row = KillSwitchModel(
        id=str(uuid.uuid4()),
        scope_type=scope_type,
        scope_id=scope_id,
        switch_action=action,
        reason=reason,
        triggered_by_actor_type=actor_type,
        triggered_by_actor_id=actor_id,
        status='active',
        correlation_id=correlation_id,
        triggered_at=datetime.now(timezone.utc),
    )
    db.add(row)
    return row


def track_drawdown(db, *, scope_type: str, scope_id: str, current_equity: float, high_watermark: float):
    amount, pct = drawdown(current_equity, high_watermark)
    row = DrawdownTrackerModel(
        id=str(uuid.uuid4()),
        scope_type=scope_type,
        scope_id=scope_id,
        equity_high_watermark=high_watermark,
        current_equity=current_equity,
        drawdown_amount=amount,
        drawdown_percent=pct,
        snapshot_time=datetime.now(timezone.utc),
    )
    db.add(row)
    return row
EOF

cat > apps/risk-service/app/api/routes/controls.py <<'EOF'
import uuid
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import RiskBreachModel, KillSwitchModel, RiskExposureSnapshotModel, DrawdownTrackerModel
from app.domain.controls import create_breach, activate_kill_switch, track_drawdown

router = APIRouter()

@router.get('/breaches')
def list_breaches(db: Session = Depends(get_db)):
    rows = db.query(RiskBreachModel).order_by(RiskBreachModel.created_at.desc()).limit(200).all()
    return [{'id': x.id, 'breach_type': x.breach_type, 'severity': x.severity, 'status': x.status, 'detected_at': x.detected_at} for x in rows]

@router.post('/kill-switches')
def create_kill_switch(payload: dict, db: Session = Depends(get_db)):
    row = activate_kill_switch(
        db,
        scope_type=payload['scope_type'],
        scope_id=payload.get('scope_id'),
        action=payload.get('switch_action', 'reject_new_orders'),
        reason=payload.get('reason', 'manual'),
        actor_type=payload.get('triggered_by_actor_type', 'user'),
        actor_id=payload.get('triggered_by_actor_id'),
        correlation_id=payload.get('correlation_id'),
    )
    db.commit()
    return {'id': row.id, 'status': row.status}

@router.get('/kill-switches')
def list_kill_switches(db: Session = Depends(get_db)):
    rows = db.query(KillSwitchModel).order_by(KillSwitchModel.created_at.desc()).limit(200).all()
    return [{'id': x.id, 'scope_type': x.scope_type, 'scope_id': x.scope_id, 'switch_action': x.switch_action, 'status': x.status} for x in rows]

@router.post('/drawdown-trackers')
def create_drawdown_tracker(payload: dict, db: Session = Depends(get_db)):
    row = track_drawdown(db, scope_type=payload['scope_type'], scope_id=payload['scope_id'], current_equity=float(payload['current_equity']), high_watermark=float(payload['high_watermark']))
    db.commit()
    return {'id': row.id, 'drawdown_amount': str(row.drawdown_amount), 'drawdown_percent': str(row.drawdown_percent)}

@router.get('/drawdown-trackers')
def list_drawdown_trackers(db: Session = Depends(get_db)):
    rows = db.query(DrawdownTrackerModel).order_by(DrawdownTrackerModel.created_at.desc()).limit(200).all()
    return [{'id': x.id, 'scope_type': x.scope_type, 'scope_id': x.scope_id, 'drawdown_amount': str(x.drawdown_amount), 'drawdown_percent': str(x.drawdown_percent)} for x in rows]
EOF

cat > apps/risk-service/app/api/routes/risk.py <<'EOF'
import uuid
from decimal import Decimal
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.db.models import RiskEvaluationModel, KillSwitchModel
from app.config import settings
from shared_auth.dependencies import validate_internal_service
from shared_observability.correlation import get_or_create_correlation_id
from app.domain.controls import evaluate_pretrade, create_breach

router = APIRouter()

class RiskEvaluationRequest(BaseModel):
    order_intent_id: str
    quantity: Decimal
    side: str
    instrument_id: str
    account_id: str | None = None

@router.post('/evaluate')
def evaluate_order(
    payload: RiskEvaluationRequest,
    db: Session = Depends(get_db),
    internal=Depends(validate_internal_service(settings.internal_service_token)),
    correlation_id: str = Depends(get_or_create_correlation_id),
):
    active_switch = db.query(KillSwitchModel).filter(KillSwitchModel.status == 'active').first()
    if active_switch:
        results = [{
            'passed': False,
            'rule_type': 'kill_switch',
            'message': 'Trading blocked by active kill switch',
            'severity': 'critical',
        }]
        decision = 'reject'
        next_state = 'risk_failed'
    else:
        control = evaluate_pretrade(float(payload.quantity), 100000.0)
        results = [control]
        failed = [r for r in results if not r['passed']]
        decision = 'reject' if failed else 'pass'
        next_state = 'risk_failed' if failed else 'risk_passed'
        if failed:
            create_breach(
                db,
                risk_policy_id=str(uuid.uuid4()),
                scope_type='order',
                scope_id=payload.order_intent_id,
                breach_type=failed[0]['rule_type'],
                severity=failed[0]['severity'],
                measured_value=float(payload.quantity),
                threshold_value=float(failed[0].get('threshold', 0)),
                correlation_id=correlation_id,
                action_taken='reject_new_orders',
                details_json={'order_intent_id': payload.order_intent_id},
            )

    row = RiskEvaluationModel(
        id=str(uuid.uuid4()),
        order_intent_id=payload.order_intent_id,
        decision=decision,
        next_state=next_state,
        rule_results={'rule_results': results},
        evaluated_by_service='risk-service',
        correlation_id=correlation_id,
    )
    db.add(row)
    db.commit()
    return {
        'order_intent_id': payload.order_intent_id,
        'decision': decision,
        'rule_results': results,
        'next_state': next_state,
        'correlation_id': correlation_id,
    }
EOF

cat > apps/risk-service/app/main.py <<'EOF'
from fastapi import FastAPI
from app.api.routes.risk import router as risk_router
from app.api.routes.controls import router as controls_router

app = FastAPI(title='risk-service', version='0.3.0')
app.include_router(risk_router, prefix='/api/risk', tags=['risk'])
app.include_router(controls_router, prefix='/api/risk', tags=['risk-controls'])

@app.get('/health/live')
def health_live():
    return {'status': 'ok', 'service': 'risk-service'}

@app.get('/health/ready')
def health_ready():
    return {'status': 'ready', 'service': 'risk-service'}
EOF

cat > apps/execution-service/app/db/models.py <<'EOF'
from sqlalchemy import String, Numeric, DateTime, JSON, Integer, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base

class BrokerOrderModel(Base):
    __tablename__ = 'broker_orders'
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
    __tablename__ = 'fills'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    broker_order_id: Mapped[str] = mapped_column(String, nullable=False)
    instrument_id: Mapped[str] = mapped_column(String, nullable=False)
    fill_price: Mapped[float] = mapped_column(Numeric(24,10), nullable=False)
    fill_quantity: Mapped[float] = mapped_column(Numeric(24,10), nullable=False)
    fee_amount: Mapped[float] = mapped_column(Numeric(24,10), nullable=False, default=0)
    fee_currency: Mapped[str] = mapped_column(String(20), nullable=True)
    correlation_id: Mapped[str] = mapped_column(String, nullable=True)
    fill_time: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
    raw_payload: Mapped[dict] = mapped_column(JSON, nullable=True)

class BrokerOrderStateHistoryModel(Base):
    __tablename__ = 'broker_order_state_history'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    broker_order_id: Mapped[str] = mapped_column(String, nullable=False)
    from_state: Mapped[str] = mapped_column(String(50), nullable=True)
    to_state: Mapped[str] = mapped_column(String(50), nullable=False)
    transition_reason: Mapped[str] = mapped_column(String(255), nullable=True)
    metadata_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())

class ExecutionQualityMetricModel(Base):
    __tablename__ = 'execution_quality_metrics'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    broker_order_id: Mapped[str] = mapped_column(String, nullable=False)
    order_intent_id: Mapped[str] = mapped_column(String, nullable=False)
    strategy_deployment_id: Mapped[str] = mapped_column(String, nullable=True)
    instrument_id: Mapped[str] = mapped_column(String, nullable=False)
    venue_id: Mapped[str] = mapped_column(String, nullable=False)
    intended_price: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    submitted_price: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    avg_fill_price: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    slippage_amount: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    slippage_bps: Mapped[float] = mapped_column(Numeric(12,6), nullable=True)
    total_fee_amount: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    fee_currency: Mapped[str] = mapped_column(String(20), nullable=True)
    ack_latency_ms: Mapped[int] = mapped_column(Integer, nullable=True)
    full_fill_latency_ms: Mapped[int] = mapped_column(Integer, nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
EOF

cat > apps/execution-service/app/domain/quality.py <<'EOF'
import uuid
from shared_execution.quality import slippage_amount, slippage_bps
from app.db.models import ExecutionQualityMetricModel, BrokerOrderStateHistoryModel


def record_state_history(db, *, broker_order_id: str, from_state: str | None, to_state: str, reason: str | None, metadata_json: dict | None = None):
    row = BrokerOrderStateHistoryModel(
        id=str(uuid.uuid4()),
        broker_order_id=broker_order_id,
        from_state=from_state,
        to_state=to_state,
        transition_reason=reason,
        metadata_json=metadata_json or {},
    )
    db.add(row)
    return row


def record_execution_quality(db, *, broker_order_id: str, order_intent_id: str, instrument_id: str, venue_id: str, side: str, intended_price: float, submitted_price: float, fill_price: float, fee_amount: float = 0.0, fee_currency: str = 'USD'):
    row = ExecutionQualityMetricModel(
        id=str(uuid.uuid4()),
        broker_order_id=broker_order_id,
        order_intent_id=order_intent_id,
        strategy_deployment_id=None,
        instrument_id=instrument_id,
        venue_id=venue_id,
        intended_price=intended_price,
        submitted_price=submitted_price,
        avg_fill_price=fill_price,
        slippage_amount=slippage_amount(intended_price, fill_price, side),
        slippage_bps=slippage_bps(intended_price, fill_price, side),
        total_fee_amount=fee_amount,
        fee_currency=fee_currency,
        ack_latency_ms=0,
        full_fill_latency_ms=0,
    )
    db.add(row)
    return row
EOF

cat > apps/execution-service/app/api/routes/execution.py <<'EOF'
import uuid
from decimal import Decimal
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import BrokerOrderModel, FillModel, ExecutionQualityMetricModel
from app.domain.quality import record_execution_quality, record_state_history

router = APIRouter()

class SimulateExecutionRequest(BaseModel):
    order_intent_id: str
    venue_id: str
    instrument_id: str
    quantity: Decimal
    price: Decimal
    fee_amount: Decimal = Decimal('0.0')
    fee_currency: str = 'USD'
    side: str = 'buy'

@router.post('/simulate')
def simulate_execution(payload: SimulateExecutionRequest, db: Session = Depends(get_db)):
    broker_order = BrokerOrderModel(
        id=str(uuid.uuid4()),
        order_intent_id=payload.order_intent_id,
        venue_id=payload.venue_id,
        external_order_id=f'sim-{uuid.uuid4()}',
        broker_status='filled',
        raw_request=payload.model_dump(mode='json'),
        raw_response={'status': 'filled'},
    )
    db.add(broker_order)
    db.flush()
    record_state_history(db, broker_order_id=broker_order.id, from_state=None, to_state='submitted', reason='simulated_submit')
    record_state_history(db, broker_order_id=broker_order.id, from_state='submitted', to_state='filled', reason='simulated_fill')
    fill = FillModel(
        id=str(uuid.uuid4()),
        broker_order_id=broker_order.id,
        instrument_id=payload.instrument_id,
        fill_price=payload.price,
        fill_quantity=payload.quantity,
        fee_amount=payload.fee_amount,
        fee_currency=payload.fee_currency,
        raw_payload={'simulation': True},
    )
    db.add(fill)
    record_execution_quality(
        db,
        broker_order_id=broker_order.id,
        order_intent_id=payload.order_intent_id,
        instrument_id=payload.instrument_id,
        venue_id=payload.venue_id,
        side=payload.side,
        intended_price=float(payload.price),
        submitted_price=float(payload.price),
        fill_price=float(payload.price),
        fee_amount=float(payload.fee_amount),
        fee_currency=payload.fee_currency,
    )
    db.commit()
    return {
        'broker_order_id': broker_order.id,
        'external_order_id': broker_order.external_order_id,
        'fill_id': fill.id,
        'status': 'filled',
        'fill': {
            'instrument_id': payload.instrument_id,
            'quantity': str(payload.quantity),
            'price': str(payload.price),
            'fee_amount': str(payload.fee_amount),
            'fee_currency': payload.fee_currency,
        },
    }

@router.get('/quality-metrics')
def list_quality_metrics(db: Session = Depends(get_db)):
    rows = db.query(ExecutionQualityMetricModel).order_by(ExecutionQualityMetricModel.created_at.desc()).limit(200).all()
    return [{'id': x.id, 'broker_order_id': x.broker_order_id, 'slippage_bps': str(x.slippage_bps), 'total_fee_amount': str(x.total_fee_amount)} for x in rows]
EOF

cat > apps/execution-service/app/main.py <<'EOF'
from fastapi import FastAPI
from app.api.routes.execution import router as execution_router

app = FastAPI(title='execution-service', version='0.3.0')
app.include_router(execution_router, prefix='/api/execution', tags=['execution'])

@app.get('/health/live')
def health_live():
    return {'status': 'ok', 'service': 'execution-service'}

@app.get('/health/ready')
def health_ready():
    return {'status': 'ready', 'service': 'execution-service'}
EOF

cat > apps/reconciliation-service/pyproject.toml <<'EOF'
[project]
name = "reconciliation-service"
version = "0.1.0"
requires-python = ">=3.12"
EOF

cat > apps/reconciliation-service/Dockerfile <<'EOF'
FROM python:3.12-slim
WORKDIR /workspace
COPY packages /workspace/packages
COPY apps/reconciliation-service /workspace/apps/reconciliation-service
RUN pip install --no-cache-dir fastapi uvicorn sqlalchemy psycopg[binary] pydantic pydantic-settings
ENV PYTHONPATH=/workspace/packages:/workspace/apps/reconciliation-service
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

cat > apps/reconciliation-service/app/config.py <<'EOF'
from shared_config.settings import Settings
settings = Settings(app_name='reconciliation-service', port=8000)
EOF

cat > apps/reconciliation-service/app/db/session.py <<'EOF'
from sqlalchemy.orm import Session
from shared_db.database import build_session_factory
from app.config import settings
SessionLocal = build_session_factory(settings.sqlalchemy_url)

def get_db():
    db: Session = SessionLocal()
    try:
        yield db
    finally:
        db.close()
EOF

cat > apps/reconciliation-service/app/db/models.py <<'EOF'
from sqlalchemy import String, DateTime, JSON, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base

class ReconciliationRunModel(Base):
    __tablename__ = 'reconciliation_runs'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    run_type: Mapped[str] = mapped_column(String(50), nullable=False)
    account_id: Mapped[str] = mapped_column(String, nullable=True)
    venue_id: Mapped[str] = mapped_column(String, nullable=True)
    status: Mapped[str] = mapped_column(String(50), nullable=False, default='running')
    summary_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    started_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    completed_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())

class ReconciliationIssueModel(Base):
    __tablename__ = 'reconciliation_issues'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    reconciliation_run_id: Mapped[str] = mapped_column(String, nullable=True)
    issue_type: Mapped[str] = mapped_column(String(100), nullable=False)
    account_id: Mapped[str] = mapped_column(String, nullable=True)
    venue_id: Mapped[str] = mapped_column(String, nullable=True)
    severity: Mapped[str] = mapped_column(String(20), nullable=False)
    internal_ref: Mapped[str] = mapped_column(String(255), nullable=True)
    external_ref: Mapped[str] = mapped_column(String(255), nullable=True)
    difference_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    recommended_action: Mapped[str] = mapped_column(String(100), nullable=True)
    status: Mapped[str] = mapped_column(String(50), nullable=False, default='open')
    correlation_id: Mapped[str] = mapped_column(String, nullable=True)
    detected_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    resolved_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
EOF

cat > apps/reconciliation-service/app/domain/reconcile.py <<'EOF'
import uuid
from datetime import datetime, timezone
from app.db.models import ReconciliationRunModel, ReconciliationIssueModel


def create_run(db, *, run_type: str, account_id: str | None = None, venue_id: str | None = None):
    row = ReconciliationRunModel(
        id=str(uuid.uuid4()),
        run_type=run_type,
        account_id=account_id,
        venue_id=venue_id,
        status='running',
        summary_json={},
        started_at=datetime.now(timezone.utc),
    )
    db.add(row)
    db.flush()
    return row


def create_issue(db, *, reconciliation_run_id: str | None, issue_type: str, severity: str, difference_json: dict, recommended_action: str, account_id: str | None = None, venue_id: str | None = None, internal_ref: str | None = None, external_ref: str | None = None, correlation_id: str | None = None):
    row = ReconciliationIssueModel(
        id=str(uuid.uuid4()),
        reconciliation_run_id=reconciliation_run_id,
        issue_type=issue_type,
        account_id=account_id,
        venue_id=venue_id,
        severity=severity,
        internal_ref=internal_ref,
        external_ref=external_ref,
        difference_json=difference_json,
        recommended_action=recommended_action,
        status='open',
        correlation_id=correlation_id,
        detected_at=datetime.now(timezone.utc),
    )
    db.add(row)
    return row
EOF

cat > apps/reconciliation-service/app/api/routes/reconciliation.py <<'EOF'
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import ReconciliationRunModel, ReconciliationIssueModel
from app.domain.reconcile import create_run, create_issue

router = APIRouter()

@router.post('/runs')
def create_reconciliation_run(payload: dict, db: Session = Depends(get_db)):
    row = create_run(db, run_type=payload['run_type'], account_id=payload.get('account_id'), venue_id=payload.get('venue_id'))
    db.commit()
    return {'id': row.id, 'status': row.status}

@router.get('/runs')
def list_reconciliation_runs(db: Session = Depends(get_db)):
    rows = db.query(ReconciliationRunModel).order_by(ReconciliationRunModel.created_at.desc()).limit(200).all()
    return [{'id': x.id, 'run_type': x.run_type, 'status': x.status, 'started_at': x.started_at} for x in rows]

@router.post('/issues')
def create_reconciliation_issue(payload: dict, db: Session = Depends(get_db)):
    row = create_issue(
        db,
        reconciliation_run_id=payload.get('reconciliation_run_id'),
        issue_type=payload['issue_type'],
        severity=payload['severity'],
        difference_json=payload.get('difference_json', {}),
        recommended_action=payload.get('recommended_action', 'manual_review'),
        account_id=payload.get('account_id'),
        venue_id=payload.get('venue_id'),
        internal_ref=payload.get('internal_ref'),
        external_ref=payload.get('external_ref'),
        correlation_id=payload.get('correlation_id'),
    )
    db.commit()
    return {'id': row.id, 'status': row.status}

@router.get('/issues')
def list_reconciliation_issues(db: Session = Depends(get_db)):
    rows = db.query(ReconciliationIssueModel).order_by(ReconciliationIssueModel.created_at.desc()).limit(200).all()
    return [{'id': x.id, 'issue_type': x.issue_type, 'severity': x.severity, 'status': x.status} for x in rows]
EOF

cat > apps/reconciliation-service/app/main.py <<'EOF'
from fastapi import FastAPI
from app.api.routes.reconciliation import router as reconciliation_router

app = FastAPI(title='reconciliation-service', version='0.1.0')
app.include_router(reconciliation_router, prefix='/api/reconciliation', tags=['reconciliation'])

@app.get('/health/live')
def health_live():
    return {'status': 'ok', 'service': 'reconciliation-service'}

@app.get('/health/ready')
def health_ready():
    return {'status': 'ready', 'service': 'reconciliation-service'}
EOF

python - <<'PY'
from pathlib import Path
p = Path('docker-compose.yml')
text = p.read_text()
add = '''

  reconciliation-service:
    build: ./apps/reconciliation-service
    ports: ["8018:8000"]
    depends_on: [postgres]
'''
if 'reconciliation-service:' not in text:
    text += add
    p.write_text(text)
PY

cat > scripts/smoke/risk_execution_reconciliation_smoke.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
curl -s -X POST http://localhost:8006/api/risk/kill-switches -H "Content-Type: application/json" -d '{"scope_type":"global","switch_action":"reject_new_orders","reason":"smoke_test"}'
echo
curl -s http://localhost:8006/api/risk/kill-switches
echo
curl -s http://localhost:8007/api/execution/quality-metrics
echo
curl -s -X POST http://localhost:8018/api/reconciliation/runs -H "Content-Type: application/json" -d '{"run_type":"order"}'
echo
curl -s http://localhost:8018/api/reconciliation/runs
echo
EOF
chmod +x scripts/smoke/risk_execution_reconciliation_smoke.sh

echo "Risk controls, execution quality, and reconciliation bootstrap applied."
echo "Next: bash scripts/migrate/run_all.sh && restart services."
