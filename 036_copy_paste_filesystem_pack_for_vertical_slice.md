# Copy-Paste Filesystem Pack for the First Vertical Slice

This pack gives the exact repo file contents to copy into the integrated monorepo for the first working slice.

Included:
- root `docker-compose.yml`
- root `Makefile`
- SQL migrations `001`–`005`
- `seeds/seed_core.py`
- migration/seed/smoke scripts
- Dockerfile template for first-slice Python services
- exact file set for the first backend services
- exact file set for `web-admin` and `web-ops`

---

# 1. Root files

## `docker-compose.yml`

```yaml
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
      - redpanda

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

  broker-adapter-simulator:
    build: ./apps/broker-adapter-simulator
    ports:
      - "8010:8000"

  web-admin:
    build: ./apps/web-admin
    ports:
      - "3000:3000"

  web-ops:
    build: ./apps/web-ops
    ports:
      - "3001:3000"
```

## `Makefile`

```makefile
up:
	docker compose up --build -d

down:
	docker compose down

logs:
	docker compose logs -f

migrate:
	bash scripts/migrate/run_all.sh

seed:
	bash scripts/seed/run_all.sh

smoke:
	bash scripts/smoke/platform_smoke.sh
```

---

# 2. Root scripts

## `scripts/migrate/run_all.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

for f in sql/001_core_identity.sql \
         sql/002_markets_instruments.sql \
         sql/003_strategies.sql \
         sql/004_orders_risk.sql \
         sql/005_positions_audit.sql

do
  echo "Applying $f"
  PGPASSWORD=postgres psql -h localhost -U postgres -d trading_platform -f "$f"
done
```

## `scripts/seed/run_all.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
python seeds/seed_core.py
```

## `scripts/smoke/platform_smoke.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Checking health endpoints..."
curl -s http://localhost:8001/health/live >/dev/null
curl -s http://localhost:8002/health/live >/dev/null
curl -s http://localhost:8003/health/live >/dev/null
curl -s http://localhost:8004/health/live >/dev/null
curl -s http://localhost:8005/health/live >/dev/null
curl -s http://localhost:8006/health/live >/dev/null
curl -s http://localhost:8007/health/live >/dev/null
curl -s http://localhost:8008/health/live >/dev/null
curl -s http://localhost:8009/health/live >/dev/null

INSTRUMENT_ID=$(PGPASSWORD=postgres psql -h localhost -U postgres -d trading_platform -t -A -c "SELECT id FROM instruments WHERE canonical_symbol='EURUSD' LIMIT 1;")
VENUE_ID=$(PGPASSWORD=postgres psql -h localhost -U postgres -d trading_platform -t -A -c "SELECT id FROM venues WHERE code='oanda-demo' LIMIT 1;")

RESPONSE=$(curl -s -X POST http://localhost:8005/api/orders/submit \
  -H "Content-Type: application/json" \
  -d "{
    \"instrument_id\": \"$INSTRUMENT_ID\",
    \"side\": \"buy\",
    \"order_type\": \"market\",
    \"quantity\": \"1000\",
    \"tif\": \"IOC\",
    \"venue_id\": \"$VENUE_ID\",
    \"execution_price\": \"1.0850\"
  }")

echo "$RESPONSE"
echo
curl -s http://localhost:8008/api/positions
echo
echo
curl -s http://localhost:8009/api/audit
echo
echo "Smoke passed."
```

---

# 3. SQL migrations

## `sql/001_core_identity.sql`

```sql
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

## `sql/002_markets_instruments.sql`

```sql
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

## `sql/003_strategies.sql`

```sql
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

## `sql/004_orders_risk.sql`

```sql
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

## `sql/005_positions_audit.sql`

```sql
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

---

# 4. Seed file

## `seeds/seed_core.py`

```python
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
            insert_if_missing(cur, "roles", "code", code, {
                "id": str(uuid.uuid4()),
                "code": code,
                "name": name,
            })

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
            insert_if_missing(cur, "permissions", "code", code, {
                "id": str(uuid.uuid4()),
                "code": code,
                "name": name,
            })

        admin_email = "admin@example.com"
        insert_if_missing(cur, "users", "email", admin_email, {
            "id": str(uuid.uuid4()),
            "name": "Admin User",
            "email": admin_email,
            "password_hash": pwd.hash("admin123"),
            "status": "active",
            "mfa_enabled": False,
        })

        cur.execute("SELECT id FROM roles WHERE code = 'super_admin'")
        super_admin_role_id = cur.fetchone()[0]
        cur.execute("SELECT id FROM users WHERE email = %s", (admin_email,))
        admin_id = cur.fetchone()[0]
        cur.execute("SELECT 1 FROM user_roles WHERE user_id = %s AND role_id = %s", (admin_id, super_admin_role_id))
        if not cur.fetchone():
            cur.execute("INSERT INTO user_roles (user_id, role_id) VALUES (%s, %s)", (admin_id, super_admin_role_id))

        insert_if_missing(cur, "markets", "code", "forex", {
            "id": str(uuid.uuid4()),
            "code": "forex",
            "name": "Forex",
            "asset_class": "forex",
            "timezone": "UTC",
            "status": "active",
        })
        insert_if_missing(cur, "markets", "code", "crypto", {
            "id": str(uuid.uuid4()),
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

        insert_if_missing(cur, "strategies", "code", "fx_ma_cross", {
            "id": str(uuid.uuid4()),
            "code": "fx_ma_cross",
            "name": "FX Moving Average Cross",
            "type": "trend_following",
            "owner_user_id": admin_id,
            "description": "Demo strategy",
            "status": "draft",
        })
        insert_if_missing(cur, "strategies", "code", "fx_mean_rev", {
            "id": str(uuid.uuid4()),
            "code": "fx_mean_rev",
            "name": "FX Mean Reversion",
            "type": "mean_reversion",
            "owner_user_id": admin_id,
            "description": "Demo strategy",
            "status": "draft",
        })

print("Seed complete.")
```

---

# 5. Python Dockerfile template

## `apps/<service>/Dockerfile`

```dockerfile
FROM python:3.12-slim
WORKDIR /workspace
COPY packages /workspace/packages
COPY apps/<service> /workspace/apps/<service>
COPY sql /workspace/sql
COPY seeds /workspace/seeds
COPY scripts /workspace/scripts
RUN pip install --no-cache-dir fastapi uvicorn sqlalchemy psycopg[binary] pydantic pydantic-settings passlib[bcrypt] email-validator httpx pyjwt
ENV PYTHONPATH=/workspace/packages:/workspace/apps/<service>
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

Use this for:
- identity-service
- market-registry-service
- instrument-master-service
- strategy-service
- order-service
- risk-service
- execution-service
- position-service
- audit-service
- broker-adapter-simulator

---

# 6. Vue root files

## `apps/web-admin/package.json`

```json
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

## `apps/web-admin/vite.config.ts`

```ts
import { defineConfig } from "vite"
import vue from "@vitejs/plugin-vue"
export default defineConfig({ plugins: [vue()] })
```

## `apps/web-admin/src/App.vue`

```vue
<template>
  <router-view />
</template>
```

## `apps/web-admin/src/main.ts`

```ts
import { createApp } from "vue"
import { createPinia } from "pinia"
import router from "./router"
import App from "./App.vue"

createApp(App).use(createPinia()).use(router).mount("#app")
```

## `apps/web-ops/package.json`

```json
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
```

## `apps/web-ops/vite.config.ts`

```ts
import { defineConfig } from "vite"
import vue from "@vitejs/plugin-vue"
export default defineConfig({ plugins: [vue()] })
```

## `apps/web-ops/src/App.vue`

```vue
<template>
  <router-view />
</template>
```

## `apps/web-ops/src/main.ts`

```ts
import { createApp } from "vue"
import { createPinia } from "pinia"
import router from "./router"
import App from "./App.vue"

createApp(App).use(createPinia()).use(router).mount("#app")
```

---

# 7. Final apply checklist

Apply in this order:
1. shared packages
2. SQL files
3. seed file
4. backend services
5. Python Dockerfiles
6. compose and Makefile
7. Vue files
8. scripts
9. run `make up`
10. run `make migrate`
11. run `make seed`
12. run `make smoke`

---

# 8. Immediate next artifact

The next useful artifact after this is a **compressed implementation manifest** that lists every path for the first slice and whether it is:
- create new
- replace placeholder
- update existing

That makes application of this pack faster and safer in the integrated repo.

