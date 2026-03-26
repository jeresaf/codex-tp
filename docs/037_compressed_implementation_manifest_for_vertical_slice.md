# Compressed Implementation Manifest for the First Vertical Slice

This manifest is the shortest practical application map for the first working slice in the integrated monorepo.

Legend:
- **CREATE**: file or directory should be created fresh
- **REPLACE**: placeholder file should be replaced fully
- **UPDATE**: existing scaffold file should be edited/expanded

---

# 1. Root-level files

## Root configs
- `CREATE or REPLACE` `docker-compose.yml`
- `CREATE or REPLACE` `Makefile`
- `UPDATE` `pyproject.toml`
- `UPDATE` `pnpm-workspace.yaml`
- `UPDATE` `README.md`

## Root scripts
- `CREATE or REPLACE` `scripts/migrate/run_all.sh`
- `CREATE or REPLACE` `scripts/seed/run_all.sh`
- `CREATE or REPLACE` `scripts/smoke/platform_smoke.sh`

## SQL migrations
- `REPLACE` `sql/001_core_identity.sql`
- `REPLACE` `sql/002_markets_instruments.sql`
- `REPLACE` `sql/003_strategies.sql`
- `REPLACE` `sql/004_orders_risk.sql`
- `REPLACE` `sql/005_positions_audit.sql`

## Seed files
- `REPLACE` `seeds/seed_core.py`

---

# 2. Shared packages

## shared-config
- `CREATE` `packages/shared-config/shared_config/__init__.py`
- `REPLACE` `packages/shared-config/shared_config/settings.py`
- `UPDATE` `packages/shared-config/pyproject.toml`

## shared-db
- `CREATE` `packages/shared-db/shared_db/__init__.py`
- `REPLACE` `packages/shared-db/shared_db/database.py`
- `UPDATE` `packages/shared-db/pyproject.toml`

## shared-auth
- `CREATE` `packages/shared-auth/shared_auth/__init__.py`
- `REPLACE` `packages/shared-auth/shared_auth/jwt_tools.py`
- `UPDATE` `packages/shared-auth/pyproject.toml`

## shared-domain
- `CREATE` `packages/shared-domain/shared_domain/__init__.py`
- `REPLACE` `packages/shared-domain/shared_domain/order_state.py`
- `UPDATE` `packages/shared-domain/pyproject.toml`

---

# 3. Backend services

## identity-service
- `UPDATE` `apps/identity-service/Dockerfile`
- `UPDATE` `apps/identity-service/pyproject.toml`
- `REPLACE` `apps/identity-service/app/config.py`
- `CREATE` `apps/identity-service/app/db/session.py`
- `REPLACE` `apps/identity-service/app/db/models.py`
- `REPLACE` `apps/identity-service/app/api/routes/auth.py`
- `REPLACE` `apps/identity-service/app/main.py`

## market-registry-service
- `UPDATE` `apps/market-registry-service/Dockerfile`
- `UPDATE` `apps/market-registry-service/pyproject.toml`
- `REPLACE` `apps/market-registry-service/app/config.py`
- `CREATE` `apps/market-registry-service/app/db/session.py`
- `REPLACE` `apps/market-registry-service/app/db/models.py`
- `REPLACE` `apps/market-registry-service/app/api/routes/markets.py`
- `REPLACE` `apps/market-registry-service/app/main.py`

## instrument-master-service
- `UPDATE` `apps/instrument-master-service/Dockerfile`
- `UPDATE` `apps/instrument-master-service/pyproject.toml`
- `REPLACE` `apps/instrument-master-service/app/config.py`
- `CREATE` `apps/instrument-master-service/app/db/session.py`
- `REPLACE` `apps/instrument-master-service/app/db/models.py`
- `REPLACE` `apps/instrument-master-service/app/api/routes/instruments.py`
- `REPLACE` `apps/instrument-master-service/app/main.py`

## strategy-service
- `UPDATE` `apps/strategy-service/Dockerfile`
- `UPDATE` `apps/strategy-service/pyproject.toml`
- `REPLACE` `apps/strategy-service/app/config.py`
- `CREATE` `apps/strategy-service/app/db/session.py`
- `REPLACE` `apps/strategy-service/app/db/models.py`
- `REPLACE` `apps/strategy-service/app/api/routes/strategies.py`
- `REPLACE` `apps/strategy-service/app/main.py`

## audit-service
- `UPDATE` `apps/audit-service/Dockerfile`
- `UPDATE` `apps/audit-service/pyproject.toml`
- `REPLACE` `apps/audit-service/app/config.py`
- `CREATE` `apps/audit-service/app/db/session.py`
- `REPLACE` `apps/audit-service/app/db/models.py`
- `REPLACE` `apps/audit-service/app/api/routes/audit.py`
- `REPLACE` `apps/audit-service/app/main.py`

## position-service
- `UPDATE` `apps/position-service/Dockerfile`
- `UPDATE` `apps/position-service/pyproject.toml`
- `REPLACE` `apps/position-service/app/config.py`
- `CREATE` `apps/position-service/app/db/session.py`
- `REPLACE` `apps/position-service/app/db/models.py`
- `REPLACE` `apps/position-service/app/domain/position_math.py`
- `REPLACE` `apps/position-service/app/api/routes/positions.py`
- `REPLACE` `apps/position-service/app/main.py`

## risk-service
- `UPDATE` `apps/risk-service/Dockerfile`
- `UPDATE` `apps/risk-service/pyproject.toml`
- `REPLACE` `apps/risk-service/app/config.py`
- `CREATE` `apps/risk-service/app/db/session.py`
- `REPLACE` `apps/risk-service/app/api/routes/risk.py`
- `REPLACE` `apps/risk-service/app/main.py`

## execution-service
- `UPDATE` `apps/execution-service/Dockerfile`
- `UPDATE` `apps/execution-service/pyproject.toml`
- `REPLACE` `apps/execution-service/app/config.py`
- `CREATE` `apps/execution-service/app/db/session.py`
- `REPLACE` `apps/execution-service/app/db/models.py`
- `REPLACE` `apps/execution-service/app/api/routes/execution.py`
- `REPLACE` `apps/execution-service/app/main.py`

## order-service
- `UPDATE` `apps/order-service/Dockerfile`
- `UPDATE` `apps/order-service/pyproject.toml`
- `REPLACE` `apps/order-service/app/config.py`
- `CREATE` `apps/order-service/app/db/session.py`
- `REPLACE` `apps/order-service/app/db/models.py`
- `REPLACE` `apps/order-service/app/domain/state_machine.py`
- `REPLACE` `apps/order-service/app/integrations/clients.py`
- `REPLACE` `apps/order-service/app/api/schemas.py`
- `REPLACE` `apps/order-service/app/api/routes/orders.py`
- `REPLACE` `apps/order-service/app/main.py`

## broker-adapter-simulator
- `UPDATE` `apps/broker-adapter-simulator/Dockerfile`
- `UPDATE` `apps/broker-adapter-simulator/pyproject.toml`
- `REPLACE` `apps/broker-adapter-simulator/app/main.py`

---

# 4. Frontend apps

## web-admin
- `UPDATE` `apps/web-admin/package.json`
- `UPDATE` `apps/web-admin/vite.config.ts`
- `REPLACE` `apps/web-admin/src/App.vue`
- `REPLACE` `apps/web-admin/src/main.ts`
- `REPLACE` `apps/web-admin/src/router/index.ts`
- `REPLACE` `apps/web-admin/src/views/LoginView.vue`
- `REPLACE` `apps/web-admin/src/views/AdminLayout.vue`
- `REPLACE` `apps/web-admin/src/views/MarketsView.vue`
- `REPLACE` `apps/web-admin/src/views/InstrumentsView.vue`
- `REPLACE` `apps/web-admin/src/views/StrategiesView.vue`
- `REPLACE` `apps/web-admin/src/views/AuditView.vue`

## web-ops
- `UPDATE` `apps/web-ops/package.json`
- `UPDATE` `apps/web-ops/vite.config.ts`
- `REPLACE` `apps/web-ops/src/App.vue`
- `REPLACE` `apps/web-ops/src/main.ts`
- `REPLACE` `apps/web-ops/src/router/index.ts`
- `REPLACE` `apps/web-ops/src/views/LoginView.vue` if shared auth UI is desired, otherwise `CREATE`
- `REPLACE` `apps/web-ops/src/views/OpsLayout.vue`
- `REPLACE` `apps/web-ops/src/views/OrdersView.vue`
- `REPLACE` `apps/web-ops/src/views/PositionsView.vue`

---

# 5. Minimal dependency checklist

## Python packages required in first slice
All first-slice Python service Dockerfiles should install:
- `fastapi`
- `uvicorn`
- `sqlalchemy`
- `psycopg[binary]`
- `pydantic`
- `pydantic-settings`
- `passlib[bcrypt]`
- `email-validator`
- `httpx`
- `pyjwt`

## Frontend packages required
Both Vue apps should include:
- `vue`
- `vue-router`
- `pinia`
- `axios`
- `vite`
- `typescript`
- `@vitejs/plugin-vue`

---

# 6. Runtime application sequence

Run in this order:

1. `make up`
2. `make migrate`
3. `make seed`
4. open admin UI at `http://localhost:3000`
5. open ops UI at `http://localhost:3001`
6. `make smoke`

---

# 7. Verification matrix

## Backend verification
- `identity-service` login returns JWT
- `market-registry-service` returns seeded markets
- `instrument-master-service` returns seeded instruments
- `strategy-service` returns seeded strategies
- `order-service` integrated submit returns `filled`
- `risk-service` returns `pass` for standard quantity
- `execution-service` writes simulated fill
- `position-service` reflects updated EURUSD position
- `audit-service` records order lifecycle events
- `broker-adapter-simulator` returns healthy status

## Frontend verification
- admin login works
- admin markets/instruments/strategies/audit pages render
- ops order submit form works
- ops positions page updates after submission

---

# 8. Fastest safe application strategy

If applying this manually, do it in four chunks:

## Chunk A
Shared packages + SQL + seed

## Chunk B
All backend services + Dockerfiles

## Chunk C
Root compose/scripts/Makefile

## Chunk D
Web admin + web ops

This reduces debugging surface area.

---

# 9. Immediate next artifact

The next strongest artifact is a **single-shell bootstrap writer** that writes all first-slice files directly into the integrated repo from one script, so you can generate the full vertical slice in one pass.

