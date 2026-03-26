#!/usr/bin/env bash
set -euo pipefail

# Strategy runtime and portfolio bootstrap writer.
# Run inside the existing trading-platform repo root.

ROOT="$(pwd)"
if [ ! -f "$ROOT/docker-compose.yml" ]; then
  echo "Run this inside the trading-platform repo root."
  exit 1
fi

mkdir -p \
  sql \
  apps/strategy-service/app/db \
  apps/strategy-runtime-service/app/{api/routes,db,domain,workers,events/{outbox,publishers,consumers}} \
  apps/signal-service/app/{api/routes,db} \
  apps/portfolio-service/app/{api/routes,db,domain,events/{outbox,publishers,consumers}} \
  packages/strategy-sdk/strategy_sdk \
  packages/shared-portfolio/shared_portfolio

cat > sql/008_strategy_portfolio.sql <<'EOF'
CREATE TABLE IF NOT EXISTS strategy_signals (
    id UUID PRIMARY KEY,
    strategy_deployment_id UUID NOT NULL,
    strategy_version_id UUID,
    instrument_id UUID NOT NULL,
    signal_type VARCHAR(50) NOT NULL,
    direction VARCHAR(20),
    strength DOUBLE PRECISION,
    confidence DOUBLE PRECISION,
    time_horizon VARCHAR(50),
    reason_codes JSONB,
    metadata_json JSONB,
    correlation_id UUID,
    signal_timestamp TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS portfolio_targets (
    id UUID PRIMARY KEY,
    account_id UUID,
    instrument_id UUID NOT NULL,
    target_quantity NUMERIC(24,10),
    current_quantity NUMERIC(24,10),
    delta_quantity NUMERIC(24,10),
    source_signal_ids JSONB,
    allocation_snapshot JSONB,
    correlation_id UUID,
    target_timestamp TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS strategy_runtime_heartbeats (
    id UUID PRIMARY KEY,
    strategy_deployment_id UUID NOT NULL,
    strategy_version_id UUID,
    worker_id UUID NOT NULL,
    status VARCHAR(50) NOT NULL,
    last_processed_event_at TIMESTAMPTZ,
    correlation_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE strategy_deployments ADD COLUMN IF NOT EXISTS deployment_status VARCHAR(50) DEFAULT 'draft';
ALTER TABLE strategy_deployments ADD COLUMN IF NOT EXISTS runtime_mode VARCHAR(20) DEFAULT 'paper';
ALTER TABLE strategy_deployments ADD COLUMN IF NOT EXISTS capital_budget NUMERIC(24,10);
ALTER TABLE strategy_deployments ADD COLUMN IF NOT EXISTS instrument_scope_json JSONB;
EOF

python - <<'PY'
from pathlib import Path
p = Path('scripts/migrate/run_all.sh')
text = p.read_text()
if 'sql/008_strategy_portfolio.sql' not in text:
    text = text.replace('sql/007_event_driven.sql', 'sql/007_event_driven.sql \\\n         sql/008_strategy_portfolio.sql')
    p.write_text(text)
PY

cat > packages/strategy-sdk/strategy_sdk/__init__.py <<'EOF'
EOF

cat > packages/strategy-sdk/strategy_sdk/contracts.py <<'EOF'
from dataclasses import dataclass, field
from typing import Any


@dataclass
class StrategySignal:
    signal_id: str
    strategy_deployment_id: str
    strategy_version_id: str | None
    instrument_id: str
    timestamp: str
    signal_type: str
    direction: str
    strength: float
    confidence: float
    time_horizon: str
    reason_codes: list[str] = field(default_factory=list)
    metadata: dict[str, Any] = field(default_factory=dict)


class BaseStrategy:
    strategy_code: str = "base"
    version: str = "0.1.0"
    supported_markets: list[str] = []
    supported_asset_classes: list[str] = []
    supported_timeframes: list[str] = []
    required_features: list[str] = []
    warmup_period: int = 0

    def on_candle(self, candle: dict, context: dict) -> list[StrategySignal]:
        raise NotImplementedError
EOF

cat > packages/shared-portfolio/shared_portfolio/__init__.py <<'EOF'
EOF

cat > packages/shared-portfolio/shared_portfolio/allocation.py <<'EOF'
def weighted_direction_score(direction: str, strength: float, confidence: float, strategy_weight: float) -> float:
    sign = 1.0 if direction == 'long' else -1.0
    return sign * strength * confidence * strategy_weight


def target_quantity_from_score(score: float, base_quantity: float = 1000.0) -> float:
    if abs(score) < 0.01:
        return 0.0
    qty = base_quantity * abs(score)
    return qty if score > 0 else -qty
EOF

cat > apps/strategy-service/app/db/models.py <<'EOF'
from sqlalchemy import String, Text, DateTime, JSON, Numeric, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base


class Strategy(Base):
    __tablename__ = "strategies"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    code: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    type: Mapped[str] = mapped_column(String(100), nullable=False)
    owner_user_id: Mapped[str] = mapped_column(String, nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(50), nullable=False, default="draft")
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class StrategyDeployment(Base):
    __tablename__ = "strategy_deployments"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    strategy_version_id: Mapped[str] = mapped_column(String, nullable=False)
    environment: Mapped[str] = mapped_column(String(50), nullable=False)
    account_id: Mapped[str] = mapped_column(String, nullable=True)
    status: Mapped[str] = mapped_column(String(50), nullable=False, default="stopped")
    capital_allocation_rule: Mapped[dict] = mapped_column(JSON, nullable=True)
    market_scope_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    deployment_status: Mapped[str] = mapped_column(String(50), nullable=False, default="draft")
    runtime_mode: Mapped[str] = mapped_column(String(20), nullable=False, default="paper")
    capital_budget: Mapped[float] = mapped_column(Numeric(24, 10), nullable=True)
    instrument_scope_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    started_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
    stopped_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
EOF

cat > apps/strategy-runtime-service/pyproject.toml <<'EOF'
[project]
name = "strategy-runtime-service"
version = "0.1.0"
requires-python = ">=3.12"
EOF

cat > apps/strategy-runtime-service/Dockerfile <<'EOF'
FROM python:3.12-slim
WORKDIR /workspace
COPY packages /workspace/packages
COPY apps/strategy-runtime-service /workspace/apps/strategy-runtime-service
COPY sql /workspace/sql
COPY seeds /workspace/seeds
COPY scripts /workspace/scripts
RUN pip install --no-cache-dir fastapi uvicorn sqlalchemy psycopg[binary] pydantic pydantic-settings httpx pyjwt
ENV PYTHONPATH=/workspace/packages:/workspace/apps/strategy-runtime-service
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

cat > apps/strategy-runtime-service/app/config.py <<'EOF'
from shared_config.settings import Settings


class StrategyRuntimeSettings(Settings):
    internal_service_token: str = "internal-dev-token"


settings = StrategyRuntimeSettings(app_name="strategy-runtime-service", port=8000)
EOF

cat > apps/strategy-runtime-service/app/db/session.py <<'EOF'
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

cat > apps/strategy-runtime-service/app/db/models.py <<'EOF'
from sqlalchemy import String, DateTime, JSON, Integer, Double, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base


class StrategyRuntimeHeartbeatModel(Base):
    __tablename__ = "strategy_runtime_heartbeats"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    strategy_deployment_id: Mapped[str] = mapped_column(String, nullable=False)
    strategy_version_id: Mapped[str] = mapped_column(String, nullable=True)
    worker_id: Mapped[str] = mapped_column(String, nullable=False)
    status: Mapped[str] = mapped_column(String(50), nullable=False)
    last_processed_event_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
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
EOF

cat > apps/strategy-runtime-service/app/domain/sample_strategy.py <<'EOF'
import uuid
from datetime import datetime, timezone
from strategy_sdk.contracts import BaseStrategy, StrategySignal


class MovingAverageCrossSampleStrategy(BaseStrategy):
    strategy_code = "fx_ma_cross"
    version = "0.1.0"
    supported_markets = ["forex"]
    supported_asset_classes = ["forex"]
    supported_timeframes = ["1m"]
    required_features = []
    warmup_period = 1

    def on_candle(self, candle: dict, context: dict) -> list[StrategySignal]:
        if candle.get("close") is None:
            return []
        direction = "long" if float(candle["close"]) >= float(candle["open"]) else "short"
        return [
            StrategySignal(
                signal_id=str(uuid.uuid4()),
                strategy_deployment_id=context["strategy_deployment_id"],
                strategy_version_id=context.get("strategy_version_id"),
                instrument_id=candle["instrument_id"],
                timestamp=datetime.now(timezone.utc).isoformat(),
                signal_type="directional",
                direction=direction,
                strength=0.8,
                confidence=0.75,
                time_horizon="short_term",
                reason_codes=["demo_candle_direction"],
                metadata={"open": candle["open"], "close": candle["close"]},
            )
        ]
EOF

cat > apps/strategy-runtime-service/app/workers/runtime_runner.py <<'EOF'
import uuid
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from app.db.models import StrategyRuntimeHeartbeatModel, OutboxEventModel
from app.domain.sample_strategy import MovingAverageCrossSampleStrategy
from shared_events.outbox import append_outbox_event


def emit_heartbeat(db: Session, strategy_deployment_id: str, strategy_version_id: str | None, worker_id: str, correlation_id: str | None, status: str = "healthy"):
    row = StrategyRuntimeHeartbeatModel(
        id=str(uuid.uuid4()),
        strategy_deployment_id=strategy_deployment_id,
        strategy_version_id=strategy_version_id,
        worker_id=worker_id,
        status=status,
        last_processed_event_at=datetime.now(timezone.utc),
        correlation_id=correlation_id,
    )
    db.add(row)
    db.commit()
    return row


def run_sample_strategy_once(db: Session, candle: dict, strategy_deployment_id: str, strategy_version_id: str | None, correlation_id: str | None):
    worker_id = str(uuid.uuid4())
    emit_heartbeat(db, strategy_deployment_id, strategy_version_id, worker_id, correlation_id, status="healthy")
    strategy = MovingAverageCrossSampleStrategy()
    signals = strategy.on_candle(candle, {
        "strategy_deployment_id": strategy_deployment_id,
        "strategy_version_id": strategy_version_id,
    })
    for signal in signals:
        append_outbox_event(
            db=db,
            model_cls=OutboxEventModel,
            aggregate_type="strategy_signal",
            aggregate_id=signal.signal_id,
            event_type="strategy.signal.generated",
            event_version=1,
            correlation_id=correlation_id,
            causation_id=None,
            payload_json={
                "signal_id": signal.signal_id,
                "strategy_deployment_id": signal.strategy_deployment_id,
                "strategy_version_id": signal.strategy_version_id,
                "instrument_id": signal.instrument_id,
                "timestamp": signal.timestamp,
                "signal_type": signal.signal_type,
                "direction": signal.direction,
                "strength": signal.strength,
                "confidence": signal.confidence,
                "time_horizon": signal.time_horizon,
                "reason_codes": signal.reason_codes,
                "metadata": signal.metadata,
            },
        )
    db.commit()
    return {"signals_emitted": len(signals), "worker_id": worker_id}
EOF

cat > apps/strategy-runtime-service/app/events/publishers/outbox_publisher.py <<'EOF'
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

cat > apps/strategy-runtime-service/app/api/routes/runtime.py <<'EOF'
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.workers.runtime_runner import run_sample_strategy_once

router = APIRouter()


@router.post('/run-sample')
def run_sample(payload: dict, db: Session = Depends(get_db)):
    return run_sample_strategy_once(
        db=db,
        candle=payload['candle'],
        strategy_deployment_id=payload['strategy_deployment_id'],
        strategy_version_id=payload.get('strategy_version_id'),
        correlation_id=payload.get('correlation_id'),
    )
EOF

cat > apps/strategy-runtime-service/app/main.py <<'EOF'
from fastapi import FastAPI
from app.api.routes.runtime import router as runtime_router

app = FastAPI(title="strategy-runtime-service", version="0.1.0")
app.include_router(runtime_router, prefix="/api/runtime", tags=["runtime"])

@app.get('/health/live')
def health_live():
    return {'status': 'ok', 'service': 'strategy-runtime-service'}

@app.get('/health/ready')
def health_ready():
    return {'status': 'ready', 'service': 'strategy-runtime-service'}
EOF

cat > apps/signal-service/pyproject.toml <<'EOF'
[project]
name = "signal-service"
version = "0.1.0"
requires-python = ">=3.12"
EOF

cat > apps/signal-service/Dockerfile <<'EOF'
FROM python:3.12-slim
WORKDIR /workspace
COPY packages /workspace/packages
COPY apps/signal-service /workspace/apps/signal-service
RUN pip install --no-cache-dir fastapi uvicorn sqlalchemy psycopg[binary] pydantic pydantic-settings
ENV PYTHONPATH=/workspace/packages:/workspace/apps/signal-service
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

cat > apps/signal-service/app/config.py <<'EOF'
from shared_config.settings import Settings
settings = Settings(app_name="signal-service", port=8000)
EOF

cat > apps/signal-service/app/db/session.py <<'EOF'
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

cat > apps/signal-service/app/db/models.py <<'EOF'
from sqlalchemy import String, DateTime, JSON, Double, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base


class StrategySignalModel(Base):
    __tablename__ = "strategy_signals"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    strategy_deployment_id: Mapped[str] = mapped_column(String, nullable=False)
    strategy_version_id: Mapped[str] = mapped_column(String, nullable=True)
    instrument_id: Mapped[str] = mapped_column(String, nullable=False)
    signal_type: Mapped[str] = mapped_column(String(50), nullable=False)
    direction: Mapped[str] = mapped_column(String(20), nullable=True)
    strength: Mapped[float] = mapped_column(Double, nullable=True)
    confidence: Mapped[float] = mapped_column(Double, nullable=True)
    time_horizon: Mapped[str] = mapped_column(String(50), nullable=True)
    reason_codes: Mapped[dict] = mapped_column(JSON, nullable=True)
    metadata_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    correlation_id: Mapped[str] = mapped_column(String, nullable=True)
    signal_timestamp: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
EOF

cat > apps/signal-service/app/api/routes/signals.py <<'EOF'
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import StrategySignalModel

router = APIRouter()


@router.get('/')
def list_signals(db: Session = Depends(get_db)):
    rows = db.query(StrategySignalModel).order_by(StrategySignalModel.created_at.desc()).limit(200).all()
    return [
        {
            'id': x.id,
            'strategy_deployment_id': x.strategy_deployment_id,
            'instrument_id': x.instrument_id,
            'direction': x.direction,
            'strength': x.strength,
            'confidence': x.confidence,
            'signal_timestamp': x.signal_timestamp,
        }
        for x in rows
    ]
EOF

cat > apps/signal-service/app/main.py <<'EOF'
from fastapi import FastAPI
from app.api.routes.signals import router as signals_router

app = FastAPI(title="signal-service", version="0.1.0")
app.include_router(signals_router, prefix='/api/signals', tags=['signals'])

@app.get('/health/live')
def health_live():
    return {'status': 'ok', 'service': 'signal-service'}

@app.get('/health/ready')
def health_ready():
    return {'status': 'ready', 'service': 'signal-service'}
EOF

cat > apps/portfolio-service/pyproject.toml <<'EOF'
[project]
name = "portfolio-service"
version = "0.1.0"
requires-python = ">=3.12"
EOF

cat > apps/portfolio-service/Dockerfile <<'EOF'
FROM python:3.12-slim
WORKDIR /workspace
COPY packages /workspace/packages
COPY apps/portfolio-service /workspace/apps/portfolio-service
RUN pip install --no-cache-dir fastapi uvicorn sqlalchemy psycopg[binary] pydantic pydantic-settings
ENV PYTHONPATH=/workspace/packages:/workspace/apps/portfolio-service
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

cat > apps/portfolio-service/app/config.py <<'EOF'
from shared_config.settings import Settings
settings = Settings(app_name="portfolio-service", port=8000)
EOF

cat > apps/portfolio-service/app/db/session.py <<'EOF'
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

cat > apps/portfolio-service/app/db/models.py <<'EOF'
from sqlalchemy import String, DateTime, JSON, Numeric, Integer, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base


class PortfolioTargetModel(Base):
    __tablename__ = "portfolio_targets"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    account_id: Mapped[str] = mapped_column(String, nullable=True)
    instrument_id: Mapped[str] = mapped_column(String, nullable=False)
    target_quantity: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    current_quantity: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    delta_quantity: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    source_signal_ids: Mapped[dict] = mapped_column(JSON, nullable=True)
    allocation_snapshot: Mapped[dict] = mapped_column(JSON, nullable=True)
    correlation_id: Mapped[str] = mapped_column(String, nullable=True)
    target_timestamp: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
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

cat > apps/portfolio-service/app/events/consumers/signal_generated_consumer.py <<'EOF'
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
EOF

cat > apps/portfolio-service/app/events/publishers/outbox_publisher.py <<'EOF'
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

cat > apps/portfolio-service/app/api/routes/targets.py <<'EOF'
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import PortfolioTargetModel

router = APIRouter()


@router.get('/')
def list_targets(db: Session = Depends(get_db)):
    rows = db.query(PortfolioTargetModel).order_by(PortfolioTargetModel.created_at.desc()).limit(200).all()
    return [
        {
            'id': x.id,
            'instrument_id': x.instrument_id,
            'target_quantity': str(x.target_quantity),
            'delta_quantity': str(x.delta_quantity),
            'correlation_id': x.correlation_id,
        }
        for x in rows
    ]
EOF

cat > apps/portfolio-service/app/main.py <<'EOF'
from fastapi import FastAPI
from app.api.routes.targets import router as targets_router

app = FastAPI(title="portfolio-service", version="0.1.0")
app.include_router(targets_router, prefix='/api/targets', tags=['targets'])

@app.get('/health/live')
def health_live():
    return {'status': 'ok', 'service': 'portfolio-service'}

@app.get('/health/ready')
def health_ready():
    return {'status': 'ready', 'service': 'portfolio-service'}
EOF

python - <<'PY'
from pathlib import Path
p = Path('docker-compose.yml')
text = p.read_text()
if 'strategy-runtime-service:' not in text:
    insert = '''

  strategy-runtime-service:
    build: ./apps/strategy-runtime-service
    ports: ["8011:8000"]
    depends_on: [postgres]

  signal-service:
    build: ./apps/signal-service
    ports: ["8012:8000"]
    depends_on: [postgres]

  portfolio-service:
    build: ./apps/portfolio-service
    ports: ["8013:8000"]
    depends_on: [postgres]
'''
    text += insert
    p.write_text(text)
PY

cat > scripts/smoke/runtime_portfolio_smoke.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
TOKEN=$(curl -s -X POST http://localhost:8001/api/auth/login -H "Content-Type: application/json" -d '{"email":"admin@example.com","password":"admin123"}' | python -c 'import sys,json; print(json.load(sys.stdin)["access_token"])')
INSTRUMENT_ID=$(PGPASSWORD=docker compose exec -T postgres psql -h localhost -U postgres -d trading_platform -t -A -c "SELECT id FROM instruments WHERE canonical_symbol='EURUSD' LIMIT 1;")
CORR_ID=$(python - <<'PY'
import uuid
print(uuid.uuid4())
PY
)

curl -s -X POST http://localhost:8011/api/runtime/run-sample \
  -H "Content-Type: application/json" \
  -d "{\"strategy_deployment_id\":\"00000000-0000-0000-0000-000000000001\",\"strategy_version_id\":null,\"correlation_id\":\"$CORR_ID\",\"candle\":{\"instrument_id\":\"$INSTRUMENT_ID\",\"open\":1.0800,\"close\":1.0850}}"
echo
EOF
chmod +x scripts/smoke/runtime_portfolio_smoke.sh

echo "Strategy runtime and portfolio bootstrap applied."
echo "Next: bash scripts/migrate/run_all.sh && restart services."
