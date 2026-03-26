# Full End-to-End Manual QA Walkthrough

This walkthrough validates the current platform in the best testing order, from infrastructure to UI.

It is designed to help you evaluate what already works, isolate failures quickly, and avoid testing later modules before prerequisites are healthy.

---

# 1. Pre-flight

## 1.1 Expected running services

Backend and infra:
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
- strategy-runtime-service
- signal-service
- portfolio-service
- market-data-service
- feature-service
- dataset-service
- replay-service
- reconciliation-service
- workflow-service
- compliance-service

Frontend:
- web-admin
- web-ops

## 1.2 Start sequence

```bash
make up
bash scripts/migrate/run_all.sh
bash scripts/seed/run_all.sh
```

Then start or restart the UIs:

```bash
docker-compose build web-admin web-ops
docker-compose up -d web-admin web-ops
```

---

# 2. Infrastructure health checks

Open these in a browser or curl them.

## 2.1 Core health endpoints
- `http://localhost:8001/health/live`
- `http://localhost:8002/health/live`
- `http://localhost:8003/health/live`
- `http://localhost:8004/health/live`
- `http://localhost:8005/health/live`
- `http://localhost:8006/health/live`
- `http://localhost:8007/health/live`
- `http://localhost:8008/health/live`
- `http://localhost:8009/health/live`
- `http://localhost:8010/health/live`
- `http://localhost:8011/health/live`
- `http://localhost:8012/health/live`
- `http://localhost:8013/health/live`
- `http://localhost:8014/health/live`
- `http://localhost:8015/health/live`
- `http://localhost:8016/health/live`
- `http://localhost:8017/health/live`
- `http://localhost:8018/health/live`
- `http://localhost:8019/health/live`
- `http://localhost:8020/health/live`

Expected:
- every endpoint returns JSON with `status: ok` or equivalent
- no 500s

If any fail:
- check `docker-compose logs <service>`
- fix that service before continuing

---

# 3. Database seed verification

Use psql or any DB client.

## 3.1 Users
Verify these exist:
- `admin@example.com`
- optional: `ops@example.com`
- optional: `risk@example.com`
- optional: `compliance@example.com`

## 3.2 Markets
Expected:
- `forex`
- `crypto`

## 3.3 Venues
Expected:
- `oanda-demo`
- `binance-testnet`

## 3.4 Instruments
Expected:
- `EURUSD`
- `GBPUSD`
- `USDJPY`
- `XAUUSD`

## 3.5 Strategies
Expected:
- `fx_ma_cross`
- `fx_mean_rev`

If these are missing, rerun seed and inspect seed errors.

---

# 4. Identity and auth QA

## 4.1 Admin login API
Call:

```bash
curl -X POST http://localhost:8001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"admin"}'
```

Expected:
- 200 response
- `access_token`
- `user`
- `roles`
- `permissions`

Failure meaning:
- password mismatch → seed mismatch
- user missing → seed issue
- 500 → passlib/bcrypt/config issue

---

# 5. Reference data QA

## 5.1 Markets API
`GET http://localhost:8002/api/markets`

Expected:
- seeded markets appear

## 5.2 Instruments API
`GET http://localhost:8003/api/instruments`

Expected:
- seeded instruments appear

## 5.3 Strategies API
`GET http://localhost:8004/api/strategies`

Expected:
- seeded strategies appear

These must all work before UI reference-data testing.

---

# 6. Admin UI QA

Open:
- `http://localhost:3000/login`

Login with:
- email: `admin@example.com`
- password: `admin`

## 6.1 Login page
Expected:
- page loads
- submitting valid credentials redirects to `/dashboard`
- invalid credentials show error

## 6.2 Dashboard
Expected:
- cards for markets, instruments, strategies
- counts are not zero if seed succeeded

## 6.3 Markets page
Expected:
- Forex and Crypto visible

## 6.4 Instruments page
Expected:
- EURUSD, GBPUSD, USDJPY, XAUUSD visible

## 6.5 Strategies page
Expected:
- fx_ma_cross and fx_mean_rev visible

## 6.6 Audit page
Expected:
- may be empty initially
- later should populate after order activity

## 6.7 Workflows page
Action:
- click create demo workflow
- click start demo run

Expected:
- API response shows created IDs
- no console errors

## 6.8 Compliance exports page
Action:
- click create export

Expected:
- export row appears
- status shown as pending or current backend status

If admin UI fails to load data:
- verify service endpoint manually first
- inspect browser console/network tab

---

# 7. Market data QA

## 7.1 Ingest a demo candle
Run the smoke script or direct API call.

Script:

```bash
bash scripts/smoke/data_feature_replay_smoke.sh
```

Or direct call to:
- `POST http://localhost:8014/api/market-data/ingest-candle`

Expected:
- raw event stored
- normalized candle stored
- response contains IDs

## 7.2 Read candles
`GET http://localhost:8014/api/market-data/candles`

Expected:
- newly inserted candle visible
- OHLC values match payload

Failure meaning:
- normalization/model/migration problem

---

# 8. Feature store QA

## 8.1 Seed feature definitions
`POST http://localhost:8015/api/features/seed-definitions`

Expected:
- `SMA_20`
- `SMA_50`

## 8.2 Read definitions
`GET http://localhost:8015/api/features/definitions`

Expected:
- SMA rows visible

## 8.3 Backfill features
Use enough candle history for warmup, or accept that short history may produce no values.

Expected:
- if enough candles exist, feature values are written

## 8.4 Read values
`GET http://localhost:8015/api/features/values`

Expected:
- values visible once warmup is satisfied

Important:
- with only 1 candle, SMA 20/50 will correctly produce no values
- this is not a bug

---

# 9. Dataset and replay QA

## 9.1 Create dataset version
`POST http://localhost:8016/api/datasets`

Expected:
- dataset version ID returned

## 9.2 Read dataset versions
`GET http://localhost:8016/api/datasets`

Expected:
- dataset row visible

## 9.3 Create replay job
`POST http://localhost:8017/api/replay/jobs`

Expected:
- replay job ID
- queued status

## 9.4 Read replay jobs
`GET http://localhost:8017/api/replay/jobs`

Expected:
- row visible

---

# 10. Strategy runtime QA

## 10.1 Run sample runtime worker
Use:
- `POST http://localhost:8011/api/runtime/run-sample`

Payload needs:
- `strategy_deployment_id`
- candle with seeded instrument ID

Expected:
- response shows `signals_emitted`
- heartbeat written

## 10.2 Verify heartbeat storage
If runtime health endpoint/page exists later, confirm heartbeat row.

Expected:
- status healthy
- recent timestamp

---

# 11. Signals QA

## 11.1 Read signals
`GET http://localhost:8012/api/signals`

Expected:
- sample signal visible after runtime run
- instrument_id, direction, strength, confidence visible

If empty:
- runtime emitted to outbox but consumer path may be incomplete
- verify whether the event pipeline is manual/demo-only in current build

Be honest in evaluation here: if signals are not persisted yet, note it as a current gap rather than a test failure in unrelated components.

---

# 12. Portfolio targets QA

## 12.1 Read targets
`GET http://localhost:8013/api/targets`

Expected:
- target row appears after signal processing if target consumer path is connected

If empty:
- likely signal-to-target event chain is not fully executed yet
- mark as partial implementation gap

---

# 13. Order lifecycle QA

This is one of the most important tests.

## 13.1 Get IDs
Retrieve:
- instrument ID for EURUSD
- venue ID for oanda-demo

## 13.2 Submit integrated order via API
Use token from login.

Endpoint:
- `POST http://localhost:8005/api/orders/submit`

Expected depending on current mode:
- synchronous mode: order may go straight to filled
- hardened mode: accepted/risk/evaluation path visible
- event-driven mode: accepted with correlation ID, then follow through pipeline if wired

## 13.3 Read orders list
`GET http://localhost:8005/api/orders`

Expected:
- submitted row visible
- correlation_id visible in hardened flow

## 13.4 Read order detail
`GET http://localhost:8005/api/orders/{id}`

Expected:
- order object visible
- state history visible if hardening migration applied and endpoint works

---

# 14. Ops UI QA

Open:
- `http://localhost:3001/login`

Login with:
- `admin@example.com`
- `admin`

## 14.1 Ops login
Expected:
- page loads
- login works
- dashboard opens

## 14.2 Ops dashboard
Expected:
- order/position/breach counters visible

## 14.3 Orders page
Action:
- paste seeded instrument ID
- paste seeded venue ID
- submit order

Expected:
- response block shown
- order list refreshes
- clicking detail opens detail page

## 14.4 Order detail page
Expected:
- detail JSON visible
- state history visible if backend endpoint is active

## 14.5 Positions page
Expected:
- position updated after successful order execution

## 14.6 Breaches page
Expected:
- initially maybe empty
- later populated after rule breach or kill switch rejection

## 14.7 Kill switches page
Action:
- create global kill switch

Expected:
- kill switch row visible

## 14.8 Execution quality page
Expected:
- rows appear after executions
- slippage/fee fields visible

## 14.9 Signals page
Expected:
- signals visible if signal persistence path is active

## 14.10 Targets page
Expected:
- targets visible if target persistence path is active

---

# 15. Position QA

## 15.1 API
`GET http://localhost:8008/api/positions`

Expected:
- row exists after order fill
- net quantity and avg price updated

## 15.2 UI
Open positions page.

Expected:
- same row visible in ops UI

---

# 16. Risk controls QA

## 16.1 Kill switch creation
Use API or ops UI.

Expected:
- active kill switch row exists

## 16.2 Submit order while kill switch active
Expected:
- risk reject
- no new successful execution

## 16.3 Breach generation
If quantity exceeds threshold or kill switch blocks the request:
- breach rows may be created

Check:
- `GET /api/risk/breaches`

## 16.4 Drawdown tracker
Call drawdown tracker endpoint.

Expected:
- tracker row created
- readable via list endpoint

---

# 17. Execution quality QA

## 17.1 Submit a successful order
Then inspect:
- `GET http://localhost:8007/api/execution/quality-metrics`

Expected:
- quality row exists
- slippage_bps and total_fee_amount visible

## 17.2 Broker order history
If state history route is not yet exposed, verify DB rows directly.

Expected:
- submitted → filled transitions stored

---

# 18. Reconciliation QA

## 18.1 Create run
`POST http://localhost:8018/api/reconciliation/runs`

Expected:
- run ID returned

## 18.2 Read runs
`GET http://localhost:8018/api/reconciliation/runs`

Expected:
- run row visible

## 18.3 Create issue
`POST http://localhost:8018/api/reconciliation/issues`

Expected:
- issue row created

## 18.4 Read issues
`GET http://localhost:8018/api/reconciliation/issues`

Expected:
- issue row visible

---

# 19. Workflow QA

## 19.1 Create workflow
`POST http://localhost:8019/api/workflows`

Expected:
- workflow ID returned

## 19.2 Start run
`POST http://localhost:8019/api/workflows/runs`

Expected:
- run ID returned

## 19.3 UI test
Use admin workflows page.

Expected:
- demo workflow creation succeeds
- demo run starts successfully

---

# 20. Compliance QA

## 20.1 Create export
`POST http://localhost:8020/api/compliance/exports`

Expected:
- export ID returned

## 20.2 Read exports
`GET http://localhost:8020/api/compliance/exports`

Expected:
- export row visible

## 20.3 UI test
Use admin compliance exports page.

Expected:
- create export button works
- row appears

---

# 21. Audit QA

After login, order creation, workflow creation, and other actions:

Check:
- `GET http://localhost:8009/api/audit`
- admin audit page

Expected:
- rows for order lifecycle and other audited actions
- timestamps, resource types, and IDs visible

If audit is sparse:
- note exactly which actions are audited and which are not yet instrumented

---

# 22. End-to-end scenario test order

Use this exact order for the strongest evaluation:

1. health endpoints
2. seed verification
3. admin login API
4. reference-data APIs
5. admin UI pages
6. market data ingest
7. feature definition seed
8. dataset create
9. replay job create
10. runtime sample run
11. signal read
12. target read
13. ops login
14. order submit
15. order detail
16. positions verify
17. execution quality verify
18. create kill switch
19. blocked order submit
20. breaches verify
21. reconciliation run + issue
22. workflow create + run
23. compliance export create
24. audit review

This sequence minimizes confusion because each step builds on earlier verified dependencies.

---

# 23. Expected pass/fail interpretation

## Full pass
Means:
- infra healthy
- auth works
- reference data works
- order flow works
- risk works
- execution works
- positions update
- UI pages render
- governance pages operate

## Partial pass
Most likely outcome at current stage for some modules:
- core trading path works
- some event-driven transitions may still be partial
- signals/targets/runtime heartbeats may be scaffolded but not fully end-to-end wired
- incident UI may still be pending

That is acceptable as long as you record it accurately.

## Fail
A fail should only be called when a module that is supposed to be wired in the current build does not work.

---

# 24. Recommended defect log format

For every problem found, record:

- module
- exact endpoint or page
- steps to reproduce
- expected result
- actual result
- logs or screenshot
- severity
- likely layer: UI / API / DB / seed / orchestration

Example:

```text
Module: Orders
Page: web-ops /orders
Steps: Submit seeded EURUSD order with valid venue
Expected: order accepted and shown in list
Actual: 500 Internal Server Error
Likely layer: order-service integration or auth header propagation
Severity: high
```

---

# 25. Final evaluation checkpoints

At the end of the walkthrough, you should be able to answer:

- Can the platform authenticate a user?
- Can it show seeded markets/instruments/strategies?
- Can it ingest market data?
- Can it seed and compute features?
- Can it create datasets and replay jobs?
- Can it generate strategy runtime output?
- Can it submit and track orders?
- Can it update positions?
- Can it block trading via kill switch?
- Can it record execution quality?
- Can it create reconciliation runs/issues?
- Can it create workflows and compliance exports?
- Can it show audit history?
- Can all of the above be exercised from the UI where applicable?

If most answers are yes, the platform is already a serious functional operator foundation.

---

# 26. Best next testing artifact

After this walkthrough, the next strongest artifact is a **formal QA checklist sheet** with:
- pass/fail column
- notes column
- defect ID column
- tester/date fields
- grouped by module

That makes test execution and handoff much cleaner.

