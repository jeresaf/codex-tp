#!/usr/bin/env bash
set -euo pipefail
for f in sql/001_core_identity.sql sql/002_markets_instruments.sql sql/003_strategies.sql sql/004_orders_risk.sql sql/005_positions_audit.sql \
         sql/006_hardening.sql \
         sql/007_event_driven.sql \
         sql/008_strategy_portfolio.sql \
         sql/009_market_data_features_research.sql \
         sql/010_risk_controls.sql \
         sql/011_execution_reconciliation.sql \
         sql/012_governance_workflows.sql; do
  echo "Applying $f"
  PGPASSWORD=docker-compose exec postgres psql -h localhost -U postgres -d trading_platform -f "$f"
done
