#!/usr/bin/env bash
set -euo pipefail
INSTRUMENT_ID=$(PGPASSWORD=docker-compose exec postgres psql -h localhost -U postgres -d trading_platform -t -A -c "SELECT id FROM instruments WHERE canonical_symbol='EURUSD' LIMIT 1;")
NOW=$(python - <<'PY'
from datetime import datetime, timedelta, timezone
now = datetime.now(timezone.utc)
print(now.isoformat())
PY
)
OPEN=$(python - <<'PY'
from datetime import datetime, timedelta, timezone
now = datetime.now(timezone.utc) - timedelta(minutes=1)
print(now.isoformat())
PY
)

curl -s -X POST http://localhost:8014/api/market-data/ingest-candle \
  -H "Content-Type: application/json" \
  -d "{\"instrument_id\":\"$INSTRUMENT_ID\",\"open_time\":\"$OPEN\",\"close_time\":\"$NOW\",\"open\":1.0800,\"high\":1.0860,\"low\":1.0790,\"close\":1.0850,\"volume\":1000,\"source\":\"demo-feed\"}"
echo
curl -s -X POST http://localhost:8015/api/features/seed-definitions
echo
