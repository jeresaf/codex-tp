#!/usr/bin/env bash
set -euo pipefail

ROOT="trading-platform"

mkdir -p "$ROOT"
cd "$ROOT"

mkdir -p \
  apps/{web-admin,web-ops,api-gateway,identity-service,tenant-service,workflow-service,audit-service,compliance-export-service,market-registry-service,instrument-master-service,market-data-service,feature-service,dataset-service,replay-service,strategy-service,strategy-runtime-service,signal-service,portfolio-service,allocation-service,alpha-service,model-registry-service,ml-service,backtest-service,paper-trading-service,risk-service,execution-service,order-service,position-service,reconciliation-service,notification-service,reporting-service,observability-service,broker-adapter-oanda,broker-adapter-binance,broker-adapter-interactivebrokers,broker-adapter-simulator} \
  packages/{shared-config,shared-db,shared-auth,shared-events,shared-domain,shared-market-data,shared-features,shared-risk,shared-portfolio,shared-execution,shared-governance,shared-observability,strategy-sdk,broker-sdk,backtest-sdk,ml-sdk,ui-kit} \
  schemas/{events,api,db,configs} \
  seeds \
  infra/docker/compose \
  infra/kubernetes/base \
  infra/kubernetes/overlays/{dev,staging,prod} \
  infra/{terraform,helm,redpanda,postgres,redis,minio,vault,ci} \
  infra/monitoring/{prometheus,grafana,loki,alertmanager} \
  scripts/{bootstrap,migrate,seed,backfill,replay,smoke,load,release} \
  docs/architecture \
  docs/{api,runbooks,playbooks,workflows,research,onboarding} \
  tests/{unit,integration,contract,e2e,simulation,performance,fixtures} \
  notebooks/{research,experiments,validation} \
  .github/workflows \
  sql

cat > README.md <<'EOF'
# Trading Platform

Integrated monorepo for a multi-market, multi-strategy, enterprise trading platform.

## Initial vertical slice
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

## Workspace layout
- `apps/` services and UIs
- `packages/` shared libraries and SDKs
- `sql/` database migrations
- `infra/` Docker, Kubernetes, monitoring, secrets, CI
- `docs/` architecture, workflows, runbooks
- `tests/` automated test suites
EOF

cat > CONTRIBUTING.md <<'EOF'
# Contributing

## Rules
- Keep domain logic out of transport layers.
- Use shared packages for common enums, schemas, math, and contracts.
- Every sensitive mutation must be auditable.
- Every event must include correlation metadata.
- Every service must expose health and readiness endpoints.
EOF

cat > Makefile <<'EOF'
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
EOF

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
  - packages/ui-kit
EOF

cat > scripts/migrate/run_all.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
for f in sql/*.sql; do
  echo "Applying $f"
done
EOF
chmod +x scripts/migrate/run_all.sh

cat > scripts/seed/run_all.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "Seed placeholder"
EOF
chmod +x scripts/seed/run_all.sh

cat > scripts/smoke/platform_smoke.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "Platform smoke placeholder"
EOF
chmod +x scripts/smoke/platform_smoke.sh

cat > docs/architecture/00-system-context.md <<'EOF'
# System Context

This platform supports multi-market, multi-strategy trading with strict risk, governance, observability, and execution controls.
EOF

cat > docs/architecture/01-service-map.md <<'EOF'
# Service Map

See repo structure document for control plane, market/research plane, strategy/portfolio plane, trading plane, and adapter plane responsibilities.
EOF

cat > docs/architecture/02-event-topology.md <<'EOF'
# Event Topology

Core topic families:
- market_data.*
- feature.*
- strategy.runtime.*
- strategy.signal.*
- portfolio.target.*
- order_intent.*
- risk.*
- execution.*
- position.*
- reconciliation.*
- workflow.*
- incident.*
- audit.*
- alert.*
- model.*
- alpha.*
EOF

cat > docs/architecture/03-data-model.md <<'EOF'
# Data Model

Migrations 001 through 015 define identity, markets, strategies, orders, hardening, events, runtime, data, risk, execution, governance, observability, tenancy, and alpha/ML layers.
EOF

for f in \
  001_core_identity.sql \
  002_markets_instruments.sql \
  003_strategies.sql \
  004_orders_risk.sql \
  005_positions_audit.sql \
  006_hardening.sql \
  007_event_driven.sql \
  008_strategy_portfolio.sql \
  009_market_data_features_research.sql \
  010_risk_controls.sql \
  011_execution_reconciliation.sql \
  012_governance_workflows.sql \
  013_observability.sql \
  014_multi_tenant.sql \
  015_alpha_ml.sql; do
  cat > "sql/$f" <<EOF
-- $f
-- placeholder migration
EOF
done

create_python_service() {
  local svc="$1"
  mkdir -p "apps/$svc/app/api/routes" "apps/$svc/app/config" "apps/$svc/app/db/models" \
           "apps/$svc/app/domain/services" "apps/$svc/app/use_cases" \
           "apps/$svc/app/integrations" "apps/$svc/app/events/{consumers,producers,outbox,inbox}" \
           "apps/$svc/app/observability" "apps/$svc/tests"

  cat > "apps/$svc/app/main.py" <<EOF
from fastapi import FastAPI

app = FastAPI(title="$svc", version="0.1.0")

@app.get("/health/live")
def health_live():
    return {"status": "ok", "service": "$svc"}

@app.get("/health/ready")
def health_ready():
    return {"status": "ready", "service": "$svc"}
EOF

  cat > "apps/$svc/Dockerfile" <<EOF
FROM python:3.12-slim
WORKDIR /workspace
COPY . /workspace
RUN pip install --no-cache-dir fastapi uvicorn
ENV PYTHONPATH=/workspace/packages:/workspace/apps/$svc
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

  cat > "apps/$svc/pyproject.toml" <<EOF
[project]
name = "$svc"
version = "0.1.0"
requires-python = ">=3.12"
EOF
}

for svc in \
  api-gateway identity-service tenant-service workflow-service audit-service compliance-export-service \
  market-registry-service instrument-master-service market-data-service feature-service dataset-service replay-service \
  strategy-service strategy-runtime-service signal-service portfolio-service allocation-service alpha-service \
  model-registry-service ml-service backtest-service paper-trading-service risk-service execution-service \
  order-service position-service reconciliation-service notification-service reporting-service observability-service \
  broker-adapter-oanda broker-adapter-binance broker-adapter-interactivebrokers broker-adapter-simulator; do
  create_python_service "$svc"
done

create_package() {
  local pkg="$1"
  local mod="${pkg//-/_}"
  mkdir -p "packages/$pkg/$mod"
  cat > "packages/$pkg/$mod/__init__.py" <<EOF
"""$pkg package."""
EOF
  cat > "packages/$pkg/pyproject.toml" <<EOF
[project]
name = "$pkg"
version = "0.1.0"
requires-python = ">=3.12"
EOF
}

for pkg in \
  shared-config shared-db shared-auth shared-events shared-domain shared-market-data shared-features \
  shared-risk shared-portfolio shared-execution shared-governance shared-observability \
  strategy-sdk broker-sdk backtest-sdk ml-sdk; do
  create_package "$pkg"
done

mkdir -p packages/ui-kit/src
cat > packages/ui-kit/package.json <<'EOF'
{
  "name": "@trading-platform/ui-kit",
  "version": "0.1.0",
  "private": true
}
EOF

create_vue_app() {
  local app="$1"
  mkdir -p "apps/$app/src" "apps/$app/src/{api,app,components,layouts,router,stores,views}"
  cat > "apps/$app/package.json" <<EOF
{
  "name": "$app",
  "private": true,
  "version": "0.1.0",
  "scripts": {
    "dev": "vite --host 0.0.0.0 --port 3000",
    "build": "vite build"
  },
  "dependencies": {
    "vue": "^3.5.13",
    "vue-router": "^4.5.0",
    "pinia": "^3.0.1",
    "axios": "^1.8.0"
  },
  "devDependencies": {
    "vite": "^6.1.0",
    "typescript": "^5.7.3",
    "@vitejs/plugin-vue": "^5.2.1"
  }
}
EOF
  cat > "apps/$app/src/App.vue" <<'EOF'
<template>
  <router-view />
</template>
EOF
  cat > "apps/$app/src/main.ts" <<'EOF'
import { createApp } from "vue"
import { createPinia } from "pinia"
import router from "./router"
import App from "./App.vue"

createApp(App).use(createPinia()).use(router).mount("#app")
EOF
  cat > "apps/$app/src/router/index.ts" <<'EOF'
import { createRouter, createWebHistory } from "vue-router"
export default createRouter({ history: createWebHistory(), routes: [] })
EOF
  cat > "apps/$app/vite.config.ts" <<'EOF'
import { defineConfig } from "vite"
import vue from "@vitejs/plugin-vue"
export default defineConfig({ plugins: [vue()] })
EOF
}

create_vue_app web-admin
create_vue_app web-ops

mkdir -p apps/web-admin/src/modules/{auth,tenants,users,roles,markets,venues,instruments,data-feeds,features,datasets,strategies,deployments,backtests,models,risk-policies,execution-policies,workflows,exceptions,incidents,compliance-exports,audit,observability,settings}
mkdir -p apps/web-ops/src/modules/{dashboard,runtime-health,signals,targets,orders,broker-orders,fills,positions,balances,exposures,breaches,kill-switches,reconciliation,feed-health,alerts,incidents,reports,traces}

cat > .github/workflows/ci.yml <<'EOF'
name: ci
on: [push, pull_request]
jobs:
  placeholder:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "Add service matrix, lint, test, contract, and integration jobs here"
EOF

echo "Scaffold created at $(pwd)"
