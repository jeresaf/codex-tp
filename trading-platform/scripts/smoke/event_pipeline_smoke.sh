#!/usr/bin/env bash
set -euo pipefail
TOKEN=$(curl -s -X POST http://localhost:8001/api/auth/login -H "Content-Type: application/json" -d '{"email":"admin@example.com","password":"admin123"}' | python -c 'import sys,json; print(json.load(sys.stdin)["access_token"])')
INSTRUMENT_ID=$(PGPASSWORD=docker-compose exec postgres psql -h localhost -U postgres -d trading_platform -t -A -c "SELECT id FROM instruments WHERE canonical_symbol='EURUSD' LIMIT 1;")
VENUE_ID=$(PGPASSWORD=docker-compose exec postgres psql -h localhost -U postgres -d trading_platform -t -A -c "SELECT id FROM venues WHERE code='oanda-demo' LIMIT 1;")
curl -s -X POST http://localhost:8005/api/orders/submit \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: event-smoke-1" \
  -d "{\"instrument_id\":\"$INSTRUMENT_ID\",\"side\":\"buy\",\"order_type\":\"market\",\"quantity\":\"1000\",\"tif\":\"IOC\",\"venue_id\":\"$VENUE_ID\",\"execution_price\":\"1.0850\"}"
echo
