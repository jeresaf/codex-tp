# 1. Delivery objective
Translate the platform architecture into a buildable engineering plan with:
- repo structure
- service structure
- database schema outline
- event schemas
- internal SDK contracts
- Vue 3 frontend module map
- API specs
- phased task board
- live readiness engineering controls
The goal is to let a team start building immediately without redesigning the system again.

# 2. Suggested monorepo structure
A monorepo is the best first step because the domains are tightly related and you want consistent contracts.

trading-platform/
├─ apps/
│ ├─ web-admin/
│ ├─ web-ops/
│ ├─ api-gateway/
│ ├─ identity-service/
│ ├─ config-service/
│ ├─ workflow-service/
│ ├─ market-registry-service/
│ ├─ instrument-master-service/
│ ├─ market-data-service/
│ ├─ historical-data-service/
│ ├─ feature-service/
│ ├─ strategy-service/
│ ├─ strategy-runtime-service/
│ ├─ backtest-service/
│ ├─ paper-trading-service/
│ ├─ experiment-service/
│ ├─ model-registry-service/
│ ├─ portfolio-service/
│ ├─ risk-service/
│ ├─ order-service/
│ ├─ execution-service/
│ ├─ position-service/
│ ├─ reconciliation-service/
│ ├─ audit-service/
│ ├─ reporting-service/
│ ├─ notification-service/
│ ├─ broker-adapter-oanda/
│ ├─ broker-adapter-binance/
│ └─ broker-adapter-interactivebrokers/
│
├─ packages/
│ ├─ shared-domain/
│ ├─ shared-events/
│ ├─ shared-db/
│ ├─ shared-auth/
│ ├─ shared-logging/
│ ├─ shared-metrics/
│ ├─ shared-config/
│ ├─ shared-risk-rules/
│ ├─ shared-market-utils/
│ ├─ shared-order-utils/
│ ├─ strategy-sdk/
│ ├─ broker-sdk/
│ ├─ backtest-sdk/
│ ├─ portfolio-sdk/
│ └─ ui-kit/
│
├─ infra/
│ ├─ docker/
│ ├─ k8s/
│ ├─ terraform/
│ ├─ monitoring/
│ ├─ kafka/
│ ├─ postgres/
│ ├─ redis/
│ └─ minio/
│
├─ schemas/
│ ├─ events/
│ ├─ api/
│ └─ db/
│
├─ scripts/
│ ├─ dev/
│ ├─ seed/
│ ├─ migrate/
│ ├─ backfill/
│ └─ smoke-tests/
│
├─ docs/
│ ├─ architecture/
│ ├─ runbooks/
│ ├─ playbooks/
│ ├─ api/
│ └─ onboarding/
│
└─ tests/
├─ unit/
├─ integration/
├─ e2e/
├─ simulation/
└─ fixtures/

# 3. Technology choice by layer

## Frontend
- Vue 3
- Pinia
- Vue Router
- TypeScript
- Tailwind CSS or CoreUI
- ECharts
- Vue Query for server state

## Backend admin/control APIs
- Laravel or FastAPI
- PostgreSQL
- Redis
- OpenAPI specs

## Runtime and quant services
- Python
- FastAPI for APIs
- Celery/RQ or native worker processes
- pandas / NumPy / PyArrow
- Backtrader or vectorbt for early backtests

## Event backbone
- Kafka or Redpanda

## Data storage
- PostgreSQL
- TimescaleDB
- MinIO
- Redis

## Infra
- Docker Compose for local
- Kubernetes later
- Prometheus/Grafana/Loki/OpenTelemetry

# 4. Service-by-service folder structure
Use a consistent internal service template.

## Example service structure

apps/risk-service/
├─ app/
│ ├─ api/
│ │ ├─ routes/
│ │ ├─ serializers/
│ │ └─ deps/
│ ├─ domain/
│ │ ├─ entities/
│ │ ├─ value_objects/
│ │ ├─ services/
│ │ ├─ policies/
│ │ └─ repositories/
│ ├─ use_cases/
│ ├─ consumers/
│ ├─ producers/
│ ├─ db/
│ │ ├─ models/
│ │ ├─ migrations/
│ │ └─ seeders/
│ ├─ integrations/
│ ├─ config/
│ ├─ observability/
│ └─ main.py
├─ tests/
├─ Dockerfile
└─ pyproject.toml

## Internal layering rule
Every service should follow:
- `api`: external endpoints
- `domain`: core business rules
- `use_cases`: orchestration
- `repositories`: persistence abstraction
- `consumers/producers`: event I/O
- `integrations`: external dependencies
- `db`: database implementation
Do not put broker logic, database logic, and domain rules in one file.

# 5. Initial MVP service cut
Do not build all services at once. Start with this minimum set.

## Phase 1 service set
- api-gateway
- identity-service
- market-registry-service
- instrument-master-service
- market-data-service
- historical-data-service
- strategy-service
- backtest-service
- paper-trading-service
- risk-service
- order-service
- execution-service
- position-service
- audit-service
- reporting-service
- broker-adapter-oanda or broker-adapter-binance
- web-admin
- web-ops
That gives a real platform.

# 6. Database implementation blueprint

## 6.1 Database split

### Main transactional database
Use PostgreSQL for:
- users
- roles
- strategies
- deployments
- risk rules
- order intents
- broker orders
- positions snapshots
- workflows
- audit metadata
- reconciliation issues

### Time-series database
Use TimescaleDB for:
- candles
- ticks
- features
- signals
- P&L time series
- service metrics snapshots if desired

### Object storage
Use MinIO for:
- backtest results
- parquet datasets
- raw feeds
- experiment artifacts
- models
- compliance exports

## 6.2 Core schema modules

### identity schema
Tables:
- users
- roles
- permissions
- role_permissions
- user_roles
- teams
- team_users
- sessions
- api_clients

### market schema
Tables:
- markets
- venues
- trading_calendars
- market_sessions
- instruments
- instrument_mappings
- instrument_tags
- corporate_actions
- roll_rules

### strategy schema
Tables:
- strategies
- strategy_versions
- strategy_parameters
- strategy_required_features
- strategy_deployments
- deployment_allocations
- deployment_market_scopes

### research schema
Tables:
- datasets
- experiment_runs
- backtest_runs
- backtest_metrics
- model_artifacts
- validation_reports

### risk schema
Tables:
- risk_policies
- risk_policy_scopes
- risk_breaches
- kill_switches
- risk_exposure_snapshots

### execution schema
Tables:
- order_intents
- broker_orders
- order_state_history
- fills
- execution_sessions
- venue_errors

### portfolio schema
Tables:
- portfolio_targets
- positions
- position_snapshots
- balances
- balance_snapshots
- pnl_snapshots

### governance schema
Tables:
- workflow_requests
- workflow_steps
- approvals
- audit_events
- incidents
- reconciliation_issues

## 6.3 Example PostgreSQL table definitions

### strategies
```SQL
CREATE TABLE strategies (
    id UUID PRIMARY KEY,
    code VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(100) NOT NULL,
    owner_user_id UUID NOT NULL,
    description TEXT,
    status VARCHAR(50) NOT NULL DEFAULT 'draft',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### strategy_versions
```SQL
CREATE TABLE strategy_versions (
    id UUID PRIMARY KEY,
    strategy_id UUID NOT NULL REFERENCES strategies(id),
    version VARCHAR(50) NOT NULL,
    artifact_uri TEXT NOT NULL,
    code_commit_hash VARCHAR(255),
    parameter_schema JSONB NOT NULL,
    runtime_requirements JSONB,
    approval_state VARCHAR(50) NOT NULL DEFAULT 'draft',
    created_by UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(strategy_id, version)
);
```

### strategy_deployments
```SQL
    CREATE TABLE strategy_deployments (
    id UUID PRIMARY KEY,
    strategy_version_id UUID NOT NULL REFERENCES strategy_versions(id),
    environment VARCHAR(50) NOT NULL,
    account_id UUID NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'stopped',
    capital_allocation_rule JSONB,
    market_scope_json JSONB,
    started_at TIMESTAMPTZ,
    stopped_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### risk_policies
```SQL
CREATE TABLE risk_policies (
    id UUID PRIMARY KEY,
    scope_type VARCHAR(50) NOT NULL,
    scope_id UUID NOT NULL,
    rule_type VARCHAR(100) NOT NULL,
    rule_config_json JSONB NOT NULL,
    severity VARCHAR(20) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### order_intents
```SQL
CREATE TABLE order_intents (
    id UUID PRIMARY KEY,
    strategy_deployment_id UUID REFERENCES strategy_deployments(id),
    account_id UUID NOT NULL,
    instrument_id UUID NOT NULL,
    signal_id UUID,
    side VARCHAR(10) NOT NULL,
    order_type VARCHAR(20) NOT NULL,
    quantity NUMERIC(24,10) NOT NULL,
    limit_price NUMERIC(24,10),
    stop_price NUMERIC(24,10),
    tif VARCHAR(20) NOT NULL,
    intent_status VARCHAR(50) NOT NULL DEFAULT 'draft',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### broker_orders
```SQL
CREATE TABLE broker_orders (
    id UUID PRIMARY KEY,
    order_intent_id UUID NOT NULL REFERENCES order_intents(id),
    venue_id UUID NOT NULL,
    external_order_id VARCHAR(255),
    broker_status VARCHAR(50) NOT NULL,
    raw_request JSONB,
    raw_response JSONB,
    submitted_at TIMESTAMPTZ,
    acknowledged_at TIMESTAMPTZ
);
```

### fills
```SQL
CREATE TABLE fills (
    id UUID PRIMARY KEY,
    broker_order_id UUID NOT NULL REFERENCES broker_orders(id),
    instrument_id UUID NOT NULL,
    fill_price NUMERIC(24,10) NOT NULL,
    fill_quantity NUMERIC(24,10) NOT NULL,
    fee_amount NUMERIC(24,10) DEFAULT 0,
    fee_currency VARCHAR(20),
    fill_time TIMESTAMPTZ NOT NULL,
    raw_payload JSONB
);
```

# 7. Time-series schema blueprint

## candles table
```SQL
CREATE TABLE market_candles (
    ts TIMESTAMPTZ NOT NULL,
    instrument_id UUID NOT NULL,
    timeframe VARCHAR(10) NOT NULL,
    open NUMERIC(24,10) NOT NULL,
    high NUMERIC(24,10) NOT NULL,
    low NUMERIC(24,10) NOT NULL,
    close NUMERIC(24,10) NOT NULL,
    volume NUMERIC(24,10),
    source VARCHAR(100) NOT NULL,
    PRIMARY KEY (instrument_id, timeframe, ts)
);
```

## features table
```SQL
CREATE TABLE feature_values (
    ts TIMESTAMPTZ NOT NULL,
    instrument_id UUID NOT NULL,
    feature_code VARCHAR(100) NOT NULL,
    timeframe VARCHAR(10) NOT NULL,
    value_double DOUBLE PRECISION,
    value_json JSONB,
    source_run_id UUID,
    PRIMARY KEY (instrument_id, feature_code, timeframe, ts)
);
```

## signals table
```SQL
CREATE TABLE signal_events (
    ts TIMESTAMPTZ NOT NULL,
    signal_id UUID NOT NULL,
    strategy_version_id UUID NOT NULL,
    instrument_id UUID NOT NULL,
    direction VARCHAR(10) NOT NULL,
    strength DOUBLE PRECISION,
    confidence DOUBLE PRECISION,
    metadata_json JSONB,
    PRIMARY KEY (signal_id, ts)
    );
```

# 8. Shared domain package structure
Create `packages/shared-domain` for canonical entities.

packages/shared-domain/
├─ entities/
│ ├─ instrument.py
│ ├─ market.py
│ ├─ venue.py
│ ├─ strategy.py
│ ├─ order_intent.py
│ ├─ broker_order.py
│ ├─ fill.py
│ ├─ position.py
│ └─ risk_policy.py
├─ value_objects/
│ ├─ money.py
│ ├─ quantity.py
│ ├─ price.py
│ ├─ symbol.py
│ └─ timeframe.py
├─ enums/
│ ├─ order_status.py
│ ├─ order_type.py
│ ├─ asset_class.py
│ └─ environment.py
└─ validators/

This package keeps all services aligned.

# 9. Event JSON schema blueprint
All events should use a standard envelope.

## Common envelope

```JSON
{
    "event_id": "uuid",
    "event_type": "orders.intent.created",
    "event_version": 1,
    "source_service": "order-service",
    "environment": "paper",
    "occurred_at": "2026-03-18T10:15:00Z",
    "correlation_id": "uuid",
    "causation_id": "uuid",
    "actor_type": "system",
    "actor_id": "strategy-runtime-service",
    "payload": {}
}
```

## Example: signals.generated

```JSON
{
    "event_id": "uuid",
    "event_type": "signals.generated",
    "event_version": 1,
    "source_service": "strategy-runtime-service",
    "environment": "paper",
    "occurred_at": "2026-03-18T10:15:00Z",
    "correlation_id": "uuid",
    "causation_id": "uuid",
    "actor_type": "strategy",
    "actor_id": "fx_trend_v1",
    "payload": {
        "signal_id": "uuid",
        "strategy_version_id": "uuid",
        "instrument_id": "uuid",
        "timestamp": "2026-03-18T10:15:00Z",
        "direction": "long",
        "strength": 0.82,
        "confidence": 0.76,
        "reason_codes": ["ma_cross", "trend_filter_passed"]
    }
}
```

## Example: risk.check.failed

```JSON
{
    "event_id": "uuid",
    "event_type": "risk.check.failed",
    "event_version": 1,
    "source_service": "risk-service",
    "environment": "live",
    "occurred_at": "2026-03-18T10:15:01Z",
    "correlation_id": "uuid",
    "causation_id": "uuid",
    "actor_type": "system",
    "actor_id": "risk-service",
    "payload": {
        "order_intent_id": "uuid",
        "account_id": "uuid",
        "instrument_id": "uuid",
        "rule_type": "max_daily_loss",
        "severity": "critical",
        "decision": "reject",
        "message": "Daily loss threshold exceeded"
    }
}
```

## Example: orders.filled

```JSON
{
    "event_id": "uuid",
    "event_type": "orders.filled",
    "event_version": 1,
    "source_service": "execution-service",
    "environment": "live",
    "occurred_at": "2026-03-18T10:15:03Z",
    "correlation_id": "uuid",
    "causation_id": "uuid",
    "actor_type": "broker",
    "actor_id": "oanda",
    "payload": {
        "broker_order_id": "uuid",
        "order_intent_id": "uuid",
        "fill_id": "uuid",
        "instrument_id": "uuid",
        "price": 1.08345,
        "quantity": 10000,
        "fee_amount": 0.8,
        "fee_currency": "USD",
        "fill_time": "2026-03-18T10:15:03Z"
    }
}
```

# 10. Strategy SDK implementation blueprint

## Package structure

packages/strategy-sdk/
├─ base/
│ ├─ strategy_plugin.py
│ ├─ context.py
│ ├─ exceptions.py
│ └─ types.py
├─ io/
│ ├─ market_data.py
│ ├─ features.py
│ ├─ orders.py
│ └─ events.py
├─ utils/
│ ├─ indicators.py
│ ├─ signals.py
│ └─ clocks.py
└─ validation/

## Base plugin

```Python
from abc import ABC, abstractmethod

class StrategyPlugin(ABC):
    @abstractmethod
    def initialize(self, context): ...
    @abstractmethod
    def on_market_data(self, event): ...
    @abstractmethod
    def on_feature_update(self, feature_set): ...
    @abstractmethod
    def generate_signal(self): ...
    @abstractmethod
    def propose_orders(self, portfolio_state, risk_context): ...
    @abstractmethod
    def on_order_update(self, order_event): ...
    @abstractmethod
    def on_fill(self, fill_event): ...
    @abstractmethod
    def on_risk_event(self, risk_event): ...
    @abstractmethod
    def on_clock(self, timestamp): ...
    @abstractmethod
    def shutdown(self): ...
```

## Strategy runtime rules
- strategies emit signals or order proposals only
- no direct venue calls
- no direct SQL writes
- no direct file writes except sandboxed artifacts
- no uncontrolled network calls
- no secrets outside injected runtime context

# 11. Broker SDK implementation blueprint

## Package structure

packages/broker-sdk/
├─ base/
│ ├─ broker_adapter.py
│ ├─ auth.py
│ └─ rate_limit.py
├─ models/
│ ├─ order_request.py
│ ├─ order_response.py
│ ├─ account_state.py
│ └─ market_data_message.py
├─ translators/
│ ├─ symbols.py
│ ├─ errors.py
│ └─ payloads.py
└─ utils/

## Base adapter

```Python
class BrokerAdapter:
def connect(self): ...
def disconnect(self): ...
def health_check(self): ...
def get_account_state(self, account_ref): ...
def get_positions(self, account_ref): ...
def submit_order(self, order_request): ...
def cancel_order(self, external_order_id): ...
def replace_order(self, external_order_id, changes): ...
def fetch_historical_data(self, instrument, start, end, timeframe):...
def stream_market_data(self, instruments): ...
def stream_order_updates(self, account_ref): ...
```

## Adapter-specific modules
Each broker service should include:
- client
- auth
- translator
- streaming consumer
- order update mapper
- health checks
- rate limiter
- retry policy

# 12. Order pipeline implementation flow
This is the most important runtime pipeline.

## Event flow

strategy-runtime-service
    → signals.generated
portfolio-service
    → portfolio.targets.created
order-service
    → orders.intent.created
risk-service
    → risk.check.passed or risk.check.failed
execution-service
    → orders.submitted
broker-adapter
    → orders.acknowledged / orders.rejected / orders.filled
position-service
    → positions.updated / pnl.updated
audit-service
    → audit.events.recorded
reporting-service
    → dashboard aggregates refreshed

## Order pipeline rules
- every order intent gets a correlation id
- risk decision must be persisted before execution
- execution idempotency keys are mandatory
- duplicate broker callbacks must be tolerated
- state machine transitions must be validated

# 13. Order state machine

## Allowed states

draft
→ risk_pending
→ risk_passed
→ risk_failed
→ submitted
→ acknowledged
→ partially_filled
→ filled
→ cancel_pending
→ cancelled
→ rejected
→ expired

## Transition rules
- `draft -> risk_pending`
- `risk_pending -> risk_passed | risk_failed`
- `risk_passed -> submitted`
- `submitted -> acknowledged | rejected`
- `acknowledged -> partially_filled | filled | cancel_pending | expired`
- `partially_filled -> filled | cancel_pending`
- `cancel_pending -> cancelled`
Never allow an illegal transition like `risk_failed -> submitted`.

# 14. Risk engine implementation blueprint

## 14.1 Risk rule categories

### Strategy rules
- max open positions
- max trades per day
- signal confidence minimum
- max holding period
- cooldown after stop-loss

### Account rules
- max notional exposure
- max leverage
- max margin used
- max loss per day

### Portfolio rules
- gross exposure
- net exposure
- correlation concentration
- asset concentration
- currency concentration

### Operational rules
- stale market feed
- broker connection down
- time skew detected
- repeated rejects
- abnormal slippage

### Governance rules
= strategy not approved for live
= deployment outside allowed hours
= frozen account
- expired approval

## 14.2 Risk service structure

apps/risk-service/app/
├─ rules/
│ ├─ strategy/
│ ├─ account/
│ ├─ portfolio/
│ ├─ operational/
│ └─ governance/
├─ evaluators/
├─ policies/
├─ use_cases/
└─ consumers/

## 14.3 Risk evaluation result

```JSON
{
    "decision": "reject",
    "severity": "critical",
    "rule_results": [
        {
            "rule_type": "max_daily_loss",
            "passed": false,
            "message": "Daily loss threshold exceeded"
        }
    ]
}
```

## 14.4 Kill switch model
Support:
- global kill switch
- market kill switch
- venue kill switch
- account kill switch
- strategy deployment kill switch
Each should:
- block new orders
- optionally cancel active open orders
- optionally flatten positions subject to policy

# 15. Portfolio engine implementation blueprint

## Responsibilities
- combine strategy outputs
- net conflicting targets
- enforce allocation rules
- scale to account and risk limits
- create final portfolio targets

## Inputs
- strategy signals
- account state
- current positions
- allocation config
- risk constraints

## Output
- normalized target exposures

## Allocation strategies to support first
- fixed capital percent
- volatility targeting
- max drawdown adjusted sizing

## Example target payload

```JSON
{
    "deployment_id": "uuid",
    "instrument_id": "uuid",
    "target_quantity": 20000,
    "target_weight": 0.12,
    "reason": "signal_consensus"
}
```

# 16. Backtest service blueprint

## Required capabilities
- replay historical candles
- configurable fees/spread/slippage
- walk-forward tests
- parameter sweeps
- reproducible outputs
- artifact storage

## Backtest flow

Select strategy version
→ Select dataset version
→ Select config assumptions
→ Run simulation
→ Store trades/equity curve/metrics
→ Produce validation report

## Minimum metrics
- total return
- Sharpe ratio
- Sortino ratio
- max drawdown
- win rate
- profit factor
- average trade
- exposure time
- turnover
- fee impact
- slippage impact

## Stored artifacts
- equity curve csv/parquet
- trade ledger
- daily returns
- config snapshot
- metric summary json
- charts

# 17. Paper trading service blueprint

## Purpose
Paper should behave as closely as possible to live.

## Logic
- consume real-time market data
- receive approved order intents
- simulate fills using configurable execution model
- track positions and P&L
- emit same lifecycle events as live execution

## Fill simulation models
Support:
- mid-price fill
- bid/ask based fill
- delayed fill
- slippage adjusted fill
- partial fill probability model
This keeps paper realistic.

# 18. Reconciliation service blueprint

## Responsibilities
- compare internal positions with broker positions
- compare balances
- compare fills
- detect orphan orders
- detect fill mismatches
- open discrepancy workflow

## Reconciliation schedules
- near-real-time check every few minutes
- end-of-day full reconciliation
- start-of-day baseline comparison

## Resolution states
- open
- investigating
- resolved_internal_adjustment
- resolved_broker_confirmed
- false_positive
- escalated

# 19. Audit service blueprint

## Every important action must create an audit event
Examples:
- user login
- strategy
- version registered
- backtest started
- backtest approved
- deployment requested
- deployment approved
- risk policy changed
- kill switch triggered
- order manually cancelled
- reconciliation issue resolved

## Audit event structure

```JSON
{
    "actor_type": "user",
    "actor_id": "uuid",
    "event_type": "risk_policy.updated",
    "resource_type": "risk_policy",
    "resource_id": "uuid",
    "before_json": {},
    "after_json": {},
    "occurred_at": "2026-03-18T10:15:00Z"
}
```

## Immutable log policy
- append-only audit table
- no updates except retention metadata if needed
- critical events replicated to object storage daily

# 20. Vue 3 frontend module map
Split UI into two apps or one app with strong module boundaries.

## Option A
- web-admin
- web-ops
This is cleaner.

## 20.1 web-admin modules

### Auth
- login
- MFA
- session management

### Users and roles
- users list
- create/edit user
- assign roles
- disable user

### Markets and venues
- market list
- venue list
- session calendars
- market status flags

### Instruments
- instruments list
- create/edit instrument
- symbol mapping view
- instrument health

### Strategies
- strategies list
- strategy detail
- versions
- parameters
- dependencies
- approvals

### Research
- experiments
- backtests
- validation reports
- artifact downloads

### Risk policies
- policies list
- scope assignment
- edit limits
- breach history

### Workflows
- approval inbox
- request detail
- approve/reject
- change history

### Audit
- event log
- resource timeline
- actor activity

### Configuration
- feature flags
- environment configs
- deployment limits

## 20.2 web-ops modules

### Dashboard
- service health
- feed health
- order throughput
- alert summary
- P&L summary

### Live monitor
- deployments
- runtime status
- heartbeats
- stale workers

### Orders
- intent list
- broker order list
- state filters
- order detail timeline

### Fills
- fill stream
- fill detail
- fee/slippage metrics

### Positions
- open positions
- net exposure
- per-account view
- per-strategy view

### Balances
- account balances
- margin usage
- equity history

### Risk monitor
- breaches
- kill switches
- drawdown tracker
- exposure monitor

### Reconciliation
- open issues
- resolution workflow
- discrepancy comparisons

### Incidents
- incident list
- severity filters
- playbooks
- resolution notes

### Reports
- strategy performance
- attribution
- daily summary
- export page

# 21. Vue route blueprint

## web-admin routes

/login
/app
/app/dashboard
/app/users
/app/users/:id
/app/roles
/app/markets
/app/venues
/app/instruments
/app/instruments/:id
/app/strategies
/app/strategies/:id
/app/strategy-versions/:id
/app/backtests
/app/backtests/:id
/app/experiments
/app/risk-policies
/app/workflows
/app/workflows/:id
/app/audit
/app/config

## web-ops routes

/login
/ops
/ops/dashboard
/ops/deployments
/ops/orders
/ops/orders/:id
/ops/fills
/ops/positions
/ops/balances
/ops/risk
/ops/reconciliation
/ops/incidents
/ops/reports

# 22. Frontend state management blueprint
Use Pinia stores:
- `authStore`
- `userStore`
- `marketStore`
- `instrumentStore`
- `strategyStore`
- `backtestStore`
- `workflowStore`
- `riskStore`
- `deploymentStore`
- `orderStore`
- `positionStore`
- `balanceStore`
- `incidentStore`
- `auditStore`
- `reportStore`

Use websocket or SSE later for:
- live orders
- fills
- risk alerts
- service heartbeats

# 23. API spec blueprint by service

## identity-service
- `POST /auth/login`
- `POST /auth/logout`
- `GET /me`
- `GET /users`
- `POST /users`
- `PATCH /users/{id}`
- `POST /users/{id}/roles`

## market-registry-service
- `GET /markets`
- `POST /markets`
- `GET /venues`
- `POST /venues`
- `GET /trading-calendars`

## instrument-master-service
- `GET /instruments`
- `POST /instruments`
- `PATCH /instruments/{id}`
- `POST /instrument-mappings`

## strategy-service
- `GET /strategies`
- `POST /strategies`
- `GET /strategies/{id}`
- `POST /strategies/{id}/versions`
- `POST /strategy-versions/{id}/request-approval`

## backtest-service
- `POST /backtests`
- `GET /backtests`
- `GET /backtests/{id}`
- `GET /backtests/{id}/artifacts`

## paper-trading-service
- `POST /paper-deployments`
- `GET /paper-deployments`
- `POST /paper-deployments/{id}/stop`

## risk-service
- `GET /risk-policies`
- `POST /risk-policies`
- `GET /risk-breaches`
- `POST /kill-switches`

## order-service
- `GET /order-intents`
- `GET /order-intents/{id}`
- `POST /order-intents/{id}/cancel`

## execution-service
- `GET /broker-orders`
- `GET /fills`

## position-service
- `GET /positions`
- `GET /balances`
- `GET /pnl`

## reconciliation-service
- `GET /reconciliation-issues`
- `POST /reconciliation-issues/{id}/resolve`

## workflow-service
- `GET /workflow-requests`
- `POST /workflow-requests/{id}/approve`
- `POST /workflow-requests/{id}/reject`

## audit-service
- `GET /audit-events`
- `GET /audit/resources/{type}/{id}`

# 24. Suggested permissions model implementation

## Permissions should be code-based, not hardcoded in UI
Examples:
- `users.read`
- `users.write`
- `roles.assign`
- `markets.read`
- `markets.write`
- `strategies.read`
- `strategies.write`
- `strategy_versions.register`
- `backtests.run`
- `backtests.read`
- `deployments.paper.manage`
- `deployments.live.approve`
- `risk_policies.write`
- `kill_switch.trigger`
- `orders.read`
- `orders.cancel`
- `audit.read`
- `reports.read`
Frontend should receive permission list on login and gate features.

# 25. Seed data blueprint

## Minimum seed set

### Roles
- super_admin
- platform_admin
- quant_researcher
- strategy_developer
- operations
- risk_officer
- compliance_officer
- executive_viewer

### Markets
- forex
- crypto

### Venues
- oanda-demo or binance-testnet

### Timeframes
- 1m
- 5m
- 15m
- 1h
- 4h
- 1d

### Instruments
If forex:
- EURUSD
- GBPUSD
- USDJPY
- XAUUSD
If crypto:
- BTCUSDT
- ETHUSDT
- SOLUSDT

### Risk policies
- max_daily_loss
- max_position_size
- max_notional_exposure
- stale_feed_halt

### Strategies
- fx_trend_v1
- fx_mean_reversion_v1
- fx_breakout_v1

# 26. Local development blueprint

## Docker Compose services

>docker-compose.yml
>- postgres
>- timescaledb
>- redis
>- redpanda/kafka
>- minio
>- api-gateway
>- identity-service
>- market-registry-service
>- instrument-master-service
>- market-data-service
>- historical-data-service
>- strategy-service
>- backtest-service
>- paper-trading-service
>- risk-service
>- order-service
>- execution-service
>- position-service
>- audit-service
>- reporting-service
>- broker-adapter
>- web-admin
>- web-ops

## Local commands
- `make up`
- `make migrate`
- `make seed`
- `make test`
- `make smoke`
- `make dev-web-admin`
- `make dev-web-ops`

# 27. CI/CD blueprint

## Pipeline stages

### 1. Lint
- Python lint
- TypeScript lint
- schema validation

### 2. Unit tests
- service-specific

### 3. Integration tests
- DB
- Kafka
- Redis
- broker stub

### 4. Contract tests
- event schema compatibility
- API schema compatibility

### 5. Build
- Docker images

### 6. Security checks
- dependency scan
- secret scan
- image scan

### 7. Deploy to QA
- smoke tests
- paper trading dry run

### 8. Manual approval for live-bound services
- risk signoff
- ops signoff

# 28. Testing blueprint

## 28.1 Unit test targets
- order state machine
- risk rules
- symbol mapping
- quantity/price rounding
- fee models
- indicator computations

## 28.2 Integration tests
- order intent to risk decision
- risk pass to execution
- broker update to fill ingestion
- fill ingestion to positions update
- workflow approval to deployment status

## 28.3 End-to-end tests
- login → create strategy → upload version → run backtest → request approval → approve → deploy paper → view orders/fills/positions

## 28.4 Simulation tests
- stale feed
- duplicate fill callbacks
- broker latency spike
- order reject burst
- service restart mid-order lifecycle

# 29. Operational runbooks blueprint
Create these documents early.

## Runbooks
- broker disconnected
- stale market feed
- sudden order rejection spike
- strategy runtime crash loop
- reconciliation mismatch
- daily loss breach
- global kill switch usage
- partial fill investigation
- high slippage investigation
Each runbook should include:
- symptoms
- likely causes
- commands/dashboards to check
- safe actions
- escalation path

# 30. Sprint-by-sprint engineering task board

## Sprint 1: platform skeleton
- create monorepo
- create shared packages
- create Docker local stack
- scaffold web-admin and web-ops
- scaffold identity-service
- scaffold market-registry-service
- scaffold instrument-master-service

## Sprint 2: schema and seeds
- implement PostgreSQL migrations
- implement base seeders
- create roles/permissions
- create market/instrument seeds
- create admin user seed
- build login and layout shell

## Sprint 3: market data foundation
- build market-data-service
- build historical-data-service
- implement venue connector skeleton
- ingest candles
- build feed health checks
- build market dashboard basics

## Sprint 4: strategy foundation
- build strategy-service
- build strategy SDK
- register strategy
- versions
- build backtest-service
- run first historical backtest
- show results in admin UI

## Sprint 5: risk and orders
- build risk-service
- implement core risk rules
- build order-service
- implement order state machine
- build execution-service skeleton
- publish order events

## Sprint 6: paper trading end-to-end
- build paper-trading-service
- connect real-time feed
- simulate fills
- update positions/balances/P&L
- build orders/fills/positions UI
- full paper trading demo

## Sprint 7: governance and audit
- build workflow-service
- build audit-service
- add approvals
- add deployment requests
- add audit timeline views
- add operator actions audit

## Sprint 8: live-readiness foundation
- build broker adapter for chosen venue
- live account read-only sync
- reconciliation service
- incident module
- kill switch flows
- run controlled shadow mode

# 31. Recommended first live implementation path
To reduce risk, the first real delivery path should be:

## Market
- Forex or crypto

## One venue
- One demo broker/exchange first

## Three strategies
- trend following
- mean reversion
- breakout

## Environments
- backtest
- paper
- limited live

## No advanced portfolio optimization yet
Start with fixed allocation and clear risk caps.

# 32. Example service communication choices

## REST
Use for:
- user CRUD
- strategy metadata CRUD
- workflow approvals
- reports
- audit queries

## Kafka events
Use for:
- market data
- strategy signals
- risk checks
- order lifecycle
- positions
- balances
- alerts

## Redis
Use for:
- locks
- short-lived hot state
- dedupe keys
- rate-limiting counters

# 33. Non-functional engineering targets

## Latency targets
- signal to order intent: under 300 ms for MVP
- risk evaluation: under 100 ms typical
- order routing overhead: under 150 ms excluding broker latency

## Reliability targets
- no silent order loss
- at-least-once event delivery with idempotent consumers
- ability to recover state after service restart

## Security targets
- all secrets outside repo
- all admin routes authenticated
- RBAC enforced in backend, not UI only
- audit for sensitive actions

# 34. Critical implementation rules
- every message consumer must be idempotent
- every event schema must be versioned
- every service must expose health/readiness endpoints
- every deployment change must be auditable
- every strategy version must be immutable after registration
- every broker adapter must normalize errors into internal codes
- every manual override must include actor, reason, and timestamp