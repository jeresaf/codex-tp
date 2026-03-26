# Repo-Ready Patch Plan for the Vertical Slice

This patch plan maps the starter code into the integrated monorepo so you can apply it in a controlled order.

It covers:
- exact target files
- patch order
- minimum root config updates
- migration and seed sequence
- end-to-end smoke workflow

---

# 1. Apply order

Use this order to avoid dependency and import breakage.

## Step 1: shared packages
Create and populate:
- `packages/shared-config/shared_config/settings.py`
- `packages/shared-db/shared_db/database.py`
- `packages/shared-auth/shared_auth/jwt_tools.py`
- `packages/shared-domain/shared_domain/order_state.py`

Also add empty `__init__.py` files in each package module directory.

## Step 2: root migration and seed files
Populate:
- `sql/001_core_identity.sql`
- `sql/002_markets_instruments.sql`
- `sql/003_strategies.sql`
- `sql/004_orders_risk.sql`
- `sql/005_positions_audit.sql`
- `seeds/seed_core.py`

## Step 3: backend services
Populate in this order:
- `apps/identity-service`
- `apps/market-registry-service`
- `apps/instrument-master-service`
- `apps/strategy-service`
- `apps/audit-service`
- `apps/position-service`
- `apps/risk-service`
- `apps/execution-service`
- `apps/order-service`
- `apps/broker-adapter-simulator`

## Step 4: Dockerfiles and compose wiring
Update service Dockerfiles and root `docker-compose.yml`.

## Step 5: web apps
Populate:
- `apps/web-admin`
- `apps/web-ops`

## Step 6: scripts and smoke flow
Populate:
- `scripts/migrate/run_all.sh`
- `scripts/seed/run_all.sh`
- `scripts/smoke/platform_smoke.sh`

---

# 2. Exact target files by service

## 2.1 Shared packages

### `packages/shared-config/`
```text
packages/shared-config/
├─ pyproject.toml
└─ shared_config/
   ├─ __init__.py
   └─ settings.py
```

### `packages/shared-db/`
```text
packages/shared-db/
├─ pyproject.toml
└─ shared_db/
   ├─ __init__.py
   └─ database.py
```

### `packages/shared-auth/`
```text
packages/shared-auth/
├─ pyproject.toml
└─ shared_auth/
   ├─ __init__.py
   └─ jwt_tools.py
```

### `packages/shared-domain/`
```text
packages/shared-domain/
├─ pyproject.toml
└─ shared_domain/
   ├─ __init__.py
   └─ order_state.py
```

---

## 2.2 identity-service

```text
apps/identity-service/
├─ app/
│  ├─ api/
│  │  └─ routes/
│  │     └─ auth.py
│  ├─ db/
│  │  ├─ models.py
│  │  └─ session.py
│  ├─ config.py
│  └─ main.py
├─ Dockerfile
└─ pyproject.toml
```

Files to populate:
- `app/config.py`
- `app/db/models.py`
- `app/db/session.py`
- `app/api/routes/auth.py`
- `app/main.py`

---

## 2.3 market-registry-service

```text
apps/market-registry-service/
├─ app/
│  ├─ api/routes/markets.py
│  ├─ db/models.py
│  ├─ db/session.py
│  ├─ config.py
│  └─ main.py
├─ Dockerfile
└─ pyproject.toml
```

---

## 2.4 instrument-master-service

```text
apps/instrument-master-service/
├─ app/
│  ├─ api/routes/instruments.py
│  ├─ db/models.py
│  ├─ db/session.py
│  ├─ config.py
│  └─ main.py
├─ Dockerfile
└─ pyproject.toml
```

---

## 2.5 strategy-service

```text
apps/strategy-service/
├─ app/
│  ├─ api/routes/strategies.py
│  ├─ db/models.py
│  ├─ db/session.py
│  ├─ config.py
│  └─ main.py
├─ Dockerfile
└─ pyproject.toml
```

---

## 2.6 audit-service

```text
apps/audit-service/
├─ app/
│  ├─ api/routes/audit.py
│  ├─ db/models.py
│  ├─ db/session.py
│  ├─ config.py
│  └─ main.py
├─ Dockerfile
└─ pyproject.toml
```

---

## 2.7 position-service

```text
apps/position-service/
├─ app/
│  ├─ api/routes/positions.py
│  ├─ db/models.py
│  ├─ db/session.py
│  ├─ domain/position_math.py
│  ├─ config.py
│  └─ main.py
├─ Dockerfile
└─ pyproject.toml
```

---

## 2.8 risk-service

```text
apps/risk-service/
├─ app/
│  ├─ api/routes/risk.py
│  ├─ db/session.py
│  ├─ config.py
│  └─ main.py
├─ Dockerfile
└─ pyproject.toml
```

Note: for the first slice, `risk-service` does not need SQLAlchemy models yet if it is stateless for evaluation.

---

## 2.9 execution-service

```text
apps/execution-service/
├─ app/
│  ├─ api/routes/execution.py
│  ├─ db/models.py
│  ├─ db/session.py
│  ├─ config.py
│  └─ main.py
├─ Dockerfile
└─ pyproject.toml
```

---

## 2.10 order-service

```text
apps/order-service/
├─ app/
│  ├─ api/
│  │  ├─ routes/orders.py
│  │  └─ schemas.py
│  ├─ db/
│  │  ├─ models.py
│  │  └─ session.py
│  ├─ domain/state_machine.py
│  ├─ integrations/clients.py
│  ├─ config.py
│  └─ main.py
├─ Dockerfile
└─ pyproject.toml
```

---

## 2.11 broker-adapter-simulator

```text
apps/broker-adapter-simulator/
├─ app/main.py
├─ Dockerfile
└─ pyproject.toml
```

---

## 2.12 web-admin

```text
apps/web-admin/
├─ package.json
├─ vite.config.ts
└─ src/
   ├─ App.vue
   ├─ main.ts
   ├─ router/index.ts
   └─ views/
      ├─ LoginView.vue
      ├─ AdminLayout.vue
      ├─ MarketsView.vue
      ├─ InstrumentsView.vue
      ├─ StrategiesView.vue
      └─ AuditView.vue
```

---

## 2.13 web-ops

```text
apps/web-ops/
├─ package.json
├─ vite.config.ts
└─ src/
   ├─ App.vue
   ├─ main.ts
   ├─ router/index.ts
   └─ views/
      ├─ LoginView.vue
      ├─ OpsLayout.vue
      ├─ OrdersView.vue
      └─ PositionsView.vue
```

---

# 3. Root file changes

## 3.1 `docker-compose.yml`
Replace the placeholder root compose with a vertical-slice compose that includes:
- postgres
- redis
- redpanda
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
- web-admin
- web-ops

## 3.2 `Makefile`
Use these commands:

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

## 3.3 `pyproject.toml`
Make sure root tooling includes:
- pytest
- ruff
- mypy

## 3.4 `pnpm-workspace.yaml`
Must include:
- `apps/web-admin`
- `apps/web-ops`
- `packages/ui-kit`

---

# 4. SQL patch order

Apply these files in order:

1. `sql/001_core_identity.sql`
2. `sql/002_markets_instruments.sql`
3. `sql/003_strategies.sql`
4. `sql/004_orders_risk.sql`
5. `sql/005_positions_audit.sql`

## Required table coverage

### `001_core_identity.sql`
- users
- roles
- permissions
- role_permissions
- user_roles

### `002_markets_instruments.sql`
- markets
- venues
- instruments

### `003_strategies.sql`
- strategies
- strategy_versions
- strategy_deployments

### `004_orders_risk.sql`
- risk_policies
- order_intents
- broker_orders
- fills

### `005_positions_audit.sql`
- positions
- audit_events

---

# 5. Seed patch order

## `seeds/seed_core.py`
Populate with:
- admin user
- roles
- permissions
- forex and crypto markets
- oanda-demo and binance-testnet venues
- EURUSD / GBPUSD / USDJPY / XAUUSD instruments
- one or two demo strategies

## `scripts/seed/run_all.sh`
Use:

```bash
#!/usr/bin/env bash
set -euo pipefail
python seeds/seed_core.py
```

---

# 6. Dockerfile baseline for Python services

Use the same baseline for all first-slice backend services.

## Template

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

Replace `<service>` per app.

---

# 7. First exact compose ports

Use this port map for the slice:
- identity-service → `8001:8000`
- market-registry-service → `8002:8000`
- instrument-master-service → `8003:8000`
- strategy-service → `8004:8000`
- order-service → `8005:8000`
- risk-service → `8006:8000`
- execution-service → `8007:8000`
- position-service → `8008:8000`
- audit-service → `8009:8000`
- broker-adapter-simulator → `8010:8000`
- web-admin → `3000:3000`
- web-ops → `3001:3000`

---

# 8. Import and PYTHONPATH rules

To avoid early import errors:
- every Python service imports shared modules from `packages/`
- every service Dockerfile must set `PYTHONPATH=/workspace/packages:/workspace/apps/<service>`
- every package module directory must include `__init__.py`

---

# 9. Minimal backend contract checks

Before UI wiring, verify these endpoints:

- `GET http://localhost:8001/health/live`
- `POST http://localhost:8001/api/auth/login`
- `GET http://localhost:8002/api/markets`
- `GET http://localhost:8003/api/instruments`
- `GET http://localhost:8004/api/strategies`
- `GET http://localhost:8005/api/orders`
- `POST http://localhost:8005/api/orders/submit`
- `POST http://localhost:8006/api/risk/evaluate`
- `POST http://localhost:8007/api/execution/simulate`
- `GET http://localhost:8008/api/positions`
- `POST http://localhost:8008/api/positions/apply-fill`
- `GET http://localhost:8009/api/audit`
- `GET http://localhost:8010/api/simulator/status`

---

# 10. First smoke script to apply

## `scripts/smoke/platform_smoke.sh`

Use this flow:

1. check health endpoints
2. fetch seeded `EURUSD` instrument id from DB
3. fetch seeded `oanda-demo` venue id from DB
4. submit integrated order through `order-service`
5. verify positions endpoint returns updated position
6. verify audit endpoint returns workflow events

---

# 11. Expected first successful result

After patching and running:

## Admin UI
- login works
- markets page shows seeded rows
- instruments page shows seeded rows
- strategies page shows seeded rows
- audit page shows lifecycle events after order submission

## Ops UI
- order submit form works
- created order becomes `filled`
- positions page shows `EURUSD` position

## Services
- order-service orchestrates risk → execution → position → audit
- risk-service returns `pass` for normal quantity
- execution-service writes a simulated fill
- position-service updates net quantity and avg price
- audit-service records at least `order_intent.created` and `order_intent.filled`

---

# 12. Common failure points and fixes

## Import errors for shared packages
Fix:
- verify `PYTHONPATH`
- verify `__init__.py`

## Login fails
Fix:
- verify migrations ran
- verify seed script inserted `admin@example.com`
- verify bcrypt/passlib installed

## Order submit fails with 500
Fix:
- verify service names in `order-service` config match compose service names
- verify risk/execution/position/audit services are up

## Positions not updated
Fix:
- verify `position-service` endpoint URL in `order-service`
- verify fill price and quantity payload fields

## Audit empty
Fix:
- verify `audit-service` is reachable from `order-service`
- verify POST payload shape matches `AuditCreateRequest`

---

# 13. Recommended git commit plan

Use these commits:

1. `chore: add shared packages and base migrations`
2. `feat: add identity market instrument and strategy services`
3. `feat: add audit position risk execution and order services`
4. `feat: wire integrated order workflow`
5. `feat: add web-admin and web-ops starter apps`
6. `chore: add seed scripts smoke scripts and compose wiring`

This makes rollback and review easier.

---

# 14. Best next step after this patch plan

After this patch plan is applied, the next most useful artifact is a **copy-paste filesystem pack** that outputs the exact contents for:
- root `docker-compose.yml`
- root `Makefile`
- all five SQL migrations
- `seed_core.py`
- every Dockerfile for the first slice
- every service file in exact repo paths
- every Vue file in exact repo paths

That would let you build the initial integrated repo with almost no interpretation needed.

