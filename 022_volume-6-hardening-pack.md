# 1. Goal
Strengthen the platform in the places that matter most:
- authentication
- inter-service trust
- durable auditability
- order history
- risk history
- rollback safety
- retries and timeouts
- correlation IDs
- better failure handling
- better UI visibility
This is the stage where the system starts behaving like a controlled trading platform instead of a prototype.

# 2. Hardening priorities
The next controls should be added in this order:
1. JWT auth for users
2. inter-service auth
3. persistent order state history
4. persistent risk evaluation history
5. automatic audit hooks
6. correlation IDs across requests
7. timeout/retry/circuit-breaker rules
8. transaction safety and compensation rules
9. standardized error model
10. better observability hooks

# 3. Authentication hardening

## 3.1 Replace placeholder login token
Right now the login returns a fake token. Replace that with a signed JWT.

### Identity service additions

#### Token payload should include
- `sub` user id
- `email`
- `roles`
- `permissions`
- `iat`
- `exp`
- `iss`

### Example JWT helper

#### apps/identity-service/app/security/jwt.py

```Python
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
```

### Login route update
Instead of `"dev-token"`, return a real signed token.

## 3.2 Backend auth dependency
Every protected service should validate bearer tokens.

### Example shared auth package
Create `packages/shared-auth`.

#### packages/shared-auth/shared_auth/jwt_auth.py

```Python
from fastapi import Header, HTTPException
import jwt


def decode_token(token: str, secret: str, algorithm: str) -> dict:
    try:
        return jwt.decode(token, secret, algorithms=[algorithm], issuer="trading-platform")
    except Exception as exc:
        raise HTTPException(status_code=401, detail=f"Invalid token: {exc}")


def get_bearer_token(authorization: str | None = Header(default=None)) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    return authorization.replace("Bearer ", "", 1)
```

Each service should then expose:
- public routes only where required
- auth-protected routes by default

# 4. Inter-service authentication
User auth is not enough. Services must trust each other securely.

## 4.1 Service token approach for MVP hardening
Use one internal service secret first, then move to per-service credentials later.
Each service-to-service call should send:
- `X-Service-Name`
- `X-Service-Token`

### Example config
Add to each service settings:

```Python
internal_service_token: str = "internal-dev-token"
```

### Example validation dependency

```Python
from fastapi import Header, HTTPException

def validate_internal_service(
    x_service_name: str | None = Header(default=None),
    x_service_token: str | None = Header(default=None),
):
    if not x_service_name or not x_service_token:
        raise HTTPException(status_code=401, detail="Missing internal auth headers")
    if x_service_token != "internal-dev-token":
        raise HTTPException(status_code=401, detail="Invalid internal service token")
    return {"service_name": x_service_name}
```

Use this on internal mutation endpoints called by other services.

# 5. Persistent order state history
Right now only the latest order state is stored. That is not enough.

## 5.1 Add `order_state_history` table

### SQL migration

```SQL
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
```

## 5.2 Write history on every transition

### apps/order-service/app/domain/history.py

```Python
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
```

## 5.3 Update state transition helper

```Python
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
```

This becomes essential for audit and debugging.

# 6. Persistent risk evaluation history
You need a durable record of why risk approved or rejected an order.

## 6.1 Add `risk_evaluations` table

```SQL
CREATE TABLE IF NOT EXISTS risk_evaluations (
    id UUID PRIMARY KEY,
    order_intent_id UUID NOT NULL REFERENCES order_intents(id),
    decision VARCHAR(20) NOT NULL,
    next_state VARCHAR(50) NOT NULL,
    rule_results JSONB NOT NULL,
    evaluated_by_service VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## 6.2 Add risk persistence model

### apps/risk-service/app/db/models.py

```Python
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
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
```

## 6.3 Save every evaluation result
Risk decisions should be queryable later from:
- order detail pages
- compliance review
- incident analysis

# 7. Automatic audit hooks
Manual audit calls are easy to miss. Start centralizing them.

## 7.1 Create reusable audit helper

### packages/shared-domain/shared_domain/audit_client.py

```Python
import httpx

async def send_audit_event(base_url: str, service_name: str, token: str, payload: dict):
    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.post(
            f"{base_url}/api/audit",
            json=payload,
            headers={
                "X-Service-Name": service_name,
                "X-Service-Token": token,
            },
        )
        resp.raise_for_status()
        return resp.json()
```

## 7.2 Define audit event naming convention
Use structured names:
- `order_intent.created`
- `order_intent.state_changed`
- `risk.evaluation.completed`
- `execution.simulated`
- `position.updated`
- `auth.login.succeeded`
- `auth.login.failed`
- `user.role_assigned`
Do not use random names.

# 8. Correlation IDs and request tracing
Every workflow should carry a correlation ID through all services.

## 8.1 Header standard
Use:
- `X-Correlation-ID`
- `X-Request-ID`

## 8.2 Generate at entrypoint
If a request reaches order-service without a correlation ID, generate one.

### Example helper

```Python
import uuid
from fastapi import Header

def get_or_create_correlation_id(x_correlation_id: str | None = Header(default=None)) -> str:
    return x_correlation_id or str(uuid.uuid4())
```

## 8.3 Pass it downstream
All service-to-service calls must forward:
- `X-Correlation-ID`

## 8.4 Persist it
Add `correlation_id` columns where useful:
- `order_intents`
- `broker_orders`
- `fills`
- `audit_events`
- `risk_evaluations`
This makes investigation much easier.

# 9. Standardized error model
Right now errors are ad hoc. Standardize them.

## 9.1 Error response shape

```JSON
{
  "error": {
    "code": "RISK_REJECTED",
    "message": "Order rejected by risk policy",
    "details": {
      "order_intent_id": "uuid"
    },
    "correlation_id": "uuid"
  }
}
```

## 9.2 Error code classes
Use stable codes like:
- `AUTH_INVALID_TOKEN`
- `AUTH_FORBIDDEN`
- `ORDER_INVALID_STATE`
- `RISK_REJECTED`
- `EXECUTION_FAILED`
- `POSITION_UPDATE_FAILED`
- `AUDIT_WRITE_FAILED`
- `DEPENDENCY_TIMEOUT`
- `DEPENDENCY_UNAVAILABLE`

## 9.3 FastAPI exception handler
Implement a common handler package later so responses stay consistent.

# 10. Retry, timeout, and circuit-breaker rules
Trading systems should fail clearly, not hang.

## 10.1 Timeout rules
Use explicit timeouts:
- audit-service: 5–10s
- risk-service: 5–10s
- execution-service: 10–15s
- position-service: 5–10s

## 10.2 Retry policy
Do not blindly retry everything.

### Safe to retry
- audit writes
- read-only lookups
- idempotent internal POSTs if idempotency keys exist

### Dangerous to retry blindly
- broker order submission
- fill ingestion
- position updates without idempotency protections

## 10.3 Circuit breaker
If a downstream service keeps failing:
- stop hammering it
- surface degraded mode
- fail fast with clear error
For now, even a simple in-memory breaker is acceptable per service instance.

# 11. Idempotency
This is critical.

## 11.1 Add idempotency key on sensitive operations
Use header:
- `Idempotency-Key`
For:
- `/api/orders/submit`
- execution simulate/submit
- fill application

## 11.2 Add persistence table

```SQL
CREATE TABLE IF NOT EXISTS idempotency_keys (
    id UUID PRIMARY KEY,
    scope VARCHAR(100) NOT NULL,
    idempotency_key VARCHAR(255) NOT NULL,
    response_json JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(scope, idempotency_key)
);
```

This prevents duplicate order submissions on retries or UI refreshes.

# 12. Transaction safety and compensation
The first integrated flow spans several services, so a DB transaction cannot cover everything.
Use compensation rules.

## 12.1 Failure scenarios and action

### Scenario A: risk passed, execution failed
Action:
- keep order as `risk_passed` or set to `execution_failed`
- record audit
- show retry action in ops UI

### Scenario B: execution succeeded, position update failed
Action:
- record critical incident
- mark reconciliation-needed flag
- do not lose execution result

### Scenario C: position updated, audit failed
Action:
- business state remains valid
- retry audit asynchronously
- raise warning

## 12.2 Add new order state
Add:
- `execution_failed`
Update allowed transitions accordingly.

```Python
ALLOWED_TRANSITIONS = {
    "draft": {"risk_pending"},
    "risk_pending": {"risk_passed", "risk_failed"},
    "risk_passed": {"submitted"},
    "submitted": {"acknowledged", "rejected", "execution_failed", "filled"},
    "acknowledged": {"partially_filled", "filled", "cancel_pending", "expired"},
    "partially_filled": {"filled", "cancel_pending"},
    "cancel_pending": {"cancelled"},
}
```

# 13. Order detail endpoint
You need one endpoint that shows the full lifecycle.

## 13.1 Add `/api/orders/{id}`
Return:
- order intent
- state history
- risk evaluations
- broker orders
- fills
- audit summary
This will power a real order detail screen.

# 14. UI hardening

## 14.1 Admin UI additions
Add:
- order detail page
- risk evaluation panel
- state history panel

## 14.2 Ops UI additions
Add:
- last error column
- correlation ID column
- retry button for safe retry cases
- incident badge if any downstream step failed

## 14.3 Better forms
For integrated order submit:
- dropdown for instrument
- dropdown for venue
- validation on quantity and price
- display returned correlation ID

# 15. Observability hooks
Even before full Prometheus/Grafana, add structured logs.

## 15.1 Structured log fields
Every log line should include:
- timestamp
- service
- level
- message
- correlation_id
- order_intent_id if relevant
- actor_type
- actor_id if known

## 15.2 Key metrics to expose
Each service should count:
- requests total
- request failures
- dependency call latency
- dependency call failures
- order submits
- risk rejects
- execution failures
- audit failures

# 16. Example hardened order submit flow
The improved flow should be:

```
POST /api/orders/submit
  validate bearer token
  get/generate correlation id
  check idempotency key
  create order(draft)
  record order_state_history(draft)
  audit created
  transition risk_pending
  persist state history
  call risk-service with internal auth + correlation id
  save risk evaluation
  if reject:
      transition risk_failed
      audit risk failed
      return
  transition risk_passed
  transition submitted
  call execution-service with internal auth + correlation id
  if execution fails:
      transition execution_failed
      audit failure
      return error
  save broker/fill data
  transition filled
  call position-service
  if position update fails:
      raise incident + reconciliation flag
  audit success
  store idempotent response
  return final response
```

# 17. Example code additions for internal headers

## apps/order-service/app/integrations/clients.py

```Python
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
```

Do the same for execution, position, and audit.

# 18. Example audit table hardening
Add correlation support.

```SQL
ALTER TABLE audit_events
ADD COLUMN IF NOT EXISTS correlation_id UUID;
```

Add similar columns to:
- `order_intents`
- `risk_evaluations`
- `broker_orders`
- `fills`

# 19. Example ops failure handling response
If execution fails, return something like:

```JSON
{
  "order_id": "uuid",
  "final_status": "execution_failed",
  "risk_decision": "pass",
  "execution": null,
  "position": null,
  "error": {
    "code": "EXECUTION_FAILED",
    "message": "Execution service unavailable",
    "correlation_id": "uuid"
  }
}
```

This is much better than a vague 500.

# 20. Security hardening notes
At this stage, also add:
- password hashing remains bcrypt or argon2
- CORS restricted to your frontend origins
- admin routes require auth
- ops routes require auth
- internal mutation routes reject browser-origin traffic where possible
- no secrets in frontend code
- no raw DB credentials in committed env files

# 21. Database migration pack for hardening
Add a new migration file.

## sql/006_hardening.sql

```SQL
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

ALTER TABLE order_intents
ADD COLUMN IF NOT EXISTS correlation_id UUID;

ALTER TABLE broker_orders
ADD COLUMN IF NOT EXISTS correlation_id UUID;

ALTER TABLE fills
ADD COLUMN IF NOT EXISTS correlation_id UUID;

ALTER TABLE audit_events
ADD COLUMN IF NOT EXISTS correlation_id UUID;
```

# 22. Manual testing checklist after hardening
Test these specifically:
1. login returns JWT
2. protected endpoints reject missing token
3. internal service endpoints reject missing internal headers
4. order submit writes state history
5. risk evaluation is persisted
6. duplicate submit with same idempotency key does not create duplicate order
7. execution failure produces `execution_failed`
8. correlation ID appears in audit and order records
9. order detail page shows full lifecycle
10. UI surfaces failure reason clearly

# 23. What should come next
After this hardening pass, the correct next step is:

## Volume 7: event-driven upgrade pack
That should move the platform from synchronous orchestration to a proper event-driven backbone with:
- Kafka/Redpanda topics
- event publishers
- event consumers
- outbox pattern
- eventual consistency handling
- replayability
- asynchronous audit and notifications
- strategy runtime decoupling
- live workflow scaling
That is the point where the system becomes truly scalable for many strategies and many markets