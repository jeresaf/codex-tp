#!/usr/bin/env bash
set -euo pipefail

# Market data, feature store, and replay bootstrap writer.
# Run inside the existing trading-platform repo root.

ROOT="$(pwd)"
if [ ! -f "$ROOT/docker-compose.yml" ]; then
  echo "Run this inside the trading-platform repo root."
  exit 1
fi

mkdir -p \
  sql \
  packages/shared-market-data/shared_market_data \
  packages/shared-features/shared_features/{indicators,registry} \
  apps/market-data-service/app/{api/routes,db,domain,events/{outbox,publishers}} \
  apps/feature-service/app/{api/routes,db,domain} \
  apps/dataset-service/app/{api/routes,db} \
  apps/replay-service/app/{api/routes,db,domain}

cat > sql/009_market_data_features_research.sql <<'EOF'
CREATE TABLE IF NOT EXISTS raw_market_events (
    id UUID PRIMARY KEY,
    provider_code VARCHAR(100) NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    external_symbol VARCHAR(100),
    payload_json JSONB NOT NULL,
    event_time TIMESTAMPTZ,
    arrival_time TIMESTAMPTZ NOT NULL,
    checksum VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS normalized_candles (
    id UUID PRIMARY KEY,
    instrument_id UUID NOT NULL,
    timeframe VARCHAR(20) NOT NULL,
    open_time TIMESTAMPTZ NOT NULL,
    close_time TIMESTAMPTZ NOT NULL,
    open NUMERIC(24,10) NOT NULL,
    high NUMERIC(24,10) NOT NULL,
    low NUMERIC(24,10) NOT NULL,
    close NUMERIC(24,10) NOT NULL,
    volume NUMERIC(24,10),
    source VARCHAR(100) NOT NULL,
    quality_flag VARCHAR(20) NOT NULL DEFAULT 'ok',
    arrival_time TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS normalized_ticks (
    id UUID PRIMARY KEY,
    instrument_id UUID NOT NULL,
    event_time TIMESTAMPTZ NOT NULL,
    bid NUMERIC(24,10),
    ask NUMERIC(24,10),
    last NUMERIC(24,10),
    bid_size NUMERIC(24,10),
    ask_size NUMERIC(24,10),
    source VARCHAR(100) NOT NULL,
    quality_flag VARCHAR(20) NOT NULL DEFAULT 'ok',
    arrival_time TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS data_quality_issues (
    id UUID PRIMARY KEY,
    provider_code VARCHAR(100) NOT NULL,
    instrument_id UUID,
    timeframe VARCHAR(20),
    issue_type VARCHAR(100) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    details_json JSONB,
    detected_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS feature_definitions (
    id UUID PRIMARY KEY,
    feature_code VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    timeframe VARCHAR(20) NOT NULL,
    formula_ref VARCHAR(255),
    implementation_version VARCHAR(50) NOT NULL,
    required_warmup INT NOT NULL DEFAULT 0,
    null_handling VARCHAR(50) NOT NULL DEFAULT 'propagate',
    dependencies_json JSONB,
    output_schema_json JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS feature_values (
    id UUID PRIMARY KEY,
    feature_code VARCHAR(100) NOT NULL,
    instrument_id UUID NOT NULL,
    timeframe VARCHAR(20) NOT NULL,
    value_time TIMESTAMPTZ NOT NULL,
    value_double DOUBLE PRECISION,
    value_json JSONB,
    quality_flag VARCHAR(20) NOT NULL DEFAULT 'ok',
    source_run_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS dataset_versions (
    id UUID PRIMARY KEY,
    dataset_code VARCHAR(100) NOT NULL,
    dataset_version VARCHAR(50) NOT NULL,
    manifest_json JSONB NOT NULL,
    storage_uri TEXT,
    checksum VARCHAR(255),
    created_by UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(dataset_code, dataset_version)
);

CREATE TABLE IF NOT EXISTS replay_jobs (
    id UUID PRIMARY KEY,
    dataset_version_id UUID NOT NULL REFERENCES dataset_versions(id),
    strategy_version_id UUID,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'queued',
    config_json JSONB,
    result_uri TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
EOF

python - <<'PY'
from pathlib import Path
p = Path('scripts/migrate/run_all.sh')
text = p.read_text()
if 'sql/009_market_data_features_research.sql' not in text:
    text = text.replace('sql/008_strategy_portfolio.sql', 'sql/008_strategy_portfolio.sql \\\n         sql/009_market_data_features_research.sql')
    p.write_text(text)
PY

cat > packages/shared-market-data/shared_market_data/__init__.py <<'EOF'
EOF

cat > packages/shared-market-data/shared_market_data/candles.py <<'EOF'
def validate_candle(candle: dict) -> list[str]:
    issues = []
    if float(candle['low']) > float(candle['high']):
        issues.append('low_gt_high')
    if float(candle['open']) < 0 or float(candle['high']) < 0 or float(candle['low']) < 0 or float(candle['close']) < 0:
        issues.append('negative_price')
    return issues
EOF

cat > packages/shared-features/shared_features/__init__.py <<'EOF'
EOF

cat > packages/shared-features/shared_features/indicators/__init__.py <<'EOF'
EOF

cat > packages/shared-features/shared_features/indicators/sma.py <<'EOF'
def sma(values: list[float], period: int) -> float | None:
    if len(values) < period or period <= 0:
        return None
    window = values[-period:]
    return sum(window) / period
EOF

cat > packages/shared-features/shared_features/registry/__init__.py <<'EOF'
EOF

cat > packages/shared-features/shared_features/registry/feature_registry.py <<'EOF'
from shared_features.indicators.sma import sma

FEATURE_REGISTRY = {
    'SMA_20': {'fn': lambda values: sma(values, 20), 'warmup': 20, 'timeframe': '1m'},
    'SMA_50': {'fn': lambda values: sma(values, 50), 'warmup': 50, 'timeframe': '1m'},
}
EOF

create_service_files() {
  local svc="$1"
  mkdir -p "apps/$svc/app"
  cat > "apps/$svc/pyproject.toml" <<EOF
[project]
name = "$svc"
version = "0.1.0"
requires-python = ">=3.12"
EOF
  cat > "apps/$svc/Dockerfile" <<EOF
FROM python:3.12-slim
WORKDIR /workspace
COPY packages /workspace/packages
COPY apps/$svc /workspace/apps/$svc
RUN pip install --no-cache-dir fastapi uvicorn sqlalchemy psycopg[binary] pydantic pydantic-settings pyjwt
ENV PYTHONPATH=/workspace/packages:/workspace/apps/$svc
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF
  cat > "apps/$svc/app/config.py" <<EOF
from shared_config.settings import Settings
settings = Settings(app_name="$svc", port=8000)
EOF
  cat > "apps/$svc/app/db/session.py" <<'EOF'
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
}

create_service_files market-data-service
create_service_files feature-service
create_service_files dataset-service
create_service_files replay-service

cat > apps/market-data-service/app/db/models.py <<'EOF'
from sqlalchemy import String, DateTime, JSON, Numeric, Integer, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base

class RawMarketEventModel(Base):
    __tablename__ = 'raw_market_events'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    provider_code: Mapped[str] = mapped_column(String(100), nullable=False)
    event_type: Mapped[str] = mapped_column(String(50), nullable=False)
    external_symbol: Mapped[str] = mapped_column(String(100), nullable=True)
    payload_json: Mapped[dict] = mapped_column(JSON, nullable=False)
    event_time: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
    arrival_time: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    checksum: Mapped[str] = mapped_column(String(255), nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())

class NormalizedCandleModel(Base):
    __tablename__ = 'normalized_candles'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    instrument_id: Mapped[str] = mapped_column(String, nullable=False)
    timeframe: Mapped[str] = mapped_column(String(20), nullable=False)
    open_time: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    close_time: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    open: Mapped[float] = mapped_column(Numeric(24,10), nullable=False)
    high: Mapped[float] = mapped_column(Numeric(24,10), nullable=False)
    low: Mapped[float] = mapped_column(Numeric(24,10), nullable=False)
    close: Mapped[float] = mapped_column(Numeric(24,10), nullable=False)
    volume: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    source: Mapped[str] = mapped_column(String(100), nullable=False)
    quality_flag: Mapped[str] = mapped_column(String(20), nullable=False, default='ok')
    arrival_time: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())

class OutboxEventModel(Base):
    __tablename__ = 'outbox_events'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    aggregate_type: Mapped[str] = mapped_column(String(100), nullable=False)
    aggregate_id: Mapped[str] = mapped_column(String, nullable=False)
    event_type: Mapped[str] = mapped_column(String(150), nullable=False)
    event_version: Mapped[int] = mapped_column(Integer, nullable=False)
    correlation_id: Mapped[str] = mapped_column(String, nullable=True)
    causation_id: Mapped[str] = mapped_column(String, nullable=True)
    payload_json: Mapped[dict] = mapped_column(JSON, nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default='pending')
    retry_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    next_attempt_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    published_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
    last_error: Mapped[str] = mapped_column(String, nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
EOF

cat > apps/market-data-service/app/domain/normalize.py <<'EOF'
import uuid
from datetime import datetime, timezone
from shared_market_data.candles import validate_candle


def normalize_demo_candle(payload: dict) -> tuple[dict, list[str]]:
    candle = {
        'id': str(uuid.uuid4()),
        'instrument_id': payload['instrument_id'],
        'timeframe': payload.get('timeframe', '1m'),
        'open_time': payload['open_time'],
        'close_time': payload['close_time'],
        'open': payload['open'],
        'high': payload['high'],
        'low': payload['low'],
        'close': payload['close'],
        'volume': payload.get('volume', 0),
        'source': payload.get('source', 'demo-feed'),
        'quality_flag': 'ok',
        'arrival_time': datetime.now(timezone.utc).isoformat(),
    }
    issues = validate_candle(candle)
    if issues:
        candle['quality_flag'] = 'warning'
    return candle, issues
EOF

cat > apps/market-data-service/app/events/publishers/outbox_publisher.py <<'EOF'
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from app.db.models import OutboxEventModel

def publish_pending_outbox(db: Session, limit: int = 100) -> list[dict]:
    rows = db.query(OutboxEventModel).filter(OutboxEventModel.status == 'pending').order_by(OutboxEventModel.created_at.asc()).limit(limit).all()
    published = []
    for row in rows:
        row.status = 'published'
        row.published_at = datetime.now(timezone.utc)
        published.append({'event_id': row.id, 'event_type': row.event_type, 'correlation_id': row.correlation_id, 'payload': row.payload_json})
    db.commit()
    return published
EOF

cat > apps/market-data-service/app/api/routes/market_data.py <<'EOF'
import uuid
from datetime import datetime, timezone
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import RawMarketEventModel, NormalizedCandleModel, OutboxEventModel
from app.domain.normalize import normalize_demo_candle
from shared_events.outbox import append_outbox_event

router = APIRouter()

@router.post('/ingest-candle')
def ingest_candle(payload: dict, db: Session = Depends(get_db)):
    raw = RawMarketEventModel(
        id=str(uuid.uuid4()),
        provider_code=payload.get('provider_code', 'demo'),
        event_type='candle',
        external_symbol=payload.get('external_symbol'),
        payload_json=payload,
        event_time=payload.get('close_time'),
        arrival_time=datetime.now(timezone.utc),
        checksum=None,
    )
    db.add(raw)
    db.flush()
    candle, issues = normalize_demo_candle(payload)
    norm = NormalizedCandleModel(**candle)
    db.add(norm)
    db.flush()
    append_outbox_event(
        db=db,
        model_cls=OutboxEventModel,
        aggregate_type='normalized_candle',
        aggregate_id=norm.id,
        event_type='market_data.candle.closed',
        event_version=1,
        correlation_id=payload.get('correlation_id'),
        causation_id=None,
        payload_json={
            'candle_id': norm.id,
            'instrument_id': norm.instrument_id,
            'timeframe': norm.timeframe,
            'open_time': str(norm.open_time),
            'close_time': str(norm.close_time),
            'open': str(norm.open),
            'high': str(norm.high),
            'low': str(norm.low),
            'close': str(norm.close),
            'volume': str(norm.volume or 0),
            'quality_flag': norm.quality_flag,
        },
    )
    db.commit()
    return {'raw_id': raw.id, 'normalized_id': norm.id, 'issues': issues}

@router.get('/candles')
def list_candles(db: Session = Depends(get_db)):
    rows = db.query(NormalizedCandleModel).order_by(NormalizedCandleModel.close_time.desc()).limit(200).all()
    return [{
        'id': x.id,
        'instrument_id': x.instrument_id,
        'timeframe': x.timeframe,
        'open_time': x.open_time,
        'close_time': x.close_time,
        'open': str(x.open),
        'high': str(x.high),
        'low': str(x.low),
        'close': str(x.close),
        'quality_flag': x.quality_flag,
    } for x in rows]
EOF

cat > apps/market-data-service/app/main.py <<'EOF'
from fastapi import FastAPI
from app.api.routes.market_data import router as market_data_router

app = FastAPI(title='market-data-service', version='0.1.0')
app.include_router(market_data_router, prefix='/api/market-data', tags=['market-data'])

@app.get('/health/live')
def health_live():
    return {'status': 'ok', 'service': 'market-data-service'}

@app.get('/health/ready')
def health_ready():
    return {'status': 'ready', 'service': 'market-data-service'}
EOF

cat > apps/feature-service/app/db/models.py <<'EOF'
from sqlalchemy import String, DateTime, JSON, Integer, Double, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base

class FeatureDefinitionModel(Base):
    __tablename__ = 'feature_definitions'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    feature_code: Mapped[str] = mapped_column(String(100), nullable=False, unique=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str] = mapped_column(String, nullable=True)
    timeframe: Mapped[str] = mapped_column(String(20), nullable=False)
    formula_ref: Mapped[str] = mapped_column(String(255), nullable=True)
    implementation_version: Mapped[str] = mapped_column(String(50), nullable=False)
    required_warmup: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    null_handling: Mapped[str] = mapped_column(String(50), nullable=False, default='propagate')
    dependencies_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    output_schema_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())

class FeatureValueModel(Base):
    __tablename__ = 'feature_values'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    feature_code: Mapped[str] = mapped_column(String(100), nullable=False)
    instrument_id: Mapped[str] = mapped_column(String, nullable=False)
    timeframe: Mapped[str] = mapped_column(String(20), nullable=False)
    value_time: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    value_double: Mapped[float] = mapped_column(Double, nullable=True)
    value_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    quality_flag: Mapped[str] = mapped_column(String(20), nullable=False, default='ok')
    source_run_id: Mapped[str] = mapped_column(String, nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
EOF

cat > apps/feature-service/app/domain/backfill.py <<'EOF'
import uuid
from shared_features.registry.feature_registry import FEATURE_REGISTRY
from app.db.models import FeatureValueModel


def backfill_features(db, candles: list[dict], feature_codes: list[str]) -> dict:
    grouped = {}
    for c in sorted(candles, key=lambda x: x['close_time']):
        grouped.setdefault(c['instrument_id'], []).append(float(c['close']))
    written = 0
    for instrument_id, closes in grouped.items():
        for feature_code in feature_codes:
            meta = FEATURE_REGISTRY[feature_code]
            value = meta['fn'](closes)
            if value is None:
                continue
            row = FeatureValueModel(
                id=str(uuid.uuid4()),
                feature_code=feature_code,
                instrument_id=instrument_id,
                timeframe=meta['timeframe'],
                value_time=candles[-1]['close_time'],
                value_double=value,
                value_json=None,
                quality_flag='ok',
                source_run_id=None,
            )
            db.add(row)
            written += 1
    db.commit()
    return {'written': written}
EOF

cat > apps/feature-service/app/api/routes/features.py <<'EOF'
import uuid
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import FeatureDefinitionModel, FeatureValueModel
from app.domain.backfill import backfill_features
from shared_features.registry.feature_registry import FEATURE_REGISTRY

router = APIRouter()

@router.post('/seed-definitions')
def seed_definitions(db: Session = Depends(get_db)):
    created = 0
    for code, meta in FEATURE_REGISTRY.items():
        exists = db.query(FeatureDefinitionModel).filter(FeatureDefinitionModel.feature_code == code).first()
        if exists:
            continue
        row = FeatureDefinitionModel(
            id=str(uuid.uuid4()),
            feature_code=code,
            name=code,
            description=f'{code} feature',
            timeframe=meta['timeframe'],
            formula_ref=code,
            implementation_version='0.1.0',
            required_warmup=meta['warmup'],
            null_handling='propagate',
            dependencies_json={},
            output_schema_json={'type': 'double'},
        )
        db.add(row)
        created += 1
    db.commit()
    return {'created': created}

@router.get('/definitions')
def list_definitions(db: Session = Depends(get_db)):
    rows = db.query(FeatureDefinitionModel).order_by(FeatureDefinitionModel.feature_code.asc()).all()
    return [{'id': x.id, 'feature_code': x.feature_code, 'timeframe': x.timeframe, 'required_warmup': x.required_warmup} for x in rows]

@router.get('/values')
def list_values(db: Session = Depends(get_db)):
    rows = db.query(FeatureValueModel).order_by(FeatureValueModel.created_at.desc()).limit(200).all()
    return [{'id': x.id, 'feature_code': x.feature_code, 'instrument_id': x.instrument_id, 'value_time': x.value_time, 'value_double': x.value_double} for x in rows]

@router.post('/backfill')
def backfill(payload: dict, db: Session = Depends(get_db)):
    return backfill_features(db, payload['candles'], payload['feature_codes'])
EOF

cat > apps/feature-service/app/main.py <<'EOF'
from fastapi import FastAPI
from app.api.routes.features import router as features_router

app = FastAPI(title='feature-service', version='0.1.0')
app.include_router(features_router, prefix='/api/features', tags=['features'])

@app.get('/health/live')
def health_live():
    return {'status': 'ok', 'service': 'feature-service'}

@app.get('/health/ready')
def health_ready():
    return {'status': 'ready', 'service': 'feature-service'}
EOF

cat > apps/dataset-service/app/db/models.py <<'EOF'
from sqlalchemy import String, DateTime, JSON, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base

class DatasetVersionModel(Base):
    __tablename__ = 'dataset_versions'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    dataset_code: Mapped[str] = mapped_column(String(100), nullable=False)
    dataset_version: Mapped[str] = mapped_column(String(50), nullable=False)
    manifest_json: Mapped[dict] = mapped_column(JSON, nullable=False)
    storage_uri: Mapped[str] = mapped_column(String, nullable=True)
    checksum: Mapped[str] = mapped_column(String(255), nullable=True)
    created_by: Mapped[str] = mapped_column(String, nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
EOF

cat > apps/dataset-service/app/api/routes/datasets.py <<'EOF'
import uuid
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import DatasetVersionModel

router = APIRouter()

@router.post('/')
def create_dataset(payload: dict, db: Session = Depends(get_db)):
    row = DatasetVersionModel(
        id=str(uuid.uuid4()),
        dataset_code=payload['dataset_code'],
        dataset_version=payload['dataset_version'],
        manifest_json=payload['manifest_json'],
        storage_uri=payload.get('storage_uri'),
        checksum=payload.get('checksum'),
        created_by=payload.get('created_by'),
    )
    db.add(row)
    db.commit()
    return {'id': row.id}

@router.get('/')
def list_datasets(db: Session = Depends(get_db)):
    rows = db.query(DatasetVersionModel).order_by(DatasetVersionModel.created_at.desc()).all()
    return [{'id': x.id, 'dataset_code': x.dataset_code, 'dataset_version': x.dataset_version, 'created_at': x.created_at} for x in rows]
EOF

cat > apps/dataset-service/app/main.py <<'EOF'
from fastapi import FastAPI
from app.api.routes.datasets import router as datasets_router

app = FastAPI(title='dataset-service', version='0.1.0')
app.include_router(datasets_router, prefix='/api/datasets', tags=['datasets'])

@app.get('/health/live')
def health_live():
    return {'status': 'ok', 'service': 'dataset-service'}

@app.get('/health/ready')
def health_ready():
    return {'status': 'ready', 'service': 'dataset-service'}
EOF

cat > apps/replay-service/app/db/models.py <<'EOF'
from sqlalchemy import String, DateTime, JSON, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base

class ReplayJobModel(Base):
    __tablename__ = 'replay_jobs'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    dataset_version_id: Mapped[str] = mapped_column(String, nullable=False)
    strategy_version_id: Mapped[str] = mapped_column(String, nullable=True)
    start_time: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    end_time: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    status: Mapped[str] = mapped_column(String(50), nullable=False, default='queued')
    config_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    result_uri: Mapped[str] = mapped_column(String, nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
EOF

cat > apps/replay-service/app/domain/replay_runner.py <<'EOF'
def run_replay_stub(payload: dict) -> dict:
    return {
        'status': 'queued',
        'message': 'Replay skeleton created',
        'dataset_version_id': payload['dataset_version_id'],
        'start_time': payload['start_time'],
        'end_time': payload['end_time'],
    }
EOF

cat > apps/replay-service/app/api/routes/replay.py <<'EOF'
import uuid
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import ReplayJobModel
from app.domain.replay_runner import run_replay_stub

router = APIRouter()

@router.post('/jobs')
def create_replay_job(payload: dict, db: Session = Depends(get_db)):
    row = ReplayJobModel(
        id=str(uuid.uuid4()),
        dataset_version_id=payload['dataset_version_id'],
        strategy_version_id=payload.get('strategy_version_id'),
        start_time=payload['start_time'],
        end_time=payload['end_time'],
        status='queued',
        config_json=payload.get('config_json', {}),
        result_uri=None,
    )
    db.add(row)
    db.commit()
    return {'id': row.id, **run_replay_stub(payload)}

@router.get('/jobs')
def list_replay_jobs(db: Session = Depends(get_db)):
    rows = db.query(ReplayJobModel).order_by(ReplayJobModel.created_at.desc()).all()
    return [{'id': x.id, 'dataset_version_id': x.dataset_version_id, 'status': x.status, 'created_at': x.created_at} for x in rows]
EOF

cat > apps/replay-service/app/main.py <<'EOF'
from fastapi import FastAPI
from app.api.routes.replay import router as replay_router

app = FastAPI(title='replay-service', version='0.1.0')
app.include_router(replay_router, prefix='/api/replay', tags=['replay'])

@app.get('/health/live')
def health_live():
    return {'status': 'ok', 'service': 'replay-service'}

@app.get('/health/ready')
def health_ready():
    return {'status': 'ready', 'service': 'replay-service'}
EOF

python - <<'PY'
from pathlib import Path
p = Path('docker-compose.yml')
text = p.read_text()
add = '''

  market-data-service:
    build: ./apps/market-data-service
    ports: ["8014:8000"]
    depends_on: [postgres]

  feature-service:
    build: ./apps/feature-service
    ports: ["8015:8000"]
    depends_on: [postgres]

  dataset-service:
    build: ./apps/dataset-service
    ports: ["8016:8000"]
    depends_on: [postgres]

  replay-service:
    build: ./apps/replay-service
    ports: ["8017:8000"]
    depends_on: [postgres]
'''
if 'market-data-service:' not in text:
    text += add
    p.write_text(text)
PY

cat > scripts/smoke/data_feature_replay_smoke.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
INSTRUMENT_ID=$(PGPASSWORD=postgres psql -h localhost -U postgres -d trading_platform -t -A -c "SELECT id FROM instruments WHERE canonical_symbol='EURUSD' LIMIT 1;")
NOW=$(python - <<'PY'
from datetime import datetime, timedelta, timezone
now = datetime.now(timezone.utc)
print(now.isoformat())
PY
)
OPEN=$(python - <<'PY'
from datetime import datetime, timedelta, timezone
now = datetime.now(timezone.utc) - timedelta(minutes=1)
print(now.isoformat())
PY
)

curl -s -X POST http://localhost:8014/api/market-data/ingest-candle \
  -H "Content-Type: application/json" \
  -d "{\"instrument_id\":\"$INSTRUMENT_ID\",\"open_time\":\"$OPEN\",\"close_time\":\"$NOW\",\"open\":1.0800,\"high\":1.0860,\"low\":1.0790,\"close\":1.0850,\"volume\":1000,\"source\":\"demo-feed\"}"
echo
curl -s -X POST http://localhost:8015/api/features/seed-definitions
echo
EOF
chmod +x scripts/smoke/data_feature_replay_smoke.sh

echo "Market data, feature store, and replay bootstrap applied."
echo "Next: bash scripts/migrate/run_all.sh && restart services."
