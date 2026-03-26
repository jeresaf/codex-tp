# Integrated Repo Structure for the 15-Volume Trading Platform

## Root

```text
trading-platform/
├─ apps/
│  ├─ web-admin/
│  ├─ web-ops/
│  ├─ api-gateway/
│  ├─ identity-service/
│  ├─ tenant-service/
│  ├─ workflow-service/
│  ├─ audit-service/
│  ├─ compliance-export-service/
│  ├─ market-registry-service/
│  ├─ instrument-master-service/
│  ├─ market-data-service/
│  ├─ feature-service/
│  ├─ dataset-service/
│  ├─ replay-service/
│  ├─ strategy-service/
│  ├─ strategy-runtime-service/
│  ├─ signal-service/
│  ├─ portfolio-service/
│  ├─ allocation-service/
│  ├─ alpha-service/
│  ├─ model-registry-service/
│  ├─ ml-service/
│  ├─ backtest-service/
│  ├─ paper-trading-service/
│  ├─ risk-service/
│  ├─ execution-service/
│  ├─ order-service/
│  ├─ position-service/
│  ├─ reconciliation-service/
│  ├─ notification-service/
│  ├─ reporting-service/
│  ├─ observability-service/
│  ├─ broker-adapter-oanda/
│  ├─ broker-adapter-binance/
│  ├─ broker-adapter-interactivebrokers/
│  └─ broker-adapter-simulator/
│
├─ packages/
│  ├─ shared-config/
│  ├─ shared-db/
│  ├─ shared-auth/
│  ├─ shared-events/
│  ├─ shared-domain/
│  ├─ shared-market-data/
│  ├─ shared-features/
│  ├─ shared-risk/
│  ├─ shared-portfolio/
│  ├─ shared-execution/
│  ├─ shared-governance/
│  ├─ shared-observability/
│  ├─ strategy-sdk/
│  ├─ broker-sdk/
│  ├─ backtest-sdk/
│  ├─ ml-sdk/
│  └─ ui-kit/
│
├─ schemas/
│  ├─ events/
│  ├─ api/
│  ├─ db/
│  └─ configs/
│
├─ sql/
│  ├─ 001_core_identity.sql
│  ├─ 002_markets_instruments.sql
│  ├─ 003_strategies.sql
│  ├─ 004_orders_risk.sql
│  ├─ 005_positions_audit.sql
│  ├─ 006_hardening.sql
│  ├─ 007_event_driven.sql
│  ├─ 008_strategy_portfolio.sql
│  ├─ 009_market_data_features_research.sql
│  ├─ 010_risk_controls.sql
│  ├─ 011_execution_reconciliation.sql
│  ├─ 012_governance_workflows.sql
│  ├─ 013_observability.sql
│  ├─ 014_multi_tenant.sql
│  └─ 015_alpha_ml.sql
│
├─ seeds/
│  ├─ seed_core.py
│  ├─ seed_reference_data.py
│  ├─ seed_demo_tenants.py
│  ├─ seed_demo_users.py
│  ├─ seed_demo_policies.py
│  └─ seed_demo_strategies.py
│
├─ infra/
│  ├─ docker/
│  │  ├─ base-python.Dockerfile
│  │  ├─ base-node.Dockerfile
│  │  └─ compose/
│  ├─ kubernetes/
│  │  ├─ base/
│  │  ├─ overlays/dev/
│  │  ├─ overlays/staging/
│  │  └─ overlays/prod/
│  ├─ terraform/
│  ├─ helm/
│  ├─ monitoring/
│  │  ├─ prometheus/
│  │  ├─ grafana/
│  │  ├─ loki/
│  │  └─ alertmanager/
│  ├─ redpanda/
│  ├─ postgres/
│  ├─ redis/
│  ├─ minio/
│  ├─ vault/
│  └─ ci/
│
├─ scripts/
│  ├─ bootstrap/
│  ├─ migrate/
│  ├─ seed/
│  ├─ backfill/
│  ├─ replay/
│  ├─ smoke/
│  ├─ load/
│  └─ release/
│
├─ docs/
│  ├─ architecture/
│  │  ├─ 00-system-context.md
│  │  ├─ 01-service-map.md
│  │  ├─ 02-event-topology.md
│  │  ├─ 03-data-model.md
│  │  ├─ 04-runtime-and-portfolio.md
│  │  ├─ 05-risk-and-controls.md
│  │  ├─ 06-execution-and-reconciliation.md
│  │  ├─ 07-governance-and-workflows.md
│  │  ├─ 08-observability-and-sre.md
│  │  ├─ 09-scaling-and-multi-tenancy.md
│  │  └─ 10-alpha-and-ml.md
│  ├─ api/
│  ├─ runbooks/
│  ├─ playbooks/
│  ├─ workflows/
│  ├─ research/
│  └─ onboarding/
│
├─ tests/
│  ├─ unit/
│  ├─ integration/
│  ├─ contract/
│  ├─ e2e/
│  ├─ simulation/
│  ├─ performance/
│  └─ fixtures/
│
├─ notebooks/
│  ├─ research/
│  ├─ experiments/
│  └─ validation/
│
├─ .github/
│  └─ workflows/
├─ Makefile
├─ docker-compose.yml
├─ pyproject.toml
├─ pnpm-workspace.yaml
├─ README.md
└─ CONTRIBUTING.md
```

## apps/ responsibilities

### Control plane
- `api-gateway`: external entrypoint, auth handoff, route aggregation
- `identity-service`: auth, users, roles, tenant membership
- `tenant-service`: tenant lifecycle and cross-tenant controls
- `workflow-service`: approvals, maker-checker, governed changes
- `audit-service`: immutable audit trail and resource timelines
- `compliance-export-service`: evidence packs and export jobs

### Market and research plane
- `market-registry-service`: markets, venues, calendars, session rules
- `instrument-master-service`: canonical instruments and symbol mappings
- `market-data-service`: raw + normalized ingestion, feed health
- `feature-service`: batch and streaming feature computation
- `dataset-service`: dataset versions, manifests, reproducible research inputs
- `replay-service`: historical and incident replay jobs
- `backtest-service`: historical simulation and validation
- `paper-trading-service`: paper execution path and shadow workflows

### Strategy and portfolio plane
- `strategy-service`: strategy metadata, versions, deployments
- `strategy-runtime-service`: isolated strategy workers, runtime heartbeats
- `signal-service`: signal persistence and signal read APIs
- `portfolio-service`: signal aggregation, target generation, conflict resolution
- `allocation-service`: capital budgets, weights, sleeve allocations
- `alpha-service`: scoring, blending, signal weighting, dynamic alpha logic
- `model-registry-service`: model versions, metrics, approvals
- `ml-service`: training, inference, drift checks, retraining jobs

### Trading plane
- `risk-service`: pre-trade, post-trade, continuous risk, kill switches
- `order-service`: order intent lifecycle, state history, order projections
- `execution-service`: execution routing, broker lifecycle, quality metrics
- `position-service`: incremental fills, balances, P&L, exposure state
- `reconciliation-service`: broker vs internal reconciliation and issue workflows
- `notification-service`: alerts, workflow notifications, incident notifications
- `reporting-service`: dashboards, reports, investor/ops/risk summaries
- `observability-service`: internal telemetry aggregation and operational read APIs

### Venue adapters
- `broker-adapter-oanda`
- `broker-adapter-binance`
- `broker-adapter-interactivebrokers`
- `broker-adapter-simulator`

## packages/ responsibilities

### Core platform shared packages
- `shared-config`: service settings and environment configuration
- `shared-db`: DB engine/session helpers, base models, migration helpers
- `shared-auth`: JWT and internal service auth utilities
- `shared-events`: event envelope, outbox/inbox helpers, publisher/consumer contracts
- `shared-domain`: shared enums, value objects, canonical entities

### Trading shared packages
- `shared-market-data`: canonical tick/candle schemas, session utilities
- `shared-features`: indicator and feature implementations used in research and runtime
- `shared-risk`: rule evaluators, exposure math, drawdown and daily-loss calculations
- `shared-portfolio`: allocation math, target sizing, correlation-aware helpers
- `shared-execution`: execution quality math, slippage/fee calculations, state machines
- `shared-governance`: workflow models, approval validation, exception expiry logic
- `shared-observability`: logging, metrics, tracing helpers

### SDKs
- `strategy-sdk`: plugin contracts and runtime contracts for strategies
- `broker-sdk`: canonical adapter contracts and normalized broker models
- `backtest-sdk`: replay helpers, execution assumptions, test harnesses
- `ml-sdk`: feature pipelines, model wrappers, registry helpers
- `ui-kit`: shared Vue components, layout primitives, tables, filters, badges

## web-admin high-level module map

```text
apps/web-admin/src/
├─ api/
├─ app/
├─ components/
├─ layouts/
├─ router/
├─ stores/
├─ modules/
│  ├─ auth/
│  ├─ tenants/
│  ├─ users/
│  ├─ roles/
│  ├─ markets/
│  ├─ venues/
│  ├─ instruments/
│  ├─ data-feeds/
│  ├─ features/
│  ├─ datasets/
│  ├─ strategies/
│  ├─ deployments/
│  ├─ backtests/
│  ├─ models/
│  ├─ risk-policies/
│  ├─ execution-policies/
│  ├─ workflows/
│  ├─ exceptions/
│  ├─ incidents/
│  ├─ compliance-exports/
│  ├─ audit/
│  ├─ observability/
│  └─ settings/
└─ views/
```

## web-ops high-level module map

```text
apps/web-ops/src/
├─ api/
├─ app/
├─ components/
├─ layouts/
├─ router/
├─ stores/
├─ modules/
│  ├─ dashboard/
│  ├─ runtime-health/
│  ├─ signals/
│  ├─ targets/
│  ├─ orders/
│  ├─ broker-orders/
│  ├─ fills/
│  ├─ positions/
│  ├─ balances/
│  ├─ exposures/
│  ├─ breaches/
│  ├─ kill-switches/
│  ├─ reconciliation/
│  ├─ feed-health/
│  ├─ alerts/
│  ├─ incidents/
│  ├─ reports/
│  └─ traces/
└─ views/
```

## Recommended service internals template

```text
apps/<service>/
├─ app/
│  ├─ api/
│  │  ├─ routes/
│  │  ├─ schemas/
│  │  └─ deps/
│  ├─ config/
│  ├─ db/
│  │  ├─ models/
│  │  ├─ repositories/
│  │  └─ session.py
│  ├─ domain/
│  │  ├─ entities/
│  │  ├─ services/
│  │  ├─ policies/
│  │  ├─ state_machines/
│  │  └─ value_objects/
│  ├─ use_cases/
│  ├─ integrations/
│  ├─ events/
│  │  ├─ consumers/
│  │  ├─ producers/
│  │  ├─ outbox/
│  │  └─ inbox/
│  ├─ jobs/
│  ├─ observability/
│  └─ main.py
├─ tests/
├─ Dockerfile
└─ pyproject.toml
```

## Data and topic ownership summary

### Services that own transactional state
- `identity-service`: users, roles, memberships
- `tenant-service`: tenants
- `strategy-service`: strategies, versions, deployments
- `signal-service`: signals
- `portfolio-service`: targets
- `risk-service`: evaluations, breaches, kill switches, exposures
- `order-service`: order intents and state history
- `execution-service`: broker orders and execution quality
- `position-service`: positions, balances, P&L snapshots
- `reconciliation-service`: runs and issues
- `workflow-service`: requests, steps, approvals, exceptions
- `audit-service`: audit log and timeline projections
- `dataset-service`: dataset versions and replay requests
- `feature-service`: feature definitions and feature values
- `model-registry-service`: models and approval metadata

### Core topic families
- `market_data.*`
- `feature.*`
- `dataset.*`
- `strategy.runtime.*`
- `strategy.signal.*`
- `portfolio.target.*`
- `order_intent.*`
- `risk.*`
- `execution.*`
- `position.*`
- `reconciliation.*`
- `workflow.*`
- `incident.*`
- `audit.*`
- `alert.*`
- `model.*`
- `alpha.*`

## Phase-aligned implementation inside this single repo

### Phase 1: platform skeleton
Implement first:
- web-admin
- web-ops
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
- shared core packages
- first 5 SQL migrations

### Phase 2: hardening and events
Add:
- workflow-service
- outbox/inbox patterns
- correlation IDs
- state history
- risk evaluation persistence
- event-driven pipelines
- migration 006 and 007

### Phase 3: runtime and portfolio
Add:
- strategy-runtime-service
- signal-service
- portfolio-service
- allocation-service
- migration 008

### Phase 4: data, research, and replay
Add:
- market-data-service
- feature-service
- dataset-service
- replay-service
- backtest-service
- migration 009

### Phase 5: enterprise controls
Add:
- expanded risk-service controls
- reconciliation-service
- compliance-export-service
- incidents and exceptions in workflow-service
- migrations 010, 011, 012

### Phase 6: operations, scale, and alpha
Add:
- observability-service
- tenant-service
- model-registry-service
- ml-service
- alpha-service
- migrations 013, 014, 015

## Recommended root-level workspace conventions

### Python
- one `pyproject.toml` at root for shared tooling
- per-service `pyproject.toml` only if needed for isolation
- Ruff, pytest, mypy configured centrally

### Frontend
- `pnpm-workspace.yaml`
- shared TS config
- shared ESLint/Prettier config
- shared UI package

### CI
- service matrix builds
- shared package tests first
- contract tests on event schemas
- integration tests with compose profile
- deployment manifests versioned in `infra/`

## Suggested root README sections
- platform purpose
- architecture summary
- local setup
- services list
- event model
- environment matrix
- migration and seed process
- testing strategy
- deployment overview
- contribution standards

## Immediate next build target inside this integrated repo

Build this first working vertical slice inside the unified structure:
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
- shared core packages
- SQL 001–005

That slice gives you a coherent base to expand into the rest of the repo without restructuring later.

