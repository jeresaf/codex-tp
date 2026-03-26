#!/usr/bin/env bash
set -euo pipefail
curl -s http://localhost:8001/health/live >/dev/null
curl -s http://localhost:8002/health/live >/dev/null
curl -s http://localhost:8003/health/live >/dev/null
curl -s http://localhost:8004/health/live >/dev/null
curl -s http://localhost:8005/health/live >/dev/null
curl -s http://localhost:8006/health/live >/dev/null
curl -s http://localhost:8007/health/live >/dev/null
curl -s http://localhost:8008/health/live >/dev/null
curl -s http://localhost:8009/health/live >/dev/null
INSTRUMENT_ID=$(PGPASSWORD=docker-compose exec postgres psql -h localhost -U postgres -d trading_platform -t -A -c "SELECT id FROM instruments WHERE canonical_symbol='EURUSD' LIMIT 1;")
VENUE_ID=$(PGPASSWORD=docker-compose exec postgres psql -h localhost -U postgres -d trading_platform -t -A -c "SELECT id FROM venues WHERE code='oanda-demo' LIMIT 1;")
curl -s -X POST http://localhost:8005/api/orders/submit -H "Content-Type: application/json" -d "{\"instrument_id\":\"$INSTRUMENT_ID\",\"side\":\"buy\",\"order_type\":\"market\",\"quantity\":\"1000\",\"tif\":\"IOC\",\"venue_id\":\"$VENUE_ID\",\"execution_price\":\"1.0850\"}"
echo
curl -s http://localhost:8008/api/positions
echo
curl -s http://localhost:8009/api/audit
echo
