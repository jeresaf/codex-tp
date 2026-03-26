#!/usr/bin/env bash
set -euo pipefail
TOKEN=$(curl -s -X POST http://localhost:8001/api/auth/login -H "Content-Type: application/json" -d '{"email":"admin@example.com","password":"admin123"}' | python -c 'import sys,json; print(json.load(sys.stdin)["access_token"])')
INSTRUMENT_ID=$(PGPASSWORD=docker-compose exec postgres psql -h localhost -U postgres -d trading_platform -t -A -c "SELECT id FROM instruments WHERE canonical_symbol='EURUSD' LIMIT 1;")
CORR_ID=$(python - <<'PY'
import uuid
print(uuid.uuid4())
PY
)

curl -s -X POST http://localhost:8011/api/runtime/run-sample \
  -H "Content-Type: application/json" \
  -d "{\"strategy_deployment_id\":\"00000000-0000-0000-0000-000000000001\",\"strategy_version_id\":null,\"correlation_id\":\"$CORR_ID\",\"candle\":{\"instrument_id\":\"$INSTRUMENT_ID\",\"open\":1.0800,\"close\":1.0850}}"
echo
