#!/usr/bin/env bash
set -euo pipefail

# Single-shell bootstrap writer for the first working vertical slice.
# Run from the parent directory where you want the repo folder created.

ROOT="trading-platform"
mkdir -p "$ROOT"
cd "$ROOT"

mkdir -p \
  packages/shared-config/shared_config \
  packages/shared-db/shared_db \
  packages/shared-auth/shared_auth \
  packages/shared-domain/shared_domain \
  sql seeds \
  scripts/migrate scripts/seed scripts/smoke

for svc in \
  identity-service market-registry-service instrument-master-service strategy-service \
  order-service risk-service execution-service position-service audit-service broker-adapter-simulator
 do
  mkdir -p "apps/$svc/app/api/routes" "apps/$svc/app/db" "apps/$svc/app/domain" "apps/$svc/app/integrations"
 done

mkdir -p apps/web-admin/src/{router,views} apps/web-ops/src/{router,views}

cat > docker-compose.yml <<'EOF'
version: "3.9"

services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_DB: trading_platform
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"

  redis:
    image: redis:7
    ports:
      - "6379:6379"

  redpanda:
    image: docker.redpanda.com/redpandadata/redpanda:v24.1.3
    command:
      - redpanda
      - start
      - --overprovisioned
      - --smp=1
      - --memory=1G
      - --reserve-memory=0M
      - --node-id=0
      - --check=false
      - --kafka-addr=PLAINTEXT://0.0.0.0:9092
      - --advertise-kafka-addr=PLAINTEXT://redpanda:9092
    ports:
      - "9092:9092"

  identity-service:
    build: ./apps/identity-service
    ports: ["8001:8000"]
    depends_on: [postgres]

  market-registry-service:
    build: ./apps/market-registry-service
    ports: ["8002:8000"]
    depends_on: [postgres]

  instrument-master-service:
    build: ./apps/instrument-master-service
    ports: ["8003:8000"]
    depends_on: [postgres]

  strategy-service:
    build: ./apps/strategy-service
    ports: ["8004:8000"]
    depends_on: [postgres]

  order-service:
    build: ./apps/order-service
    ports: ["8005:8000"]
    depends_on: [postgres, redpanda]

  risk-service:
    build: ./apps/risk-service
    ports: ["8006:8000"]
    depends_on: [postgres]

  execution-service:
    build: ./apps/execution-service
    ports: ["8007:8000"]
    depends_on: [postgres]

  position-service:
    build: ./apps/position-service
    ports: ["8008:8000"]
    depends_on: [postgres]

  audit-service:
    build: ./apps/audit-service
    ports: ["8009:8000"]
    depends_on: [postgres]

  broker-adapter-simulator:
    build: ./apps/broker-adapter-simulator
    ports: ["8010:8000"]

  web-admin:
    build: ./apps/web-admin
    ports: ["3000:3000"]

  web-ops:
    build: ./apps/web-ops
    ports: ["3001:3000"]
EOF

cat > Makefile <<'EOF'
up:
	docker-compose up --build -d

down:
	docker-compose down

logs:
	docker-compose logs -f

migrate:
	bash scripts/migrate/run_all.sh

seed:
	bash scripts/seed/run_all.sh

smoke:
	bash scripts/smoke/platform_smoke.sh
EOF

cat > pyproject.toml <<'EOF'
[tool.ruff]
line-length = 100

[tool.pytest.ini_options]
testpaths = ["tests"]

[tool.mypy]
python_version = "3.12"
warn_unused_configs = true
ignore_missing_imports = true
EOF

cat > pnpm-workspace.yaml <<'EOF'
packages:
  - apps/web-admin
  - apps/web-ops
EOF

cat > packages/shared-config/shared_config/__init__.py <<'EOF'
EOF
cat > packages/shared-config/shared_config/settings.py <<'EOF'
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "service"
    env: str = "local"
    host: str = "0.0.0.0"
    port: int = 8000
    db_host: str = "postgres"
    db_port: int = 5432
    db_name: str = "trading_platform"
    db_user: str = "postgres"
    db_password: str = "postgres"
    jwt_secret: str = "dev-secret"
    jwt_algorithm: str = "HS256"
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @property
    def sqlalchemy_url(self) -> str:
        return f"postgresql+psycopg://{self.db_user}:{self.db_password}@{self.db_host}:{self.db_port}/{self.db_name}"
EOF

cat > packages/shared-db/shared_db/__init__.py <<'EOF'
EOF
cat > packages/shared-db/shared_db/database.py <<'EOF'
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

Base = declarative_base()


def build_engine(url: str):
    return create_engine(url, future=True, pool_pre_ping=True)


def build_session_factory(url: str):
    engine = build_engine(url)
    return sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)
EOF

cat > packages/shared-auth/shared_auth/__init__.py <<'EOF'
EOF
cat > packages/shared-auth/shared_auth/jwt_tools.py <<'EOF'
from datetime import datetime, timedelta, timezone
import jwt

JWT_ISSUER = "trading-platform"
JWT_EXP_HOURS = 8


def create_access_token(secret: str, algorithm: str, user: dict) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": user["id"],
        "email": user["email"],
        "roles": user.get("roles", []),
        "permissions": user.get("permissions", []),
        "iss": JWT_ISSUER,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(hours=JWT_EXP_HOURS)).timestamp()),
    }
    return jwt.encode(payload, secret, algorithm=algorithm)
EOF

cat > packages/shared-domain/shared_domain/__init__.py <<'EOF'
EOF
cat > packages/shared-domain/shared_domain/order_state.py <<'EOF'
ALLOWED_TRANSITIONS = {
    "draft": {"risk_pending"},
    "risk_pending": {"risk_passed", "risk_failed"},
    "risk_passed": {"submitted"},
    "submitted": {"filled", "execution_failed", "rejected"},
}


def can_transition(current_state: str, next_state: str) -> bool:
    return next_state in ALLOWED_TRANSITIONS.get(current_state, set())
EOF

cat > sql/001_core_identity.sql <<'EOF'
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'active',
    mfa_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY,
    code VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL
);
CREATE TABLE IF NOT EXISTS permissions (
    id UUID PRIMARY KEY,
    code VARCHAR(150) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL
);
CREATE TABLE IF NOT EXISTS role_permissions (
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);
CREATE TABLE IF NOT EXISTS user_roles (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, role_id)
);
EOF

cat > sql/002_markets_instruments.sql <<'EOF'
CREATE TABLE IF NOT EXISTS markets (
    id UUID PRIMARY KEY,
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    asset_class VARCHAR(50) NOT NULL,
    timezone VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'active'
);
CREATE TABLE IF NOT EXISTS venues (
    id UUID PRIMARY KEY,
    market_id UUID NOT NULL REFERENCES markets(id),
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    venue_type VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'active'
);
CREATE TABLE IF NOT EXISTS instruments (
    id UUID PRIMARY KEY,
    venue_id UUID NOT NULL REFERENCES venues(id),
    canonical_symbol VARCHAR(100) UNIQUE NOT NULL,
    external_symbol VARCHAR(100),
    asset_class VARCHAR(50) NOT NULL,
    base_asset VARCHAR(50),
    quote_asset VARCHAR(50),
    tick_size NUMERIC(24,10) NOT NULL,
    lot_size NUMERIC(24,10) NOT NULL,
    price_precision INT NOT NULL,
    quantity_precision INT NOT NULL,
    contract_multiplier NUMERIC(24,10),
    status VARCHAR(50) NOT NULL DEFAULT 'active'
);
EOF

cat > sql/003_strategies.sql <<'EOF'
CREATE TABLE IF NOT EXISTS strategies (
    id UUID PRIMARY KEY,
    code VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(100) NOT NULL,
    owner_user_id UUID NOT NULL REFERENCES users(id),
    description TEXT,
    status VARCHAR(50) NOT NULL DEFAULT 'draft',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS strategy_versions (
    id UUID PRIMARY KEY,
    strategy_id UUID NOT NULL REFERENCES strategies(id),
    version VARCHAR(50) NOT NULL,
    artifact_uri TEXT NOT NULL,
    code_commit_hash VARCHAR(255),
    parameter_schema JSONB NOT NULL,
    runtime_requirements JSONB,
    approval_state VARCHAR(50) NOT NULL DEFAULT 'draft',
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(strategy_id, version)
);
CREATE TABLE IF NOT EXISTS strategy_deployments (
    id UUID PRIMARY KEY,
    strategy_version_id UUID NOT NULL REFERENCES strategy_versions(id),
    environment VARCHAR(50) NOT NULL,
    account_id UUID,
    status VARCHAR(50) NOT NULL DEFAULT 'stopped',
    capital_allocation_rule JSONB,
    market_scope_json JSONB,
    started_at TIMESTAMPTZ,
    stopped_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
EOF

cat > sql/004_orders_risk.sql <<'EOF'
CREATE TABLE IF NOT EXISTS risk_policies (
    id UUID PRIMARY KEY,
    scope_type VARCHAR(50) NOT NULL,
    scope_id UUID NOT NULL,
    rule_type VARCHAR(100) NOT NULL,
    rule_config_json JSONB NOT NULL,
    severity VARCHAR(20) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS order_intents (
    id UUID PRIMARY KEY,
    strategy_deployment_id UUID REFERENCES strategy_deployments(id),
    account_id UUID,
    instrument_id UUID NOT NULL REFERENCES instruments(id),
    signal_id UUID,
    side VARCHAR(10) NOT NULL,
    order_type VARCHAR(20) NOT NULL,
    quantity NUMERIC(24,10) NOT NULL,
    limit_price NUMERIC(24,10),
    stop_price NUMERIC(24,10),
    tif VARCHAR(20) NOT NULL,
    intent_status VARCHAR(50) NOT NULL DEFAULT 'draft',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS broker_orders (
    id UUID PRIMARY KEY,
    order_intent_id UUID NOT NULL REFERENCES order_intents(id),
    venue_id UUID NOT NULL REFERENCES venues(id),
    external_order_id VARCHAR(255),
    broker_status VARCHAR(50) NOT NULL,
    raw_request JSONB,
    raw_response JSONB,
    submitted_at TIMESTAMPTZ,
    acknowledged_at TIMESTAMPTZ
);
CREATE TABLE IF NOT EXISTS fills (
    id UUID PRIMARY KEY,
    broker_order_id UUID NOT NULL REFERENCES broker_orders(id),
    instrument_id UUID NOT NULL REFERENCES instruments(id),
    fill_price NUMERIC(24,10) NOT NULL,
    fill_quantity NUMERIC(24,10) NOT NULL,
    fee_amount NUMERIC(24,10) DEFAULT 0,
    fee_currency VARCHAR(20),
    fill_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    raw_payload JSONB
);
EOF

cat > sql/005_positions_audit.sql <<'EOF'
CREATE TABLE IF NOT EXISTS positions (
    id UUID PRIMARY KEY,
    account_id UUID,
    instrument_id UUID NOT NULL REFERENCES instruments(id),
    net_quantity NUMERIC(24,10) NOT NULL DEFAULT 0,
    avg_price NUMERIC(24,10) NOT NULL DEFAULT 0,
    market_value NUMERIC(24,10) NOT NULL DEFAULT 0,
    unrealized_pnl NUMERIC(24,10) NOT NULL DEFAULT 0,
    realized_pnl NUMERIC(24,10) NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS audit_events (
    id UUID PRIMARY KEY,
    actor_type VARCHAR(50) NOT NULL,
    actor_id UUID,
    event_type VARCHAR(100) NOT NULL,
    resource_type VARCHAR(100) NOT NULL,
    resource_id UUID,
    before_json JSONB,
    after_json JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
EOF

cat > seeds/seed_core.py <<'EOF'
import uuid
from passlib.context import CryptContext
import psycopg

pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")


def insert_if_missing(cur, table, unique_col, unique_val, data):
    cur.execute(f"SELECT 1 FROM {table} WHERE {unique_col} = %s", (unique_val,))
    if cur.fetchone():
        return
    cols = ", ".join(data.keys())
    placeholders = ", ".join(["%s"] * len(data))
    cur.execute(f"INSERT INTO {table} ({cols}) VALUES ({placeholders})", tuple(data.values()))


conn = psycopg.connect("host=localhost port=5432 dbname=trading_platform user=postgres password=postgres")
with conn:
    with conn.cursor() as cur:
        for code, name in [
            ("super_admin", "Super Admin"),
            ("platform_admin", "Platform Admin"),
            ("quant_researcher", "Quant Researcher"),
            ("strategy_developer", "Strategy Developer"),
            ("operations", "Operations"),
            ("risk_officer", "Risk Officer"),
            ("compliance_officer", "Compliance Officer"),
            ("executive_viewer", "Executive Viewer"),
        ]:
            insert_if_missing(cur, "roles", "code", code, {"id": str(uuid.uuid4()), "code": code, "name": name})
        for code, name in [
            ("users.read", "Read users"),
            ("users.write", "Write users"),
            ("markets.read", "Read markets"),
            ("markets.write", "Write markets"),
            ("strategies.read", "Read strategies"),
            ("strategies.write", "Write strategies"),
            ("orders.read", "Read orders"),
            ("audit.read", "Read audit"),
        ]:
            insert_if_missing(cur, "permissions", "code", code, {"id": str(uuid.uuid4()), "code": code, "name": name})
        admin_email = "admin@example.com"
        insert_if_missing(cur, "users", "email", admin_email, {
            "id": str(uuid.uuid4()), "name": "Admin User", "email": admin_email,
            "password_hash": pwd.hash("admin123"), "status": "active", "mfa_enabled": False,
        })
        cur.execute("SELECT id FROM roles WHERE code = 'super_admin'")
        role_id = cur.fetchone()[0]
        cur.execute("SELECT id FROM users WHERE email = %s", (admin_email,))
        admin_id = cur.fetchone()[0]
        cur.execute("SELECT 1 FROM user_roles WHERE user_id = %s AND role_id = %s", (admin_id, role_id))
        if not cur.fetchone():
            cur.execute("INSERT INTO user_roles (user_id, role_id) VALUES (%s, %s)", (admin_id, role_id))
        insert_if_missing(cur, "markets", "code", "forex", {"id": str(uuid.uuid4()), "code": "forex", "name": "Forex", "asset_class": "forex", "timezone": "UTC", "status": "active"})
        insert_if_missing(cur, "markets", "code", "crypto", {"id": str(uuid.uuid4()), "code": "crypto", "name": "Crypto", "asset_class": "crypto", "timezone": "UTC", "status": "active"})
        cur.execute("SELECT id FROM markets WHERE code='forex'")
        forex_market_id = cur.fetchone()[0]
        cur.execute("SELECT id FROM markets WHERE code='crypto'")
        crypto_market_id = cur.fetchone()[0]
        insert_if_missing(cur, "venues", "code", "oanda-demo", {"id": str(uuid.uuid4()), "market_id": forex_market_id, "code": "oanda-demo", "name": "OANDA Demo", "venue_type": "broker", "status": "active"})
        insert_if_missing(cur, "venues", "code", "binance-testnet", {"id": str(uuid.uuid4()), "market_id": crypto_market_id, "code": "binance-testnet", "name": "Binance Testnet", "venue_type": "exchange", "status": "active"})
        cur.execute("SELECT id FROM venues WHERE code='oanda-demo'")
        oanda_venue_id = cur.fetchone()[0]
        for symbol, base_asset, quote_asset, tick, lot, pp, qp in [
            ("EURUSD", "EUR", "USD", "0.0001", "1000", 5, 2),
            ("GBPUSD", "GBP", "USD", "0.0001", "1000", 5, 2),
            ("USDJPY", "USD", "JPY", "0.01", "1000", 3, 2),
            ("XAUUSD", "XAU", "USD", "0.01", "1", 2, 2),
        ]:
            insert_if_missing(cur, "instruments", "canonical_symbol", symbol, {
                "id": str(uuid.uuid4()), "venue_id": oanda_venue_id, "canonical_symbol": symbol, "external_symbol": symbol,
                "asset_class": "forex", "base_asset": base_asset, "quote_asset": quote_asset,
                "tick_size": tick, "lot_size": lot, "price_precision": pp, "quantity_precision": qp,
                "contract_multiplier": None, "status": "active",
            })
        insert_if_missing(cur, "strategies", "code", "fx_ma_cross", {"id": str(uuid.uuid4()), "code": "fx_ma_cross", "name": "FX Moving Average Cross", "type": "trend_following", "owner_user_id": admin_id, "description": "Demo strategy", "status": "draft"})
        insert_if_missing(cur, "strategies", "code", "fx_mean_rev", {"id": str(uuid.uuid4()), "code": "fx_mean_rev", "name": "FX Mean Reversion", "type": "mean_reversion", "owner_user_id": admin_id, "description": "Demo strategy", "status": "draft"})
print("Seed complete.")
EOF

cat > scripts/migrate/run_all.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
for f in sql/001_core_identity.sql sql/002_markets_instruments.sql sql/003_strategies.sql sql/004_orders_risk.sql sql/005_positions_audit.sql; do
  echo "Applying $f"
  PGPASSWORD=docker-compose exec -T postgres psql -h localhost -U postgres -d trading_platform -f "$f"
done
EOF
chmod +x scripts/migrate/run_all.sh

cat > scripts/seed/run_all.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
python seeds/seed_core.py
EOF
chmod +x scripts/seed/run_all.sh

cat > scripts/smoke/platform_smoke.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
curl -s http://localhost:8001/health/live >/dev/null
curl -s http://localhost:8002/health/live >/dev/null
curl -s http://localhost:8003/health/live >/dev/null
curl -s http://localhost:8004/health/live >/dev/null
curl -s http://localhost:8005/health/live >/dev/null
curl -s http://localhost:8006/health/live >/dev/null
curl -s http://localhost:8007/health/live >/dev/null
curl -s http://localhost:8008/health/live >/dev/null
curl -s http://localhost:8009/health/live >/dev/null
INSTRUMENT_ID=$(PGPASSWORD=docker-compose exec -T postgres psql -h localhost -U postgres -d trading_platform -t -A -c "SELECT id FROM instruments WHERE canonical_symbol='EURUSD' LIMIT 1;")
VENUE_ID=$(PGPASSWORD=docker-compose exec -T postgres psql -h localhost -U postgres -d trading_platform -t -A -c "SELECT id FROM venues WHERE code='oanda-demo' LIMIT 1;")
curl -s -X POST http://localhost:8005/api/orders/submit -H "Content-Type: application/json" -d "{\"instrument_id\":\"$INSTRUMENT_ID\",\"side\":\"buy\",\"order_type\":\"market\",\"quantity\":\"1000\",\"tif\":\"IOC\",\"venue_id\":\"$VENUE_ID\",\"execution_price\":\"1.0850\"}"
echo
curl -s http://localhost:8008/api/positions
echo
curl -s http://localhost:8009/api/audit
echo
EOF
chmod +x scripts/smoke/platform_smoke.sh

create_pyproject() {
  local svc="$1"
  cat > "apps/$svc/pyproject.toml" <<EOF
[project]
name = "$svc"
version = "0.1.0"
requires-python = ">=3.12"
EOF
}

create_dockerfile() {
  local svc="$1"
  cat > "apps/$svc/Dockerfile" <<EOF
FROM python:3.12-slim
WORKDIR /workspace
COPY packages /workspace/packages
COPY apps/$svc /workspace/apps/$svc
COPY sql /workspace/sql
COPY seeds /workspace/seeds
COPY scripts /workspace/scripts
RUN pip install --no-cache-dir fastapi uvicorn sqlalchemy psycopg[binary] pydantic pydantic-settings passlib[bcrypt] email-validator httpx pyjwt
ENV PYTHONPATH=/workspace/packages:/workspace/apps/$svc
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF
}

create_py_service_common() {
  local svc="$1"
  create_pyproject "$svc"
  create_dockerfile "$svc"
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

create_py_service_common identity-service
create_py_service_common market-registry-service
create_py_service_common instrument-master-service
create_py_service_common strategy-service
create_py_service_common audit-service
create_py_service_common position-service
create_py_service_common risk-service
create_py_service_common execution-service
create_py_service_common order-service
create_py_service_common broker-adapter-simulator

cat > apps/identity-service/app/config.py <<'EOF'
from shared_config.settings import Settings
settings = Settings(app_name="identity-service", port=8000)
EOF
cat > apps/identity-service/app/db/models.py <<'EOF'
from sqlalchemy import String, Boolean, DateTime, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base

class User(Base):
    __tablename__ = "users"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String, nullable=False)
    status: Mapped[str] = mapped_column(String(50), nullable=False, default="active")
    mfa_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
EOF
cat > apps/identity-service/app/api/routes/auth.py <<'EOF'
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, EmailStr
from passlib.context import CryptContext
from sqlalchemy.orm import Session
from app.db.models import User
from app.db.session import get_db
from app.config import settings
from shared_auth.jwt_tools import create_access_token

router = APIRouter()
pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

@router.post("/login")
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == payload.email).first()
    if not user or not pwd.verify(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    user_data = {"id": user.id, "email": user.email, "roles": ["super_admin"], "permissions": ["users.read", "markets.read", "strategies.read", "orders.read", "audit.read"]}
    token = create_access_token(settings.jwt_secret, settings.jwt_algorithm, user_data)
    return {"access_token": token, "token_type": "bearer", "user": {"id": user.id, "name": user.name, "email": user.email, "status": user.status}, "roles": user_data["roles"], "permissions": user_data["permissions"]}
EOF
cat > apps/identity-service/app/main.py <<'EOF'
from fastapi import FastAPI
from app.api.routes.auth import router as auth_router
app = FastAPI(title="identity-service", version="0.1.0")
app.include_router(auth_router, prefix="/api/auth", tags=["auth"])
@app.get("/health/live")
def health_live(): return {"status": "ok", "service": "identity-service"}
@app.get("/health/ready")
def health_ready(): return {"status": "ready", "service": "identity-service"}
EOF

cat > apps/market-registry-service/app/config.py <<'EOF'
from shared_config.settings import Settings
settings = Settings(app_name="market-registry-service", port=8000)
EOF
cat > apps/market-registry-service/app/db/models.py <<'EOF'
from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base

class Market(Base):
    __tablename__ = "markets"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    code: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    asset_class: Mapped[str] = mapped_column(String(50), nullable=False)
    timezone: Mapped[str] = mapped_column(String(100), nullable=False)
    status: Mapped[str] = mapped_column(String(50), nullable=False, default="active")
EOF
cat > apps/market-registry-service/app/api/routes/markets.py <<'EOF'
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import Market
router = APIRouter()
@router.get("/")
def list_markets(db: Session = Depends(get_db)):
    rows = db.query(Market).order_by(Market.code.asc()).all()
    return [{"id": x.id, "code": x.code, "name": x.name, "asset_class": x.asset_class, "timezone": x.timezone, "status": x.status} for x in rows]
EOF
cat > apps/market-registry-service/app/main.py <<'EOF'
from fastapi import FastAPI
from app.api.routes.markets import router as markets_router
app = FastAPI(title="market-registry-service", version="0.1.0")
app.include_router(markets_router, prefix="/api/markets", tags=["markets"])
@app.get("/health/live")
def health_live(): return {"status": "ok", "service": "market-registry-service"}
@app.get("/health/ready")
def health_ready(): return {"status": "ready", "service": "market-registry-service"}
EOF

cat > apps/instrument-master-service/app/config.py <<'EOF'
from shared_config.settings import Settings
settings = Settings(app_name="instrument-master-service", port=8000)
EOF
cat > apps/instrument-master-service/app/db/models.py <<'EOF'
from sqlalchemy import String, Numeric, Integer
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base

class Instrument(Base):
    __tablename__ = "instruments"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    venue_id: Mapped[str] = mapped_column(String, nullable=False)
    canonical_symbol: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    external_symbol: Mapped[str] = mapped_column(String(100), nullable=True)
    asset_class: Mapped[str] = mapped_column(String(50), nullable=False)
    base_asset: Mapped[str] = mapped_column(String(50), nullable=True)
    quote_asset: Mapped[str] = mapped_column(String(50), nullable=True)
    tick_size: Mapped[float] = mapped_column(Numeric(24, 10), nullable=False)
    lot_size: Mapped[float] = mapped_column(Numeric(24, 10), nullable=False)
    price_precision: Mapped[int] = mapped_column(Integer, nullable=False)
    quantity_precision: Mapped[int] = mapped_column(Integer, nullable=False)
    contract_multiplier: Mapped[float] = mapped_column(Numeric(24, 10), nullable=True)
    status: Mapped[str] = mapped_column(String(50), nullable=False, default="active")
EOF
cat > apps/instrument-master-service/app/api/routes/instruments.py <<'EOF'
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import Instrument
router = APIRouter()
@router.get("/")
def list_instruments(db: Session = Depends(get_db)):
    rows = db.query(Instrument).order_by(Instrument.canonical_symbol.asc()).all()
    return [{"id": x.id, "canonical_symbol": x.canonical_symbol, "external_symbol": x.external_symbol, "asset_class": x.asset_class, "base_asset": x.base_asset, "quote_asset": x.quote_asset, "tick_size": str(x.tick_size), "lot_size": str(x.lot_size), "price_precision": x.price_precision, "quantity_precision": x.quantity_precision, "status": x.status} for x in rows]
EOF
cat > apps/instrument-master-service/app/main.py <<'EOF'
from fastapi import FastAPI
from app.api.routes.instruments import router as instruments_router
app = FastAPI(title="instrument-master-service", version="0.1.0")
app.include_router(instruments_router, prefix="/api/instruments", tags=["instruments"])
@app.get("/health/live")
def health_live(): return {"status": "ok", "service": "instrument-master-service"}
@app.get("/health/ready")
def health_ready(): return {"status": "ready", "service": "instrument-master-service"}
EOF

cat > apps/strategy-service/app/config.py <<'EOF'
from shared_config.settings import Settings
settings = Settings(app_name="strategy-service", port=8000)
EOF
cat > apps/strategy-service/app/db/models.py <<'EOF'
from sqlalchemy import String, Text, DateTime, func
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
EOF
cat > apps/strategy-service/app/api/routes/strategies.py <<'EOF'
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import Strategy
router = APIRouter()
@router.get("/")
def list_strategies(db: Session = Depends(get_db)):
    rows = db.query(Strategy).order_by(Strategy.code.asc()).all()
    return [{"id": x.id, "code": x.code, "name": x.name, "type": x.type, "owner_user_id": x.owner_user_id, "description": x.description, "status": x.status} for x in rows]
EOF
cat > apps/strategy-service/app/main.py <<'EOF'
from fastapi import FastAPI
from app.api.routes.strategies import router as strategies_router
app = FastAPI(title="strategy-service", version="0.1.0")
app.include_router(strategies_router, prefix="/api/strategies", tags=["strategies"])
@app.get("/health/live")
def health_live(): return {"status": "ok", "service": "strategy-service"}
@app.get("/health/ready")
def health_ready(): return {"status": "ready", "service": "strategy-service"}
EOF

cat > apps/audit-service/app/config.py <<'EOF'
from shared_config.settings import Settings
settings = Settings(app_name="audit-service", port=8000)
EOF
cat > apps/audit-service/app/db/models.py <<'EOF'
from sqlalchemy import String, DateTime, JSON, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base

class AuditEventModel(Base):
    __tablename__ = "audit_events"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    actor_type: Mapped[str] = mapped_column(String(50), nullable=False)
    actor_id: Mapped[str] = mapped_column(String, nullable=True)
    event_type: Mapped[str] = mapped_column(String(100), nullable=False)
    resource_type: Mapped[str] = mapped_column(String(100), nullable=False)
    resource_id: Mapped[str] = mapped_column(String, nullable=True)
    before_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    after_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
EOF
cat > apps/audit-service/app/api/routes/audit.py <<'EOF'
import uuid
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import AuditEventModel
router = APIRouter()
class AuditCreateRequest(BaseModel):
    actor_type: str
    actor_id: str | None = None
    event_type: str
    resource_type: str
    resource_id: str | None = None
    before_json: dict | None = None
    after_json: dict | None = None
@router.get("/")
def list_audit(db: Session = Depends(get_db)):
    rows = db.query(AuditEventModel).order_by(AuditEventModel.created_at.desc()).limit(200).all()
    return [{"id": x.id, "actor_type": x.actor_type, "actor_id": x.actor_id, "event_type": x.event_type, "resource_type": x.resource_type, "resource_id": x.resource_id, "created_at": x.created_at} for x in rows]
@router.post("/")
def create_audit(payload: AuditCreateRequest, db: Session = Depends(get_db)):
    row = AuditEventModel(id=str(uuid.uuid4()), **payload.model_dump())
    db.add(row)
    db.commit()
    db.refresh(row)
    return {"id": row.id}
EOF
cat > apps/audit-service/app/main.py <<'EOF'
from fastapi import FastAPI
from app.api.routes.audit import router as audit_router
app = FastAPI(title="audit-service", version="0.1.0")
app.include_router(audit_router, prefix="/api/audit", tags=["audit"])
@app.get("/health/live")
def health_live(): return {"status": "ok", "service": "audit-service"}
@app.get("/health/ready")
def health_ready(): return {"status": "ready", "service": "audit-service"}
EOF

cat > apps/position-service/app/config.py <<'EOF'
from shared_config.settings import Settings
settings = Settings(app_name="position-service", port=8000)
EOF
cat > apps/position-service/app/db/models.py <<'EOF'
from sqlalchemy import String, Numeric, DateTime, func
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
EOF
cat > apps/position-service/app/domain/position_math.py <<'EOF'
from decimal import Decimal


def apply_fill(position: dict, side: str, fill_qty: Decimal, fill_price: Decimal) -> dict:
    current_qty = Decimal(str(position.get("net_quantity", "0")))
    avg_price = Decimal(str(position.get("avg_price", "0")))
    signed_qty = fill_qty if side == "buy" else -fill_qty
    new_qty = current_qty + signed_qty
    same_direction = current_qty == 0 or (current_qty > 0 and signed_qty > 0) or (current_qty < 0 and signed_qty < 0)
    if same_direction:
        total_cost = (current_qty * avg_price) + (signed_qty * fill_price)
        new_avg = total_cost / new_qty if new_qty != 0 else Decimal("0")
    else:
        new_avg = avg_price if new_qty != 0 else Decimal("0")
    return {"net_quantity": new_qty, "avg_price": new_avg}
EOF
cat > apps/position-service/app/api/routes/positions.py <<'EOF'
import uuid
from decimal import Decimal
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import PositionModel
from app.domain.position_math import apply_fill
router = APIRouter()
class ApplyFillRequest(BaseModel):
    account_id: str | None = None
    instrument_id: str
    side: str
    fill_quantity: Decimal
    fill_price: Decimal
@router.get("/")
def list_positions(db: Session = Depends(get_db)):
    rows = db.query(PositionModel).order_by(PositionModel.instrument_id.asc()).all()
    return [{"id": x.id, "account_id": x.account_id, "instrument_id": x.instrument_id, "net_quantity": str(x.net_quantity), "avg_price": str(x.avg_price), "market_value": str(x.market_value), "unrealized_pnl": str(x.unrealized_pnl), "realized_pnl": str(x.realized_pnl)} for x in rows]
@router.post("/apply-fill")
def update_position(payload: ApplyFillRequest, db: Session = Depends(get_db)):
    row = db.query(PositionModel).filter(PositionModel.account_id == payload.account_id).filter(PositionModel.instrument_id == payload.instrument_id).first()
    if not row:
        row = PositionModel(id=str(uuid.uuid4()), account_id=payload.account_id, instrument_id=payload.instrument_id, net_quantity=0, avg_price=0, market_value=0, unrealized_pnl=0, realized_pnl=0)
        db.add(row)
        db.flush()
    updated = apply_fill({"net_quantity": row.net_quantity, "avg_price": row.avg_price}, payload.side, payload.fill_quantity, payload.fill_price)
    row.net_quantity = updated["net_quantity"]
    row.avg_price = updated["avg_price"]
    db.commit()
    db.refresh(row)
    return {"id": row.id, "account_id": row.account_id, "instrument_id": row.instrument_id, "net_quantity": str(row.net_quantity), "avg_price": str(row.avg_price), "market_value": str(row.market_value), "unrealized_pnl": str(row.unrealized_pnl), "realized_pnl": str(row.realized_pnl)}
EOF
cat > apps/position-service/app/main.py <<'EOF'
from fastapi import FastAPI
from app.api.routes.positions import router as positions_router
app = FastAPI(title="position-service", version="0.1.0")
app.include_router(positions_router, prefix="/api/positions", tags=["positions"])
@app.get("/health/live")
def health_live(): return {"status": "ok", "service": "position-service"}
@app.get("/health/ready")
def health_ready(): return {"status": "ready", "service": "position-service"}
EOF

cat > apps/risk-service/app/config.py <<'EOF'
from shared_config.settings import Settings
settings = Settings(app_name="risk-service", port=8000)
EOF
cat > apps/risk-service/app/api/routes/risk.py <<'EOF'
from decimal import Decimal
from fastapi import APIRouter
from pydantic import BaseModel
router = APIRouter()
class RiskEvaluationRequest(BaseModel):
    order_intent_id: str
    quantity: Decimal
    side: str
    instrument_id: str
    account_id: str | None = None

def evaluate_max_position_size(order_quantity: Decimal, max_allowed: Decimal):
    if order_quantity > max_allowed:
        return {"passed": False, "rule_type": "max_position_size", "message": "Order exceeds max position size", "severity": "high"}
    return {"passed": True, "rule_type": "max_position_size", "message": "Passed", "severity": "info"}

@router.post("/evaluate")
def evaluate_order(payload: RiskEvaluationRequest):
    results = [evaluate_max_position_size(payload.quantity, Decimal("100000"))]
    failed = [r for r in results if not r["passed"]]
    return {"order_intent_id": payload.order_intent_id, "decision": "reject" if failed else "pass", "rule_results": results, "next_state": "risk_failed" if failed else "risk_passed"}
EOF
cat > apps/risk-service/app/main.py <<'EOF'
from fastapi import FastAPI
from app.api.routes.risk import router as risk_router
app = FastAPI(title="risk-service", version="0.1.0")
app.include_router(risk_router, prefix="/api/risk", tags=["risk"])
@app.get("/health/live")
def health_live(): return {"status": "ok", "service": "risk-service"}
@app.get("/health/ready")
def health_ready(): return {"status": "ready", "service": "risk-service"}
EOF

cat > apps/execution-service/app/config.py <<'EOF'
from shared_config.settings import Settings
settings = Settings(app_name="execution-service", port=8000)
EOF
cat > apps/execution-service/app/db/models.py <<'EOF'
from sqlalchemy import String, Numeric, DateTime, JSON, func
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
    fill_time: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
    raw_payload: Mapped[dict] = mapped_column(JSON, nullable=True)
EOF
cat > apps/execution-service/app/api/routes/execution.py <<'EOF'
import uuid
from decimal import Decimal
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import BrokerOrderModel, FillModel
router = APIRouter()
class SimulateExecutionRequest(BaseModel):
    order_intent_id: str
    venue_id: str
    instrument_id: str
    quantity: Decimal
    price: Decimal
    fee_amount: Decimal = Decimal("0.0")
    fee_currency: str = "USD"
@router.post("/simulate")
def simulate_execution(payload: SimulateExecutionRequest, db: Session = Depends(get_db)):
    broker_order = BrokerOrderModel(id=str(uuid.uuid4()), order_intent_id=payload.order_intent_id, venue_id=payload.venue_id, external_order_id=f"sim-{uuid.uuid4()}", broker_status="filled", raw_request=payload.model_dump(mode="json"), raw_response={"status": "filled"})
    db.add(broker_order)
    db.flush()
    fill = FillModel(id=str(uuid.uuid4()), broker_order_id=broker_order.id, instrument_id=payload.instrument_id, fill_price=payload.price, fill_quantity=payload.quantity, fee_amount=payload.fee_amount, fee_currency=payload.fee_currency, raw_payload={"simulation": True})
    db.add(fill)
    db.commit()
    return {"broker_order_id": broker_order.id, "external_order_id": broker_order.external_order_id, "fill_id": fill.id, "status": "filled", "fill": {"instrument_id": payload.instrument_id, "quantity": str(payload.quantity), "price": str(payload.price), "fee_amount": str(payload.fee_amount), "fee_currency": payload.fee_currency}}
EOF
cat > apps/execution-service/app/main.py <<'EOF'
from fastapi import FastAPI
from app.api.routes.execution import router as execution_router
app = FastAPI(title="execution-service", version="0.1.0")
app.include_router(execution_router, prefix="/api/execution", tags=["execution"])
@app.get("/health/live")
def health_live(): return {"status": "ok", "service": "execution-service"}
@app.get("/health/ready")
def health_ready(): return {"status": "ready", "service": "execution-service"}
EOF

cat > apps/order-service/app/config.py <<'EOF'
from shared_config.settings import Settings
class OrderServiceSettings(Settings):
    risk_service_url: str = "http://risk-service:8000"
    execution_service_url: str = "http://execution-service:8000"
    position_service_url: str = "http://position-service:8000"
    audit_service_url: str = "http://audit-service:8000"
settings = OrderServiceSettings(app_name="order-service", port=8000)
EOF
cat > apps/order-service/app/db/models.py <<'EOF'
from sqlalchemy import String, Numeric, DateTime, func
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
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
EOF
cat > apps/order-service/app/domain/state_machine.py <<'EOF'
from shared_domain.order_state import can_transition

def transition_order(row, next_state: str):
    current_state = row.intent_status
    if not can_transition(current_state, next_state):
        raise ValueError(f"Illegal order state transition: {current_state} -> {next_state}")
    row.intent_status = next_state
    return row
EOF
cat > apps/order-service/app/integrations/clients.py <<'EOF'
import httpx
from app.config import settings

async def call_risk_service(payload: dict) -> dict:
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(f"{settings.risk_service_url}/api/risk/evaluate", json=payload)
        response.raise_for_status()
        return response.json()

async def call_execution_service(payload: dict) -> dict:
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(f"{settings.execution_service_url}/api/execution/simulate", json=payload)
        response.raise_for_status()
        return response.json()

async def call_position_service(payload: dict) -> dict:
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(f"{settings.position_service_url}/api/positions/apply-fill", json=payload)
        response.raise_for_status()
        return response.json()

async def call_audit_service(payload: dict) -> dict:
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(f"{settings.audit_service_url}/api/audit", json=payload)
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
EOF
cat > apps/order-service/app/api/routes/orders.py <<'EOF'
import uuid
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import OrderIntentModel
from app.api.schemas import OrderIntentCreate, OrderSubmitResponse
from app.domain.state_machine import transition_order
from app.integrations.clients import call_risk_service, call_execution_service, call_position_service, call_audit_service
router = APIRouter()
@router.get("/")
def list_orders(db: Session = Depends(get_db)):
    rows = db.query(OrderIntentModel).order_by(OrderIntentModel.created_at.desc()).all()
    return [{"id": x.id, "instrument_id": x.instrument_id, "side": x.side, "order_type": x.order_type, "quantity": str(x.quantity), "intent_status": x.intent_status, "created_at": x.created_at} for x in rows]
@router.post("/submit", response_model=OrderSubmitResponse)
async def submit_order(payload: OrderIntentCreate, db: Session = Depends(get_db)):
    row = OrderIntentModel(id=str(uuid.uuid4()), strategy_deployment_id=payload.strategy_deployment_id, account_id=payload.account_id, instrument_id=payload.instrument_id, signal_id=payload.signal_id, side=payload.side, order_type=payload.order_type, quantity=payload.quantity, limit_price=payload.limit_price, stop_price=payload.stop_price, tif=payload.tif, intent_status="draft")
    db.add(row)
    db.commit()
    db.refresh(row)
    await call_audit_service({"actor_type": "system", "actor_id": None, "event_type": "order_intent.created", "resource_type": "order_intent", "resource_id": row.id, "after_json": {"instrument_id": row.instrument_id, "side": row.side, "quantity": str(row.quantity), "status": row.intent_status}})
    try:
        transition_order(row, "risk_pending")
        db.commit()
        db.refresh(row)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    risk_result = await call_risk_service({"order_intent_id": row.id, "quantity": str(row.quantity), "side": row.side, "instrument_id": row.instrument_id, "account_id": row.account_id})
    if risk_result["decision"] == "reject":
        transition_order(row, "risk_failed")
        db.commit()
        db.refresh(row)
        await call_audit_service({"actor_type": "system", "actor_id": None, "event_type": "order_intent.risk_failed", "resource_type": "order_intent", "resource_id": row.id, "after_json": {"status": row.intent_status, "risk_result": risk_result}})
        return OrderSubmitResponse(order_id=row.id, final_status=row.intent_status, risk_decision="reject", execution=None, position=None)
    try:
        transition_order(row, "risk_passed")
        db.commit()
        db.refresh(row)
        transition_order(row, "submitted")
        db.commit()
        db.refresh(row)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    execution_result = await call_execution_service({"order_intent_id": row.id, "venue_id": payload.venue_id, "instrument_id": row.instrument_id, "quantity": str(row.quantity), "price": str(payload.execution_price), "fee_amount": "0.0", "fee_currency": "USD"})
    row.intent_status = "filled"
    db.commit()
    db.refresh(row)
    position_result = await call_position_service({"account_id": row.account_id, "instrument_id": row.instrument_id, "side": row.side, "fill_quantity": str(row.quantity), "fill_price": str(payload.execution_price)})
    await call_audit_service({"actor_type": "system", "actor_id": None, "event_type": "order_intent.filled", "resource_type": "order_intent", "resource_id": row.id, "after_json": {"status": row.intent_status, "execution_result": execution_result, "position_result": position_result}})
    return OrderSubmitResponse(order_id=row.id, final_status=row.intent_status, risk_decision="pass", execution=execution_result, position=position_result)
EOF
cat > apps/order-service/app/main.py <<'EOF'
from fastapi import FastAPI
from app.api.routes.orders import router as orders_router
app = FastAPI(title="order-service", version="0.1.0")
app.include_router(orders_router, prefix="/api/orders", tags=["orders"])
@app.get("/health/live")
def health_live(): return {"status": "ok", "service": "order-service"}
@app.get("/health/ready")
def health_ready(): return {"status": "ready", "service": "order-service"}
EOF

cat > apps/broker-adapter-simulator/app/main.py <<'EOF'
from fastapi import FastAPI
app = FastAPI(title="broker-adapter-simulator", version="0.1.0")
@app.get("/health/live")
def health_live(): return {"status": "ok", "service": "broker-adapter-simulator"}
@app.get("/health/ready")
def health_ready(): return {"status": "ready", "service": "broker-adapter-simulator"}
@app.get("/api/simulator/status")
def simulator_status(): return {"mode": "paper", "status": "healthy"}
EOF

cat > apps/web-admin/package.json <<'EOF'
{
  "name": "web-admin",
  "private": true,
  "version": "0.1.0",
  "scripts": {
    "dev": "vite --host 0.0.0.0 --port 3000",
    "build": "vite build"
  },
  "dependencies": {
    "axios": "^1.8.0",
    "pinia": "^3.0.1",
    "vue": "^3.5.13",
    "vue-router": "^4.5.0"
  },
  "devDependencies": {
    "@vitejs/plugin-vue": "^5.2.1",
    "typescript": "^5.7.3",
    "vite": "^6.1.0"
  }
}
EOF
cat > apps/web-admin/vite.config.ts <<'EOF'
import { defineConfig } from "vite"
import vue from "@vitejs/plugin-vue"
export default defineConfig({ plugins: [vue()] })
EOF
cat > apps/web-admin/src/App.vue <<'EOF'
<template>
  <router-view />
</template>
EOF
cat > apps/web-admin/src/main.ts <<'EOF'
import { createApp } from "vue"
import { createPinia } from "pinia"
import router from "./router"
import App from "./App.vue"
createApp(App).use(createPinia()).use(router).mount("#app")
EOF
cat > apps/web-admin/src/router/index.ts <<'EOF'
import { createRouter, createWebHistory } from "vue-router"
import LoginView from "../views/LoginView.vue"
import AdminLayout from "../views/AdminLayout.vue"
import MarketsView from "../views/MarketsView.vue"
import InstrumentsView from "../views/InstrumentsView.vue"
import StrategiesView from "../views/StrategiesView.vue"
import AuditView from "../views/AuditView.vue"
export default createRouter({
  history: createWebHistory(),
  routes: [
    { path: "/login", component: LoginView },
    { path: "/", component: AdminLayout, children: [
      { path: "", redirect: "/markets" },
      { path: "markets", component: MarketsView },
      { path: "instruments", component: InstrumentsView },
      { path: "strategies", component: StrategiesView },
      { path: "audit", component: AuditView }
    ] }
  ]
})
EOF
cat > apps/web-admin/src/views/LoginView.vue <<'EOF'
<template>
  <div style="max-width: 360px; margin: 60px auto;">
    <h1>Admin Login</h1>
    <form @submit.prevent="submit">
      <div><label>Email</label><input v-model="email" type="email" /></div>
      <div style="margin-top: 12px;"><label>Password</label><input v-model="password" type="password" /></div>
      <button style="margin-top: 16px;" type="submit">Login</button>
    </form>
    <p v-if="error" style="color: red;">{{ error }}</p>
  </div>
</template>
<script setup lang="ts">
import axios from "axios"
import { ref } from "vue"
import { useRouter } from "vue-router"
const router = useRouter()
const email = ref("admin@example.com")
const password = ref("admin123")
const error = ref("")
async function submit() {
  try {
    const { data } = await axios.post("http://localhost:8001/api/auth/login", { email: email.value, password: password.value })
    localStorage.setItem("access_token", data.access_token)
    router.push("/markets")
  } catch {
    error.value = "Login failed"
  }
}
</script>
EOF
cat > apps/web-admin/src/views/AdminLayout.vue <<'EOF'
<template>
  <div style="display: grid; grid-template-columns: 220px 1fr; min-height: 100vh;">
    <aside style="padding: 16px; border-right: 1px solid #ddd;">
      <h3>Admin</h3>
      <nav style="display: grid; gap: 8px;">
        <router-link to="/markets">Markets</router-link>
        <router-link to="/instruments">Instruments</router-link>
        <router-link to="/strategies">Strategies</router-link>
        <router-link to="/audit">Audit</router-link>
      </nav>
    </aside>
    <main style="padding: 16px;"><router-view /></main>
  </div>
</template>
EOF
cat > apps/web-admin/src/views/MarketsView.vue <<'EOF'
<template><div><h1>Markets</h1><table border="1" cellpadding="8"><thead><tr><th>Code</th><th>Name</th><th>Asset Class</th><th>Timezone</th><th>Status</th></tr></thead><tbody><tr v-for="item in rows" :key="item.id"><td>{{ item.code }}</td><td>{{ item.name }}</td><td>{{ item.asset_class }}</td><td>{{ item.timezone }}</td><td>{{ item.status }}</td></tr></tbody></table></div></template>
<script setup lang="ts">
import axios from "axios"
import { onMounted, ref } from "vue"
const rows = ref<any[]>([])
onMounted(async () => { const { data } = await axios.get("http://localhost:8002/api/markets"); rows.value = data })
</script>
EOF
cat > apps/web-admin/src/views/InstrumentsView.vue <<'EOF'
<template><div><h1>Instruments</h1><table border="1" cellpadding="8"><thead><tr><th>Symbol</th><th>Asset Class</th><th>Base</th><th>Quote</th><th>Status</th></tr></thead><tbody><tr v-for="item in rows" :key="item.id"><td>{{ item.canonical_symbol }}</td><td>{{ item.asset_class }}</td><td>{{ item.base_asset }}</td><td>{{ item.quote_asset }}</td><td>{{ item.status }}</td></tr></tbody></table></div></template>
<script setup lang="ts">
import axios from "axios"
import { onMounted, ref } from "vue"
const rows = ref<any[]>([])
onMounted(async () => { const { data } = await axios.get("http://localhost:8003/api/instruments"); rows.value = data })
</script>
EOF
cat > apps/web-admin/src/views/StrategiesView.vue <<'EOF'
<template><div><h1>Strategies</h1><table border="1" cellpadding="8"><thead><tr><th>Code</th><th>Name</th><th>Type</th><th>Status</th></tr></thead><tbody><tr v-for="item in rows" :key="item.id"><td>{{ item.code }}</td><td>{{ item.name }}</td><td>{{ item.type }}</td><td>{{ item.status }}</td></tr></tbody></table></div></template>
<script setup lang="ts">
import axios from "axios"
import { onMounted, ref } from "vue"
const rows = ref<any[]>([])
onMounted(async () => { const { data } = await axios.get("http://localhost:8004/api/strategies"); rows.value = data })
</script>
EOF
cat > apps/web-admin/src/views/AuditView.vue <<'EOF'
<template><div><h1>Audit Events</h1><table border="1" cellpadding="8"><thead><tr><th>Time</th><th>Event</th><th>Resource Type</th><th>Resource ID</th></tr></thead><tbody><tr v-for="item in rows" :key="item.id"><td>{{ item.created_at }}</td><td>{{ item.event_type }}</td><td>{{ item.resource_type }}</td><td>{{ item.resource_id }}</td></tr></tbody></table></div></template>
<script setup lang="ts">
import axios from "axios"
import { onMounted, ref } from "vue"
const rows = ref<any[]>([])
onMounted(async () => { const { data } = await axios.get("http://localhost:8009/api/audit"); rows.value = data })
</script>
EOF

cat > apps/web-ops/package.json <<'EOF'
{
  "name": "web-ops",
  "private": true,
  "version": "0.1.0",
  "scripts": {
    "dev": "vite --host 0.0.0.0 --port 3000",
    "build": "vite build"
  },
  "dependencies": {
    "axios": "^1.8.0",
    "pinia": "^3.0.1",
    "vue": "^3.5.13",
    "vue-router": "^4.5.0"
  },
  "devDependencies": {
    "@vitejs/plugin-vue": "^5.2.1",
    "typescript": "^5.7.3",
    "vite": "^6.1.0"
  }
}
EOF
cat > apps/web-ops/vite.config.ts <<'EOF'
import { defineConfig } from "vite"
import vue from "@vitejs/plugin-vue"
export default defineConfig({ plugins: [vue()] })
EOF
cat > apps/web-ops/src/App.vue <<'EOF'
<template>
  <router-view />
</template>
EOF
cat > apps/web-ops/src/main.ts <<'EOF'
import { createApp } from "vue"
import { createPinia } from "pinia"
import router from "./router"
import App from "./App.vue"
createApp(App).use(createPinia()).use(router).mount("#app")
EOF
cat > apps/web-ops/src/router/index.ts <<'EOF'
import { createRouter, createWebHistory } from "vue-router"
import OpsLayout from "../views/OpsLayout.vue"
import OrdersView from "../views/OrdersView.vue"
import PositionsView from "../views/PositionsView.vue"
export default createRouter({
  history: createWebHistory(),
  routes: [
    { path: "/", component: OpsLayout, children: [
      { path: "", redirect: "/orders" },
      { path: "orders", component: OrdersView },
      { path: "positions", component: PositionsView }
    ] }
  ]
})
EOF
cat > apps/web-ops/src/views/OpsLayout.vue <<'EOF'
<template>
  <div style="display: grid; grid-template-columns: 220px 1fr; min-height: 100vh;">
    <aside style="padding: 16px; border-right: 1px solid #ddd;"><h3>Ops</h3><nav style="display: grid; gap: 8px;"><router-link to="/orders">Orders</router-link><router-link to="/positions">Positions</router-link></nav></aside>
    <main style="padding: 16px;"><router-view /></main>
  </div>
</template>
EOF
cat > apps/web-ops/src/views/OrdersView.vue <<'EOF'
<template>
  <div>
    <h1>Orders</h1>
    <form @submit.prevent="submitOrder" style="margin-bottom: 24px;">
      <div><label>Instrument ID</label><input v-model="form.instrument_id" style="width: 420px;" /></div>
      <div style="margin-top: 8px;"><label>Venue ID</label><input v-model="form.venue_id" style="width: 420px;" /></div>
      <div style="margin-top: 8px;"><label>Side</label><select v-model="form.side"><option value="buy">buy</option><option value="sell">sell</option></select></div>
      <div style="margin-top: 8px;"><label>Quantity</label><input v-model="form.quantity" /></div>
      <div style="margin-top: 8px;"><label>Execution Price</label><input v-model="form.execution_price" /></div>
      <button type="submit" style="margin-top: 12px;">Submit Integrated Order</button>
    </form>
    <pre v-if="lastResponse">{{ lastResponse }}</pre>
    <table border="1" cellpadding="8"><thead><tr><th>ID</th><th>Instrument</th><th>Side</th><th>Type</th><th>Quantity</th><th>Status</th></tr></thead><tbody><tr v-for="item in rows" :key="item.id"><td>{{ item.id }}</td><td>{{ item.instrument_id }}</td><td>{{ item.side }}</td><td>{{ item.order_type }}</td><td>{{ item.quantity }}</td><td>{{ item.intent_status }}</td></tr></tbody></table>
  </div>
</template>
<script setup lang="ts">
import axios from "axios"
import { onMounted, ref } from "vue"
const rows = ref<any[]>([])
const lastResponse = ref("")
const form = ref({ instrument_id: "", venue_id: "", side: "buy", quantity: "1000", execution_price: "1.0850" })
async function loadOrders() {
  const { data } = await axios.get("http://localhost:8005/api/orders")
  rows.value = data
}
async function submitOrder() {
  const { data } = await axios.post("http://localhost:8005/api/orders/submit", { instrument_id: form.value.instrument_id, side: form.value.side, order_type: "market", quantity: form.value.quantity, tif: "IOC", venue_id: form.value.venue_id, execution_price: form.value.execution_price })
  lastResponse.value = JSON.stringify(data, null, 2)
  await loadOrders()
}
onMounted(loadOrders)
</script>
EOF
cat > apps/web-ops/src/views/PositionsView.vue <<'EOF'
<template><div><h1>Positions</h1><table border="1" cellpadding="8"><thead><tr><th>Instrument</th><th>Net Quantity</th><th>Average Price</th></tr></thead><tbody><tr v-for="item in rows" :key="item.id"><td>{{ item.instrument_id }}</td><td>{{ item.net_quantity }}</td><td>{{ item.avg_price }}</td></tr></tbody></table></div></template>
<script setup lang="ts">
import axios from "axios"
import { onMounted, ref } from "vue"
const rows = ref<any[]>([])
onMounted(async () => { const { data } = await axios.get("http://localhost:8008/api/positions"); rows.value = data })
</script>
EOF

echo "Bootstrap complete at $(pwd)"
echo "Next: make up && make migrate && make seed && make smoke"
