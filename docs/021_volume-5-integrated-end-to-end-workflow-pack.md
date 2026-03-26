## 1. Goal
Make this happen automatically:
1. create order intent
2. transition order to `risk_pending`
3. risk-service evaluates it
4. order becomes `risk_passed` or `risk_failed`
5. if passed, execution-service simulates broker execution
6. fill is stored
7. position-service updates the position
8. audit-service records all key steps
9. ops UI shows the updated order and position state
This is the **first real integrated trading flow.**

## 2. Integration approach
For the first integrated version, the safest path is:
- keep each service separate
- use synchronous HTTP calls first
- add Kafka later once the business flow is stable
So the first orchestration style is:

>order-service
>  → risk-service
>  → execution-service
>  → position-service
>  → audit-service

This is simpler to debug than event-driven orchestration on day one.

## 3. Workflow ownership
The cleanest place to orchestrate first is **order-service.**
Why:
- order-service already owns order intent lifecycle
- it can drive status transitions
- it is the natural place to start the trade pipeline

So the first integrated workflow is:
- order-service creates the order
- order-service calls risk-service
- if pass, order-service calls execution-service
- order-service calls position-service
- order-service calls audit-service
Later, this can become event-driven.

# 4. New flow design

## 4.1 Full synchronous flow

>POST /api/orders/submit
>
>order-service:
>  create draft order
>  -> transition to risk_pending
>  -> call risk-service
>  -> if fail:
>       transition to risk_failed
>       record audit
>       return result
>  -> if pass:
>       transition to risk_passed
>       transition to submitted
>       call execution-service simulate
>       transition to filled
>       call position-service apply-fill
>       record audit events
>       return integrated response

# 5. Required improvements by service

## order-service
Add:
- `submit order` orchestration endpoint
- state transition helper
- HTTP clients for downstream services
- audit call integration

## risk-service
Already close enough.
Add:
- slightly richer response structure

## execution-service
Already close enough.
Add:
- response should include fill data clearly

## position-service
Already close enough.
Add:
- return updated position summary

## audit-service
Already close enough.
Add:
- batch or repeated writes are fine for now

# 6. New order lifecycle states to actually use
Use these in the integrated flow:
- `draft`
- `risk_pending`
- `risk_passed`
- `risk_failed`
- `submitted`
- `filled`
You do not need all other states immediately for the first integrated version.

# 7. order-service changes

## 7.1 Add service URLs to config

### apps/order-service/app/config.py

```Python
from shared_config.settings import Settings


class OrderServiceSettings(Settings):
    risk_service_url: str = "http://risk-service:8000"
    execution_service_url: str = "http://execution-service:8000"
    position_service_url: str = "http://position-service:8000"
    audit_service_url: str = "http://audit-service:8000"


settings = OrderServiceSettings(app_name="order-service", port=8000)
```

## 7.2 Add state transition helper

### apps/order-service/app/domain/state_machine.py

```Python
from shared_domain.order_state import can_transition


def transition_order(row, next_state: str):
    current_state = row.intent_status
    if not can_transition(current_state, next_state):
        raise ValueError(f"Illegal order state transition: {current_state} -> {next_state}")
    row.intent_status = next_state
    return row
```

## 7.3 Add downstream HTTP client helpers

### apps/order-service/app/integrations/clients.py

```Python
import httpx
from app.config import settings


async def call_risk_service(payload: dict) -> dict:
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            f"{settings.risk_service_url}/api/risk/evaluate",
            json=payload,
        )
        response.raise_for_status()
        return response.json()


async def call_execution_service(payload: dict) -> dict:
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            f"{settings.execution_service_url}/api/execution/simulate",
            json=payload,
        )
        response.raise_for_status()
        return response.json()


async def call_position_service(payload: dict) -> dict:
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            f"{settings.position_service_url}/api/positions/apply-fill",
            json=payload,
        )
        response.raise_for_status()
        return response.json()


async def call_audit_service(payload: dict) -> dict:
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            f"{settings.audit_service_url}/api/audit",
            json=payload,
        )
        response.raise_for_status()
        return response.json()
```

## 7.4 Add richer order response models

### apps/order-service/app/api/schemas.py

```Python
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
```

## 7.5 Replace order route with integrated flow

### apps/order-service/app/api/routes/orders.py

```Python
import uuid
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.db.models import OrderIntentModel
from app.api.schemas import OrderIntentCreate, OrderSubmitResponse
from app.domain.state_machine import transition_order
from app.integrations.clients import (
    call_risk_service,
    call_execution_service,
    call_position_service,
    call_audit_service,
)

router = APIRouter()


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


@router.post("/submit", response_model=OrderSubmitResponse)
async def submit_order(payload: OrderIntentCreate, db: Session = Depends(get_db)):
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

    await call_audit_service({
        "actor_type": "system",
        "actor_id": None,
        "event_type": "order_intent.created",
        "resource_type": "order_intent",
        "resource_id": row.id,
        "after_json": {
            "instrument_id": row.instrument_id,
            "side": row.side,
            "quantity": str(row.quantity),
            "status": row.intent_status,
        },
    })

    try:
        transition_order(row, "risk_pending")
        db.commit()
        db.refresh(row)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))

    risk_result = await call_risk_service({
        "order_intent_id": row.id,
        "quantity": str(row.quantity),
        "side": row.side,
        "instrument_id": row.instrument_id,
        "account_id": row.account_id,
    })

    if risk_result["decision"] == "reject":
        transition_order(row, "risk_failed")
        db.commit()
        db.refresh(row)

        await call_audit_service({
            "actor_type": "system",
            "actor_id": None,
            "event_type": "order_intent.risk_failed",
            "resource_type": "order_intent",
            "resource_id": row.id,
            "after_json": {
                "status": row.intent_status,
                "risk_result": risk_result,
            },
        })

        return OrderSubmitResponse(
            order_id=row.id,
            final_status=row.intent_status,
            risk_decision="reject",
            execution=None,
            position=None,
        )

    try:
        transition_order(row, "risk_passed")
        db.commit()
        db.refresh(row)

        transition_order(row, "submitted")
        db.commit()
        db.refresh(row)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))

    await call_audit_service({
        "actor_type": "system",
        "actor_id": None,
        "event_type": "order_intent.risk_passed",
        "resource_type": "order_intent",
        "resource_id": row.id,
        "after_json": {
            "status": row.intent_status,
            "risk_result": risk_result,
        },
    })

    execution_result = await call_execution_service({
        "order_intent_id": row.id,
        "venue_id": payload.venue_id,
        "instrument_id": row.instrument_id,
        "quantity": str(row.quantity),
        "price": str(payload.execution_price),
        "fee_amount": "0.0",
        "fee_currency": "USD",
    })

    # for the starter flow, simulate => filled immediately
    row.intent_status = "filled"
    db.commit()
    db.refresh(row)

    position_result = await call_position_service({
        "account_id": row.account_id,
        "instrument_id": row.instrument_id,
        "side": row.side,
        "fill_quantity": str(row.quantity),
        "fill_price": str(payload.execution_price),
    })

    await call_audit_service({
        "actor_type": "system",
        "actor_id": None,
        "event_type": "order_intent.filled",
        "resource_type": "order_intent",
        "resource_id": row.id,
        "after_json": {
            "status": row.intent_status,
            "execution_result": execution_result,
            "position_result": position_result,
        },
    })

    return OrderSubmitResponse(
        order_id=row.id,
        final_status=row.intent_status,
        risk_decision="pass",
        execution=execution_result,
        position=position_result,
    )
```

# 8. risk-service improvement
Current version is fine, but make sure the response is stable.

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
            "severity": "high",
        }
    return {
        "passed": True,
        "rule_type": "max_position_size",
        "message": "Passed",
        "severity": "info",
    }


@router.post("/evaluate")
def evaluate_order(payload: RiskEvaluationRequest):
    results = [
        evaluate_max_position_size(payload.quantity, Decimal("100000"))
    ]
    failed = [r for r in results if not r["passed"]]

    return {
        "order_intent_id": payload.order_intent_id,
        "decision": "reject" if failed else "pass",
        "rule_results": results,
        "next_state": "risk_failed" if failed else "risk_passed",
    }
```

# 9. execution-service improvement
Return more explicit fill details.

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
        "external_order_id": broker_order.external_order_id,
        "fill_id": fill.id,
        "status": "filled",
        "fill": {
            "instrument_id": payload.instrument_id,
            "quantity": str(payload.quantity),
            "price": str(payload.price),
            "fee_amount": str(payload.fee_amount),
            "fee_currency": payload.fee_currency,
        },
    }
```

# 10. position-service improvement
It is already good enough. Just return more fields if needed.

## apps/position-service/app/api/routes/positions.py
Keep the route, but return:

```Python
return {
    "id": row.id,
    "account_id": row.account_id,
    "instrument_id": row.instrument_id,
    "net_quantity": str(row.net_quantity),
    "avg_price": str(row.avg_price),
    "market_value": str(row.market_value),
    "unrealized_pnl": str(row.unrealized_pnl),
    "realized_pnl": str(row.realized_pnl),
}
```

# 11. Add service `main.py` endpoints if missing
Each service should expose the proper router.
Example:

## apps/risk-service/app/main.py

```Python
from fastapi import FastAPI
from app.api.routes.risk import router as risk_router

app = FastAPI(title="risk-service", version="0.1.0")
app.include_router(risk_router, prefix="/api/risk", tags=["risk"])


@app.get("/health")
def health():
    return {"status": "ok", "service": "risk-service"}
```

Do the same for:
- execution-service
- position-service
- audit-service
- market-registry-service
- instrument-master-service
- strategy-service

# 12. Dockerfile update
Because order-service now uses async HTTP clients, install `httpx`.

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
    pydantic pydantic-settings passlib[bcrypt] email-validator httpx

ENV PYTHONPATH=/workspace/packages:/workspace/apps/order-service

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

For consistency, install the same core dependencies in the other Python service Dockerfiles.

# 13. Docker Compose networking note
In container-to-container calls, use service names, not localhost.

These config values are correct:
- `http://risk-service:8000`
- `http://execution-service:8000`
- `http://position-service:8000`
- `http://audit-service:8000`

So no special networking changes are needed if all services are in the same `docker-compose.yml`.

# 14. Integrated smoke workflow
Replace the simple smoke script with a real flow.

## scripts/smoke.sh

```Bash
#!/usr/bin/env bash
set -e

echo "Checking health endpoints..."
curl -s http://localhost:8001/health >/dev/null
curl -s http://localhost:8002/health >/dev/null
curl -s http://localhost:8003/health >/dev/null
curl -s http://localhost:8004/health >/dev/null
curl -s http://localhost:8005/health >/dev/null
curl -s http://localhost:8006/health >/dev/null
curl -s http://localhost:8007/health >/dev/null
curl -s http://localhost:8008/health >/dev/null
curl -s http://localhost:8009/health >/dev/null

echo "Fetching seeded venue and instrument..."
INSTRUMENT_ID=$(docker-compose exec postgres psql -U postgres -d trading_platform -t -A -c "SELECT id FROM instruments WHERE canonical_symbol='EURUSD' LIMIT 1;")
VENUE_ID=$(docker-compose exec postgres psql -U postgres -d trading_platform -t -A -c "SELECT id FROM venues WHERE code='oanda-demo' LIMIT 1;")

echo "Submitting integrated order..."
RESPONSE=$(curl -s -X POST http://localhost:8005/api/orders/submit \
  -H "Content-Type: application/json" \
  -d "{
    \"instrument_id\":\"$INSTRUMENT_ID\",
    \"side\":\"buy\",
    \"order_type\":\"market\",
    \"quantity\":\"1000\",
    \"tif\":\"IOC\",
    \"venue_id\":\"$VENUE_ID\",
    \"execution_price\":\"1.0850\"
  }")

echo "$RESPONSE"

echo "Verifying positions..."
curl -s http://localhost:8008/api/positions

echo
echo "Verifying audit..."
curl -s http://localhost:8009/api/audit

echo
echo "Integrated smoke passed."
```

# 15. How the first integrated test should behave
When you run the smoke flow:

## Expected order outcome
The order should:
- be created
- pass risk
- execute immediately
- end as `filled`

## Expected execution outcome
The execution response should contain:
- `broker_order_id`
- `external_order_id`
- `fill_id`
- fill price and quantity

## Expected position outcome
For the first buy of `1000` EURUSD at `1.0850`, position should show approximately:
- `net_quantity = 1000`
- `avg_price = 1.0850`

## Expected audit outcome
Audit should contain at least:
- `order_intent.created`
- `order_intent.risk_passed`
- `order_intent.filled`

# 16. Admin UI additions
For the admin app, add a basic Strategies page and Audit page if not already done.

## apps/web-admin/src/views/StrategiesView.vue

```vue
<template>
  <div>
    <h1>Strategies</h1>
    <table border="1" cellpadding="8">
      <thead>
        <tr>
          <th>Code</th>
          <th>Name</th>
          <th>Type</th>
          <th>Status</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="item in rows" :key="item.id">
          <td>{{ item.code }}</td>
          <td>{{ item.name }}</td>
          <td>{{ item.type }}</td>
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
  const { data } = await axios.get("http://localhost:8004/api/strategies")
  rows.value = data
})
</script>
```

## apps/web-admin/src/views/AuditView.vue

```vue
<template>
  <div>
    <h1>Audit Events</h1>
    <table border="1" cellpadding="8">
      <thead>
        <tr>
          <th>Time</th>
          <th>Event</th>
          <th>Resource Type</th>
          <th>Resource ID</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="item in rows" :key="item.id">
          <td>{{ item.created_at }}</td>
          <td>{{ item.event_type }}</td>
          <td>{{ item.resource_type }}</td>
          <td>{{ item.resource_id }}</td>
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
  const { data } = await axios.get("http://localhost:8009/api/audit")
  rows.value = data
})
</script>
```

# 17. Ops UI improvement: add integrated submit page
This is useful for manual testing.

## apps/web-ops/src/views/OrdersView.vue
Replace with a form plus list:

```vue
<template>
  <div>
    <h1>Orders</h1>

    <form @submit.prevent="submitOrder" style="margin-bottom: 24px;">
      <div>
        <label>Instrument ID</label>
        <input v-model="form.instrument_id" style="width: 420px;" />
      </div>
      <div style="margin-top: 8px;">
        <label>Venue ID</label>
        <input v-model="form.venue_id" style="width: 420px;" />
      </div>
      <div style="margin-top: 8px;">
        <label>Side</label>
        <select v-model="form.side">
          <option value="buy">buy</option>
          <option value="sell">sell</option>
        </select>
      </div>
      <div style="margin-top: 8px;">
        <label>Quantity</label>
        <input v-model="form.quantity" />
      </div>
      <div style="margin-top: 8px;">
        <label>Execution Price</label>
        <input v-model="form.execution_price" />
      </div>
      <button type="submit" style="margin-top: 12px;">Submit Integrated Order</button>
    </form>

    <pre v-if="lastResponse">{{ lastResponse }}</pre>

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
const lastResponse = ref("")
const form = ref({
  instrument_id: "",
  venue_id: "",
  side: "buy",
  quantity: "1000",
  execution_price: "1.0850"
})

async function loadOrders() {
  const { data } = await axios.get("http://localhost:8005/api/orders")
  rows.value = data
}

async function submitOrder() {
  const { data } = await axios.post("http://localhost:8005/api/orders/submit", {
    instrument_id: form.value.instrument_id,
    side: form.value.side,
    order_type: "market",
    quantity: form.value.quantity,
    tif: "IOC",
    venue_id: form.value.venue_id,
    execution_price: form.value.execution_price
  })
  lastResponse.value = JSON.stringify(data, null, 2)
  await loadOrders()
}

onMounted(loadOrders)
</script>
```

This gives you a manual integrated test page.

# 18. Manual UAT sequence
Use this exact sequence after booting the system.

## Step 1
Run:

```Bash
make up
```

## Step 2
Run migrations:

```Bash
make migrate
```

## Step 3
Run seed:

```Bash
make seed
```

## Step 4
Open admin UI:
- `http://localhost:3000`
Log in with:
- `admin@example.com`
- `admin123`

## Step 5
Verify:
- Markets page loads
- Instruments page loads
- Strategies page loads
- Audit page loads

## Step 6
Open ops UI:
- `http://localhost:3001`

## Step 7
Get seeded IDs from DB:

```Bash
docker-compose exec postgres psql -U postgres -d trading_platform -c "SELECT id, canonical_symbol FROM instruments;"
docker-compose exec postgres psql -U postgres -d trading_platform -c "SELECT id, code FROM venues;"
```

## Step 8
Paste `EURUSD` instrument ID and `oanda-demo` venue ID into the Ops Orders form.

## Step 9
Submit an integrated order.

## Step 10
Verify:
- order appears as `filled`
- position is updated
- audit log contains the workflow events

# 19. Known gaps in this integrated starter
This flow is correct for a starter, but it still has these simplifications:
- no JWT validation between services
- no Kafka events yet
- no persistent risk result table
- no broker acknowledgements or partial fills
- no automatic market value / P&L recalculation
- no deployment/account scoping enforcement
- no retries or circuit breakers around service calls
- no distributed tracing yet
That is fine for this stage.

# 20. What should come next
After this integrated flow works, the next major upgrade is:

## Volume 6: hardening pack
This should add:
- JWT auth and inter-service auth
- persistent order state history
- persistent risk evaluations
- automatic audit hooks
- better error handling and rollback semantics
- transactional consistency rules
- retry and timeout policy
- Kafka event publishing for all lifecycle stages
- service correlation IDs
- richer ops/admin tables
That is the correct next step once this workflow is running end to end.