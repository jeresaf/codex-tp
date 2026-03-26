# 1. First working target

This scaffold is designed to make this flow work first:
1. login
2. list markets
3. list instruments
4. list strategies
5. create order intent
6. evaluate risk
7. simulate execution
8. write fill
9. update position
10. record audit event
11. show orders and positions in ops UI

# 2. Repo tree

trading-platform/
├─ apps/
│ ├─ identity-service/
│ ├─ market-registry-service/
│ ├─ instrument-master-service/
│ ├─ strategy-service/
│ ├─ order-service/
│ ├─ risk-service/
│ ├─ execution-service/
│ ├─ position-service/
│ ├─ audit-service/
│ ├─ web-admin/
│ └─ web-ops/
├─ packages/
│ ├─ shared-config/
│ ├─ shared-db/
│ ├─ shared-events/
│ ├─ shared-domain/
│ └─ strategy-sdk/
├─ sql/
│ ├─ 001_core_identity.sql
│ ├─ 002_markets_instruments.sql
│ ├─ 003_strategies.sql
│ ├─ 004_orders_risk.sql
│ └─ 005_positions_audit.sql
├─ seeds/
│ └─ seed_core.py
├─ scripts/
│ ├─ migrate.sh
│ ├─ seed.sh
│ └─ smoke.sh
├─ docker-compose.yml
├─ Makefile
└─ README.md

# 3. Shared Python packages

## packages/shared-config/shared_config/settings.py

```Python
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

    redis_url: str = "redis://redis:6379/0"
    kafka_bootstrap_servers: str = "redpanda:9092"

    jwt_secret: str = "dev-secret"
    jwt_algorithm: str = "HS256"

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")
    @property
    def sqlalchemy_url(self) -> str:
        return (
            f"postgresql+psycopg://{self.db_user}:{self.db_password}"
            f"@{self.db_host}:{self.db_port}/{self.db_name}"
        )
```

## packages/shared-db/shared_db/database.py

```Python
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

Base = declarative_base()

def build_engine(url: str):
    return create_engine(url, future=True, pool_pre_ping=True)

def build_session_factory(url: str):
    engine = build_engine(url)
    return sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)
```

## packages/shared-events/shared_events/envelope.py

```Python
from pydantic import BaseModel
from typing import Any

class EventEnvelope(BaseModel):
    event_id: str
    event_type: str
    event_version: int
    source_service: str
    environment: str
    occurred_at: str
    correlation_id: str
    causation_id: str
    actor_type: str
    actor_id: str
    payload: dict[str, Any]
```

## packages/shared-domain/shared_domain/enums.py

```Python
from enum import Enum

class OrderIntentStatus(str, Enum):
    DRAFT = "draft"
    RISK_PENDING = "risk_pending"
    RISK_PASSED = "risk_passed"
    RISK_FAILED = "risk_failed"
    SUBMITTED = "submitted"
    ACKNOWLEDGED = "acknowledged"
    PARTIALLY_FILLED = "partially_filled"
    FILLED = "filled"
    CANCEL_PENDING = "cancel_pending"
    CANCELLED = "cancelled"
    REJECTED = "rejected"
    EXPIRED = "expired"
```

## packages/shared-domain/shared_domain/order_state.py

```Python
ALLOWED_TRANSITIONS = {
    "draft": {"risk_pending"},
    "risk_pending": {"risk_passed", "risk_failed"},
    "risk_passed": {"submitted"},
    "submitted": {"acknowledged", "rejected"},
    "acknowledged": {"partially_filled", "filled", "cancel_pending", "expired"},
    "partially_filled": {"filled", "cancel_pending"},
    "cancel_pending": {"cancelled"},
}

def can_transition(current_state: str, next_state: str) -> bool:
    return next_state in ALLOWED_TRANSITIONS.get(current_state, set())
```

# 4. Standard Python service template
Use this same skeleton in each FastAPI service.

## apps/order-service/app/main.py

```Python
from fastapi import FastAPI
from app.api.routes.orders import router as orders_router

app = FastAPI(title="order-service", version="0.1.0")

app.include_router(orders_router, prefix="/api/orders", tags=["orders"])

@app.get("/health")
def health():
    return {"status": "ok", "service": "order-service"}

@app.get("/ready")
def ready():
    return {"status": "ready", "service": "order-service"}
```

## apps/order-service/app/config.py

```Python
from shared_config.settings import Settings

settings = Settings(app_name="order-service", port=8000)
```

## apps/order-service/app/db/session.py

```Python
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
```

# 5. Identity service starter

## apps/identity-service/app/db/models.py

```Python
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
```

## apps/identity-service/app/api/routes/auth.py

```Python
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session
from passlib.context import CryptContext
from app.db.session import get_db
from app.db.models import User

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
    return {
        "token": "dev-token",
        "user": {
            "id": user.id,
            "name": user.name,
            "email": user.email,
            "status": user.status,
        },
        "permissions": ["users.read", "markets.read", "strategies.read", "orders.read", "audit.read"],
    }
```

## apps/identity-service/app/main.py

```Python
from fastapi import FastAPI
from app.api.routes.auth import router as auth_router

app = FastAPI(title="identity-service", version="0.1.0")
app.include_router(auth_router, prefix="/api/auth", tags=["auth"])

@app.get("/health")
def health():
    return {"status": "ok", "service": "identity-service"}
```

# 6. Market registry service starter

## apps/market-registry-service/app/db/models.py

```Python
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
```

## apps/market-registry-service/app/api/routes/markets.py

```Python
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import Market

router = APIRouter()

@router.get("/")
def list_markets(db: Session = Depends(get_db)):
    items = db.query(Market).order_by(Market.code.asc()).all()
    return [
        {
            "id": x.id,
            "code": x.code,
            "name": x.name,
            "asset_class": x.asset_class,
            "timezone": x.timezone,
            "status": x.status,
        }
        for x in items
    ]
```

# 7. Instrument master service starter

## apps/instrument-master-service/app/db/models.py

```Python
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
```

## apps/instrument-master-service/app/api/routes/instruments.py

```Python
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import Instrument

router = APIRouter()


@router.get("/")
def list_instruments(db: Session = Depends(get_db)):
    items = db.query(Instrument).order_by(Instrument.canonical_symbol.asc()).all()
    return [
        {
            "id": x.id,
            "canonical_symbol": x.canonical_symbol,
            "external_symbol": x.external_symbol,
            "asset_class": x.asset_class,
            "base_asset": x.base_asset,
            "quote_asset": x.quote_asset,
            "tick_size": str(x.tick_size),
            "lot_size": str(x.lot_size),
            "price_precision": x.price_precision,
            "quantity_precision": x.quantity_precision,
            "status": x.status,
        }
        for x in items
    ]
```

# 8. Strategy service starter

## apps/strategy-service/app/db/models.py

```Python
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
```

## apps/strategy-service/app/api/routes/strategies.py

```Python
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import Strategy

router = APIRouter()


@router.get("/")
def list_strategies(db: Session = Depends(get_db)):
    rows = db.query(Strategy).order_by(Strategy.code.asc()).all()
    return [
        {
            "id": x.id,
            "code": x.code,
            "name": x.name,
            "type": x.type,
            "owner_user_id": x.owner_user_id,
            "description": x.description,
            "status": x.status,
        }
        for x in rows
    ]
```

# 9. Order service starter

## apps/order-service/app/db/models.py

```Python
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
```

## apps/order-service/app/api/routes/orders.py

```Python
import uuid
from decimal import Decimal
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import OrderIntentModel

router = APIRouter()


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


@router.get("/")
def list_orders(db: Session = Depends(get_db)):
    rows = db.query(OrderIntentModel).order_by(OrderIntentModel.created_at.desc()).all()
    return [
        {
            "id": x.id,
            "instrument_id": x.instrument_id,
            "side": x.side,
            "order_type": x.order_type,
            "quantity": str(x.quantity),
            "intent_status": x.intent_status,
            "created_at": x.created_at,
        }
        for x in rows
    ]


@router.post("/")
def create_order_intent(payload: OrderIntentCreate, db: Session = Depends(get_db)):
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
    )
    db.add(row)
    db.commit()
    db.refresh(row)

    return {
        "id": row.id,
        "intent_status": row.intent_status,
    }
```

# 10. Risk service starter

## apps/risk-service/app/api/routes/risk.py

```Python
from fastapi import APIRouter
from pydantic import BaseModel
from decimal import Decimal

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
        }
    return {
        "passed": True,
        "rule_type": "max_position_size",
        "message": "Passed",
    }


@router.post("/evaluate")
def evaluate_order(payload: RiskEvaluationRequest):
    results = [
        evaluate_max_position_size(payload.quantity, Decimal("100000"))
    ]
    failed = [r for r in results if not r["passed"]]

    return {
        "decision": "reject" if failed else "pass",
        "rule_results": results,
        "next_state": "risk_failed" if failed else "risk_passed",
        "order_intent_id": payload.order_intent_id,
    }
```

# 11. Execution service starter

## apps/execution-service/app/db/models.py

```Python
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
```

## apps/execution-service/app/api/routes/execution.py

```Python
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
    broker_order = BrokerOrderModel(
        id=str(uuid.uuid4()),
        order_intent_id=payload.order_intent_id,
        venue_id=payload.venue_id,
        external_order_id=f"sim-{uuid.uuid4()}",
        broker_status="filled",
        raw_request=payload.model_dump(mode="json"),
        raw_response={"status": "filled"},
    )
    db.add(broker_order)
    db.flush()

    fill = FillModel(
        id=str(uuid.uuid4()),
        broker_order_id=broker_order.id,
        instrument_id=payload.instrument_id,
        fill_price=payload.price,
        fill_quantity=payload.quantity,
        fee_amount=payload.fee_amount,
        fee_currency=payload.fee_currency,
        raw_payload={"simulation": True},
    )
    db.add(fill)
    db.commit()

    return {
        "broker_order_id": broker_order.id,
        "fill_id": fill.id,
        "status": "filled",
    }
```

# 12. Position service starter

## apps/position-service/app/db/models.py

```Python
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
```

## apps/position-service/app/domain/position_math.py

```Python
from decimal import Decimal


def apply_fill(position: dict, side: str, fill_qty: Decimal, fill_price: Decimal) -> dict:
    current_qty = Decimal(str(position.get("net_quantity", "0")))
    avg_price = Decimal(str(position.get("avg_price", "0")))

    signed_qty = fill_qty if side == "buy" else -fill_qty
    new_qty = current_qty + signed_qty

    same_direction = (
        current_qty == 0
        or (current_qty > 0 and signed_qty > 0)
        or (current_qty < 0 and signed_qty < 0)
    )

    if same_direction:
        total_cost = (current_qty * avg_price) + (signed_qty * fill_price)
        new_avg = total_cost / new_qty if new_qty != 0 else Decimal("0")
    else:
        new_avg = avg_price if new_qty != 0 else Decimal("0")

    return {
        "net_quantity": new_qty,
        "avg_price": new_avg,
    }
```

## apps/position-service/app/api/routes/positions.py

```Python
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
    return [
        {
            "id": x.id,
            "account_id": x.account_id,
            "instrument_id": x.instrument_id,
            "net_quantity": str(x.net_quantity),
            "avg_price": str(x.avg_price),
            "market_value": str(x.market_value),
            "unrealized_pnl": str(x.unrealized_pnl),
            "realized_pnl": str(x.realized_pnl),
        }
        for x in rows
    ]


@router.post("/apply-fill")
def update_position(payload: ApplyFillRequest, db: Session = Depends(get_db)):
    row = (
        db.query(PositionModel)
        .filter(PositionModel.account_id == payload.account_id)
        .filter(PositionModel.instrument_id == payload.instrument_id)
        .first()
    )

    if not row:
        row = PositionModel(
            id=str(uuid.uuid4()),
            account_id=payload.account_id,
            instrument_id=payload.instrument_id,
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
        payload.side,
        payload.fill_quantity,
        payload.fill_price,
    )

    row.net_quantity = updated["net_quantity"]
    row.avg_price = updated["avg_price"]
    db.commit()
    db.refresh(row)

    return {
        "id": row.id,
        "instrument_id": row.instrument_id,
        "net_quantity": str(row.net_quantity),
        "avg_price": str(row.avg_price),
    }
```

# 13. Audit service starter

## apps/audit-service/app/db/models.py

```Python
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
```

## apps/audit-service/app/api/routes/audit.py

```Python
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
    return [
        {
            "id": x.id,
            "actor_type": x.actor_type,
            "actor_id": x.actor_id,
            "event_type": x.event_type,
            "resource_type": x.resource_type,
            "resource_id": x.resource_id,
            "created_at": x.created_at,
        }
        for x in rows
    ]


@router.post("/")
def create_audit(payload: AuditCreateRequest, db: Session = Depends(get_db)):
    row = AuditEventModel(
        id=str(uuid.uuid4()),
        **payload.model_dump(),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return {"id": row.id}
```

# 14. SQL migration files

## sql/001_core_identity.sql

```SQL
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
```

## sql/002_markets_instruments.sql

```SQL
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
```

## sql/003_strategies.sql

```SQL
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
```

## sql/004_orders_risk.sql

```SQL
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
```

## sql/005_positions_audit.sql

```SQL
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
```

# 15. Seed script

## seeds/seed_core.py

```Python
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
    cur.execute(
        f"INSERT INTO {table} ({cols}) VALUES ({placeholders})",
        tuple(data.values()),
    )


conn = psycopg.connect("host=postgres port=5432 dbname=trading_platform user=postgres password=postgres")

with conn:
    with conn.cursor() as cur:
        role_ids = {}
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
            role_id = str(uuid.uuid4())
            insert_if_missing(cur, "roles", "code", code, {
                "id": role_id,
                "code": code,
                "name": name,
            })

        permissions = [
            ("users.read", "Read users"),
            ("users.write", "Write users"),
            ("markets.read", "Read markets"),
            ("markets.write", "Write markets"),
            ("strategies.read", "Read strategies"),
            ("strategies.write", "Write strategies"),
            ("orders.read", "Read orders"),
            ("audit.read", "Read audit"),
            ("risk_policies.write", "Write risk policies"),
        ]
        for code, name in permissions:
            insert_if_missing(cur, "permissions", "code", code, {
                "id": str(uuid.uuid4()),
                "code": code,
                "name": name,
            })

        admin_id = str(uuid.uuid4())
        admin_email = "admin@example.com"
        insert_if_missing(cur, "users", "email", admin_email, {
            "id": admin_id,
            "name": "Admin User",
            "email": admin_email,
            "password_hash": pwd.hash("admin123"),
            "status": "active",
            "mfa_enabled": False,
        })

        cur.execute("SELECT id FROM roles WHERE code = %s", ("super_admin",))
        super_admin_role_id = cur.fetchone()[0]

        cur.execute("SELECT id FROM users WHERE email = %s", (admin_email,))
        actual_admin_id = cur.fetchone()[0]

        cur.execute(
            "SELECT 1 FROM user_roles WHERE user_id = %s AND role_id = %s",
            (actual_admin_id, super_admin_role_id),
        )
        if not cur.fetchone():
            cur.execute(
                "INSERT INTO user_roles (user_id, role_id) VALUES (%s, %s)",
                (actual_admin_id, super_admin_role_id),
            )

        forex_market_id = str(uuid.uuid4())
        crypto_market_id = str(uuid.uuid4())

        insert_if_missing(cur, "markets", "code", "forex", {
            "id": forex_market_id,
            "code": "forex",
            "name": "Forex",
            "asset_class": "forex",
            "timezone": "UTC",
            "status": "active",
        })

        insert_if_missing(cur, "markets", "code", "crypto", {
            "id": crypto_market_id,
            "code": "crypto",
            "name": "Crypto",
            "asset_class": "crypto",
            "timezone": "UTC",
            "status": "active",
        })

        cur.execute("SELECT id FROM markets WHERE code = 'forex'")
        forex_market_id = cur.fetchone()[0]

        cur.execute("SELECT id FROM markets WHERE code = 'crypto'")
        crypto_market_id = cur.fetchone()[0]

        insert_if_missing(cur, "venues", "code", "oanda-demo", {
            "id": str(uuid.uuid4()),
            "market_id": forex_market_id,
            "code": "oanda-demo",
            "name": "OANDA Demo",
            "venue_type": "broker",
            "status": "active",
        })

        insert_if_missing(cur, "venues", "code", "binance-testnet", {
            "id": str(uuid.uuid4()),
            "market_id": crypto_market_id,
            "code": "binance-testnet",
            "name": "Binance Testnet",
            "venue_type": "exchange",
            "status": "active",
        })

        cur.execute("SELECT id FROM venues WHERE code = 'oanda-demo'")
        oanda_venue_id = cur.fetchone()[0]

        for symbol, base_asset, quote_asset, tick, lot, pp, qp in [
            ("EURUSD", "EUR", "USD", "0.0001", "1000", 5, 2),
            ("GBPUSD", "GBP", "USD", "0.0001", "1000", 5, 2),
            ("USDJPY", "USD", "JPY", "0.01", "1000", 3, 2),
            ("XAUUSD", "XAU", "USD", "0.01", "1", 2, 2),
        ]:
            insert_if_missing(cur, "instruments", "canonical_symbol", symbol, {
                "id": str(uuid.uuid4()),
                "venue_id": oanda_venue_id,
                "canonical_symbol": symbol,
                "external_symbol": symbol,
                "asset_class": "forex",
                "base_asset": base_asset,
                "quote_asset": quote_asset,
                "tick_size": tick,
                "lot_size": lot,
                "price_precision": pp,
                "quantity_precision": qp,
                "contract_multiplier": None,
                "status": "active",
            })

print("Seed complete.")
```

# 16. Scripts

## scripts/migrate.sh

```Bash
#!/usr/bin/env bash
set -e

for f in /workspace/sql/*.sql; do
  echo "Running $f"
  PGPASSWORD=postgres psql -h postgres -U postgres -d trading_platform -f "$f"
done

echo "Migrations complete."
```

## scripts/seed.sh

```Bash
#!/usr/bin/env bash
set -e
python /workspace/seeds/seed_core.py
```

## scripts/smoke.sh

```Bash
#!/usr/bin/env bash
set -e

curl -s http://localhost:8001/health
curl -s http://localhost:8002/health
curl -s http://localhost:8003/health
curl -s http://localhost:8004/health
curl -s http://localhost:8005/health
curl -s http://localhost:8006/health
curl -s http://localhost:8007/health

echo
echo "Smoke passed."
```

# 17. Docker Compose

## docker-compose.yml

```YAML
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
    ports:
      - "8001:8000"
    depends_on:
      - postgres

  market-registry-service:
    build: ./apps/market-registry-service
    ports:
      - "8002:8000"
    depends_on:
      - postgres

  instrument-master-service:
    build: ./apps/instrument-master-service
    ports:
      - "8003:8000"
    depends_on:
      - postgres

  strategy-service:
    build: ./apps/strategy-service
    ports:
      - "8004:8000"
    depends_on:
      - postgres

  order-service:
    build: ./apps/order-service
    ports:
      - "8005:8000"
    depends_on:
      - postgres

  risk-service:
    build: ./apps/risk-service
    ports:
      - "8006:8000"
    depends_on:
      - postgres

  execution-service:
    build: ./apps/execution-service
    ports:
      - "8007:8000"
    depends_on:
      - postgres

  position-service:
    build: ./apps/position-service
    ports:
      - "8008:8000"
    depends_on:
      - postgres

  audit-service:
    build: ./apps/audit-service
    ports:
      - "8009:8000"
    depends_on:
      - postgres

  web-admin:
    build: ./apps/web-admin
    ports:
      - "3000:3000"

  web-ops:
    build: ./apps/web-ops
    ports:
      - "3001:3000"
```

# 18. Makefile

## Makefile

```Makefile
up:
	docker compose up --build -d

down:
	docker compose down

logs:
	docker compose logs -f

migrate:
	docker compose exec identity-service bash /workspace/scripts/migrate.sh

seed:
	docker compose exec identity-service bash /workspace/scripts/seed.sh

smoke:
	bash ./scripts/smoke.sh
```

# 19. Python service Dockerfile
Use the same Dockerfile pattern for each backend service.

## apps/order-service/Dockerfile

```dockerfile
FROM python:3.12-slim

WORKDIR /workspace

COPY packages /workspace/packages
COPY apps/order-service /workspace/apps/order-service
COPY sql /workspace/sql
COPY seeds /workspace/seeds
COPY scripts /workspace/scripts

RUN pip install --no-cache-dir fastapi uvicorn sqlalchemy psycopg[binary] \
    pydantic pydantic-settings passlib[bcrypt] email-validator

ENV PYTHONPATH=/workspace/packages:/workspace/apps/order-service

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

Use the same pattern for all FastAPI services, changing only the app path if needed.

# 20. Vue admin app scaffold

## apps/web-admin/package.json

```JSON
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
```

## apps/web-admin/src/main.ts

```Typescript
import { createApp } from "vue"
import { createPinia } from "pinia"
import router from "./router"
import App from "./App.vue"

createApp(App).use(createPinia()).use(router).mount("#app")
```

## apps/web-admin/src/router/index.ts

```Typescript
import { createRouter, createWebHistory } from "vue-router"
import LoginView from "../views/LoginView.vue"
import AdminLayout from "../views/AdminLayout.vue"
import UsersView from "../views/UsersView.vue"
import MarketsView from "../views/MarketsView.vue"
import InstrumentsView from "../views/InstrumentsView.vue"
import StrategiesView from "../views/StrategiesView.vue"
import AuditView from "../views/AuditView.vue"

export default createRouter({
  history: createWebHistory(),
  routes: [
    { path: "/login", component: LoginView },
    {
      path: "/",
      component: AdminLayout,
      children: [
        { path: "", redirect: "/markets" },
        { path: "users", component: UsersView },
        { path: "markets", component: MarketsView },
        { path: "instruments", component: InstrumentsView },
        { path: "strategies", component: StrategiesView },
        { path: "audit", component: AuditView }
      ]
    }
  ]
})
```

## apps/web-admin/src/App.vue

```vue
<template>
  <router-view />
</template>
```

## apps/web-admin/src/views/LoginView.vue

```vue
<template>
  <div style="max-width: 360px; margin: 60px auto;">
    <h1>Admin Login</h1>
    <form @submit.prevent="submit">
      <div>
        <label>Email</label>
        <input v-model="email" type="email" />
      </div>
      <div style="margin-top: 12px;">
        <label>Password</label>
        <input v-model="password" type="password" />
      </div>
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
    await axios.post("http://localhost:8001/api/auth/login", {
      email: email.value,
      password: password.value
    })
    router.push("/markets")
  } catch {
    error.value = "Login failed"
  }
}
</script>
```

## apps/web-admin/src/views/AdminLayout.vue

```vue
<template>
  <div style="display: grid; grid-template-columns: 220px 1fr; min-height: 100vh;">
    <aside style="padding: 16px; border-right: 1px solid #ddd;">
      <h3>Admin</h3>
      <nav style="display: grid; gap: 8px;">
        <router-link to="/users">Users</router-link>
        <router-link to="/markets">Markets</router-link>
        <router-link to="/instruments">Instruments</router-link>
        <router-link to="/strategies">Strategies</router-link>
        <router-link to="/audit">Audit</router-link>
      </nav>
    </aside>
    <main style="padding: 16px;">
      <router-view />
    </main>
  </div>
</template>
```

## apps/web-admin/src/views/MarketsView.vue

```vue
<template>
  <div>
    <h1>Markets</h1>
    <table border="1" cellpadding="8">
      <thead>
        <tr>
          <th>Code</th>
          <th>Name</th>
          <th>Asset Class</th>
          <th>Timezone</th>
          <th>Status</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="item in rows" :key="item.id">
          <td>{{ item.code }}</td>
          <td>{{ item.name }}</td>
          <td>{{ item.asset_class }}</td>
          <td>{{ item.timezone }}</td>
          <td>{{ item.status }}</td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script setup lang="ts">
import axios from "axios"
import { onMounted, ref } from "vue"

const rows = ref<any[]>([])

onMounted(async () => {
  const { data } = await axios.get("http://localhost:8002/api/markets")
  rows.value = data
})
</script>
```

Create InstrumentsView.vue, StrategiesView.vue, and AuditView.vue with the same pattern against ports 8003, 8004, and 8009.

# 21. Vue ops app scaffold

## apps/web-ops/src/router/index.ts

```Typescript
import { createRouter, createWebHistory } from "vue-router"
import LoginView from "../views/LoginView.vue"
import OpsLayout from "../views/OpsLayout.vue"
import OrdersView from "../views/OrdersView.vue"
import PositionsView from "../views/PositionsView.vue"

export default createRouter({
  history: createWebHistory(),
  routes: [
    { path: "/login", component: LoginView },
    {
      path: "/",
      component: OpsLayout,
      children: [
        { path: "", redirect: "/orders" },
        { path: "orders", component: OrdersView },
        { path: "positions", component: PositionsView }
      ]
    }
  ]
})
```

## apps/web-ops/src/views/OpsLayout.vue

```vue
<template>
  <div style="display: grid; grid-template-columns: 220px 1fr; min-height: 100vh;">
    <aside style="padding: 16px; border-right: 1px solid #ddd;">
      <h3>Ops</h3>
      <nav style="display: grid; gap: 8px;">
        <router-link to="/orders">Orders</router-link>
        <router-link to="/positions">Positions</router-link>
      </nav>
    </aside>
    <main style="padding: 16px;">
      <router-view />
    </main>
  </div>
</template>
```

## apps/web-ops/src/views/OrdersView.vue

```vue
<template>
  <div>
    <h1>Orders</h1>
    <table border="1" cellpadding="8">
      <thead>
        <tr>
          <th>ID</th>
          <th>Instrument</th>
          <th>Side</th>
          <th>Type</th>
          <th>Quantity</th>
          <th>Status</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="item in rows" :key="item.id">
          <td>{{ item.id }}</td>
          <td>{{ item.instrument_id }}</td>
          <td>{{ item.side }}</td>
          <td>{{ item.order_type }}</td>
          <td>{{ item.quantity }}</td>
          <td>{{ item.intent_status }}</td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script setup lang="ts">
import axios from "axios"
import { onMounted, ref } from "vue"

const rows = ref<any[]>([])

onMounted(async () => {
  const { data } = await axios.get("http://localhost:8005/api/orders")
  rows.value = data
})
</script>
```

## apps/web-ops/src/views/PositionsView.vue

```vue
<template>
  <div>
    <h1>Positions</h1>
    <table border="1" cellpadding="8">
      <thead>
        <tr>
          <th>Instrument</th>
          <th>Net Quantity</th>
          <th>Average Price</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="item in rows" :key="item.id">
          <td>{{ item.instrument_id }}</td>
          <td>{{ item.net_quantity }}</td>
          <td>{{ item.avg_price }}</td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script setup lang="ts">
import axios from "axios"
import { onMounted, ref } from "vue"

const rows = ref<any[]>([])

onMounted(async () => {
  const { data } = await axios.get("http://localhost:8008/api/positions")
  rows.value = data
})
</script>
```

# 22. First paper workflow test
Use these calls in order.

## 1. Create order intent

```Bash
curl -X POST http://localhost:8005/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "instrument_id":"<instrument-uuid>",
    "side":"buy",
    "order_type":"market",
    "quantity":"1000",
    "tif":"IOC"
  }'
```

## 2. Evaluate risk

```Bash
curl -X POST http://localhost:8006/api/risk/evaluate \
  -H "Content-Type: application/json" \
  -d '{
    "order_intent_id":"<order-id>",
    "instrument_id":"<instrument-uuid>",
    "side":"buy",
    "quantity":"1000"
  }'
```

## 3. Simulate execution

```Bash
curl -X POST http://localhost:8007/api/execution/simulate \
  -H "Content-Type: application/json" \
  -d '{
    "order_intent_id":"<order-id>",
    "venue_id":"<venue-uuid>",
    "instrument_id":"<instrument-uuid>",
    "quantity":"1000",
    "price":"1.0850"
  }'
```

## 4. Apply fill to position

```Bash
curl -X POST http://localhost:8008/api/positions/apply-fill \
  -H "Content-Type: application/json" \
  -d '{
    "account_id": null,
    "instrument_id":"<instrument-uuid>",
    "side":"buy",
    "fill_quantity":"1000",
    "fill_price":"1.0850"
  }'
```

## 5. Record audit

```Bash
curl -X POST http://localhost:8009/api/audit \
  -H "Content-Type: application/json" \
  -d '{
    "actor_type":"system",
    "actor_id":null,
    "event_type":"paper_trade.executed",
    "resource_type":"order_intent",
    "resource_id":"<order-id>"
  }'
```

# 23. What to build next from this scaffold
After this starter pack, the next upgrade should be:
- real JWT auth instead of placeholder token
- proper shared SQLAlchemy base package per service
- Alembic migrations instead of raw SQL-only
- event publishing to Kafka
- risk result persistence and order state transitions
- automatic position updates from fills
- strategy version CRUD and deployment records
- better UI tables/forms
- audit hooks inside every mutation

The best continuation is Volume 5: integrated end-to-end workflow pack, where I lay out the exact code changes needed so order creation → risk → execution → position → audit happens automatically across services.