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
