# 1. API style
Use:
- REST for admin and reporting APIs
- async events for runtime
- optional gRPC later for low-latency internal flows

# 2. Example REST endpoints

## Auth / identity
- `POST /api/auth/login`
- `POST /api/auth/logout`
- `GET /api/me`
- `GET /api/users`
- `POST /api/users`
- `GET /api/roles`
- `POST /api/users/{id}/roles`

## Markets / instruments
- `GET /api/markets`
- `GET /api/venues`
- `GET /api/instruments`
- `POST /api/instruments`
- `POST /api/instrument-mappings`

## Strategies
- `GET /api/strategies`
- `POST /api/strategies`
- `GET /api/strategies/{id}`
- `POST /api/strategies/{id}/versions`
- `POST /api/strategy-versions/{id}/validate`
- `POST /api/strategy-versions/{id}/request-promotion`

## Backtests
- `POST /api/backtests`
- `GET /api/backtests`
- `GET /api/backtests/{id}`
- `GET /api/backtests/{id}/results`

## Paper/live deployments
- `POST /api/deployments`
- `GET /api/deployments`
- `POST /api/deployments/{id}/pause`
- `POST /api/deployments/{id}/resume`
- `POST /api/deployments/{id}/stop`

## Risk
- `GET /api/risk/policies`
- `POST /api/risk/policies`
- `GET /api/risk/exposures`
- `GET /api/risk/breaches`
- `POST /api/risk/kill-switch/global`
- `POST /api/risk/kill-switch/strategy/{id}`

## Orders
- `GET /api/orders`
- `GET /api/orders/{id}`
- `POST /api/orders/{id}/cancel`
- `GET /api/fills`
- `GET /api/positions`
- `GET /api/balances`

## Reconciliation
- `GET /api/reconciliation/issues`
- `POST /api/reconciliation/issues/{id}/resolve`

## Audit
- `GET /api/audit/events`
- `GET /api/audit/resources/{type}/{id}`

## Reporting
- `GET /api/reports/performance`
- `GET /api/reports/risk`
- `GET /api/reports/strategy-attribution`

# 3. Example order intent payload

```JSON
{
"strategy_deployment_id": "dep_fx_trend_001",
"account_id": "acct_oanda_live_01",
"instrument_id": "eurusd_spot",
"side": "buy",
"order_type": "limit",
"quantity": 10000,
"limit_price": 1.0845,
"stop_price": null,
"tif": "GTC",
    "metadata": {
    "reason": "trend_breakout",
    "signal_id": "sig_1001"
    }
}
```