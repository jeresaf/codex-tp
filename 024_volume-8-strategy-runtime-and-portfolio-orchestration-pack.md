# 1. Goal
Add the layer that turns market inputs into coordinated trading decisions across many strategies and many markets.
This pack introduces:
- strategy runtime workers
- strategy deployments
- signal lifecycle
- portfolio target generation
- capital allocation
- conflict resolution across strategies
- runtime supervision
- paper/live separation
- health monitoring for strategy processes
At this stage, the system evolves from:
- order workflow platform
into:
- decision platform
- portfolio platform
- strategy execution platform

# 2. Core architectural shift
Until now, the system starts at the order layer.
Now the flow starts earlier:

```
Market Data
-> Feature Updates
-> Strategy Runtime
-> Signals
-> Portfolio Engine
-> Portfolio Targets
-> Order Intents
-> Risk
-> Execution
-> Positions / P&L
```

This separation is essential.
Strategies should not directly place orders. They should produce:
- signals
- proposed targets
- order recommendations
Then the portfolio layer decides what actually gets traded.

# 3. New bounded domains added

## 3.1 Strategy runtime domain
Responsibilities:
- load approved strategy versions
- run them in isolated workers
- feed them market data/features
- collect signals
- track health and heartbeats
- restart failed runtimes where allowed

## 3.2 Signal domain
Responsibilities:
- store signals
- version signal schema
- track signal confidence/strength
- tie signals to strategy versions and deployments
- support replay and backtesting consistency

## 3.3 Portfolio orchestration domain
Responsibilities:
- convert many signals into a coherent target portfolio
- resolve conflicts
- apply capital allocation rules
- produce target exposures
- hand off to order generation

## 3.4 Allocation domain
Responsibilities:
- capital budgets
- sleeve allocations
- strategy weights
- regime-adjusted scaling
- drawdown-based deallocation

## 3.5 Runtime supervision domain
Responsibilities:
- worker lifecycle
- deployment status
- runtime configuration
- crash loops
- health checks
- kill/pause/resume actions

# 4. Service additions
Add these services next.

## New services
- `strategy-runtime-service`
- `signal-service`
- `portfolio-service`
- `allocation-service` or allocation inside portfolio-service initially
- `runtime-supervisor-service` or supervisor module inside strategy-runtime-service initially
For the first implementation, you can keep:
- `allocation` inside `portfolio-service`
- `runtime supervision` inside `strategy-runtime-service`
That keeps complexity manageable.

# 5. New core event flow

## 5.1 Strategy-to-order pipeline

```
market_data.candle.closed / features.updated
    -> strategy-runtime-service consumes
    -> strategy.signal.generated published

portfolio-service consumes strategy.signal.generated
    -> applies allocation and conflict resolution
    -> publishes portfolio.target.generated

order-service consumes portfolio.target.generated
    -> creates order_intent
    -> publishes order_intent.created

then existing workflow continues:
    -> risk
    -> execution
    -> position
    -> audit
```

# 6. Strategy deployment model
A strategy cannot just “exist.” It must be deployed.

## 6.1 Deployment entity
Each deployment should define:
- which strategy version
- which environment
- which market scope
- which instruments
- which account
- which capital budget
- runtime mode
- whether it is enabled
- when it started/stopped

## 6.2 Deployment scopes
Support:
- paper deployment
- live deployment
- shadow deployment

### Paper
Real-time market data, simulated orders.

### Live
Real-time market data, real capital.

### Shadow
Runs against live market data, emits signals, but does not place orders.
Shadow mode is extremely useful before live rollout.

# 7. Strategy runtime architecture

## 7.1 Runtime model
Each deployed strategy runs in an isolated worker process.
Inputs:
- market data
- features
- position snapshots
- account state if needed
- runtime clock events
Outputs:
- signals
- optional diagnostics
- heartbeat events
- exceptions/failure events

## 7.2 Isolation rules
Each runtime should be isolated enough so one bad strategy does not crash the entire engine.
Minimum safety rules:
- one worker per deployment or controlled worker pool
- strategy timeout limits
- memory limits later
- no direct broker/network calls from strategy logic
- no direct DB writes from strategy logic

## 7.3 Runtime loop
Typical loop:

```
worker starts
  -> loads deployment config
  -> loads strategy artifact
  -> initializes strategy instance
  -> subscribes to needed event streams
  -> on each candle/feature update:
       run strategy logic
       produce zero or more signals
  -> emit heartbeats
  -> shutdown cleanly on command
```

# 8. Strategy SDK upgrade
The SDK now needs stronger runtime contracts.

## 8.1 Required strategy metadata
Each strategy artifact should expose:
- strategy_code
- version
- supported_markets
- supported_asset_classes
- supported_timeframes
- required_features
- warmup_period
- parameter_schema
- signal_schema_version

## 8.2 Signal output contract
A strategy signal should be standardized.
Example:

```JSON
{
  "signal_id": "uuid",
  "strategy_deployment_id": "uuid",
  "strategy_version_id": "uuid",
  "instrument_id": "uuid",
  "timestamp": "2026-03-18T10:15:00Z",
  "signal_type": "directional",
  "direction": "long",
  "strength": 0.82,
  "confidence": 0.76,
  "time_horizon": "short_term",
  "reason_codes": ["ma_cross", "trend_filter"],
  "metadata": {
    "fast_ma": 1.0821,
    "slow_ma": 1.0804
  }
}
```

## 8.3 Strategy return types
Strategies should return one of:
- no signal
- directional signal
- target weight proposal
- volatility estimate
- regime classification
For the first portfolio engine, directional signals plus strength/confidence are enough.

# 9. Signal domain design

## 9.1 Signal entity
A signal should record:
- signal id
- deployment id
- strategy version id
- instrument id
- timestamp
- type
- direction
- strength
- confidence
- time horizon
- reason codes
- metadata
- correlation id

## 9.2 Signal retention
Signals should be durable because they are essential for:
- attribution
- backtesting comparison
- incident review
- model analysis
- audit

## 9.3 Signal quality controls
Add checks for:
- duplicate signal id
- invalid instrument
- unsupported signal type
- stale timestamps
- confidence outside allowed range

# 10. Portfolio engine responsibilities
This is one of the most important new layers.

## The portfolio engine must:
- consume signals from many strategies
- combine them into a single view
- apply capital budgets
- net conflicting exposures
- respect concentration limits
- produce final target positions or target deltas
It must not just pass through strategy outputs blindly.

# 11. Portfolio target model

## 11.1 Target types
Support at least:
- target quantity
- target notional
- target weight
- delta order recommendation
Best first choice:
- target quantity or target notional

## 11.2 Portfolio target event
Example:

```JSON
{
  "target_id": "uuid",
  "account_id": "uuid",
  "instrument_id": "uuid",
  "timestamp": "2026-03-18T10:16:00Z",
  "target_quantity": "2000",
  "current_quantity": "1000",
  "delta_quantity": "1000",
  "source_signals": [
    "signal-uuid-1",
    "signal-uuid-2"
  ],
  "allocation_context": {
    "strategy_weight": 0.15,
    "capital_budget": 25000
  }
}
```

# 12. Multi-strategy conflict resolution
This is the heart of multi-strategy orchestration.

## 12.1 Example conflict
- Strategy A says long EURUSD
- Strategy B says short EURUSD
- Strategy C says no action
The portfolio engine must decide:
- net long
- net short
- flat
- scaled exposure

## 12.2 Conflict resolution policies
Support these policies:

### Weighted netting
Convert each signal into a signed score and sum them.
Example:
- A = +0.8
- B = -0.4
- Net = +0.4

### Priority hierarchy
Some strategies override others.
Useful later, but not best as default.

### Sleeve separation
Different sleeves may trade independently, but even then account-level risk must aggregate.

### Confidence-weighted voting
Higher-confidence signals get more influence.
Best first implementation:
**weighted netting with strategy allocation weights**

# 13. Allocation engine design
The allocation engine decides how much capital each strategy may influence.

## 13.1 Allocation levels
Use this hierarchy:

### Master portfolio
Total capital.

### Sleeve
Examples:
- FX sleeve
- Crypto sleeve
- Equities sleeve

### Strategy allocation
Examples:
- FX trend = 20%
- FX mean reversion = 10%
- Crypto breakout = 15%

### Instrument cap
Per-instrument exposure cap.

## 13.2 Allocation methods to support first
- fixed percent allocation
- max notional cap
- volatility targeting later
- drawdown-adjusted allocation later
Best first implementation:
- fixed allocation + per-instrument caps

# 14. Portfolio service first algorithm
A clean first portfolio algorithm is:

## Step 1
Collect current active signals for an instrument.

## Step 2
Convert each signal to a signed weighted score:
- long => positive
- short => negative
- multiply by strategy allocation weight
- multiply by confidence/strength

## Step 3
Compute net desired exposure score.

## Step 4
Map score to target quantity based on:
- account capital budget
- instrument-specific max size
- risk caps

## Step 5
Publish `portfolio.target.generated`.
This is simple, explainable, and extensible.

# 15. Signal-to-target example
Assume:
- Strategy A allocation = 20%
- Strategy B allocation = 10%
Signals:
- A long EURUSD, strength 0.9, confidence 0.8
- B short EURUSD, strength 0.7, confidence 0.6
Weighted scores:
- A = +0.9 × 0.8 × 0.20 = +0.144
- B = -0.7 × 0.6 × 0.10 = -0.042
- net = +0.102
Portfolio engine maps `+0.102` into target size under current budget and caps.

# 16. Order generation from targets
The order-service should stop being manually fed most of the time.
New order flow:

```
portfolio.target.generated
    -> order-service consumes
    -> compare target with current position
    -> compute delta
    -> create order_intent only if delta exceeds threshold
```

## Thresholds to add
- minimum notional threshold
- minimum quantity threshold
- cooldown between repeated rebalances
- no-op if target delta is too small
This avoids overtrading.

# 17. Strategy runtime health model
Every deployment must be observable.

## 17.1 Heartbeat event
Each runtime should emit:
- deployment id
- strategy version id
- worker id
- environment
- timestamp
- status
- last processed event time
Example status:
- healthy
- warming_up
- paused
- degraded
- crashed

## 17.2 Runtime health table
Track latest heartbeat per deployment for UI and alerts.

## 17.3 Failure conditions
Trigger alerts if:
- no heartbeat for N seconds
- repeated restart loop
- repeated signal generation exceptions
- high processing lag
- stale input data

# 18. Strategy deployment lifecycle
Use these states:
- draft
- approved
- starting
- running
- paused
- stopping
- stopped
- failed
- archived

## Lifecycle flow

```
draft -> approved -> starting -> running
running -> paused -> running
running -> stopping -> stopped
starting/running -> failed
stopped -> archived
```

# 19. Runtime supervisor design
The runtime supervisor controls worker processes.

## Responsibilities
- start deployment worker
- stop deployment worker
- restart failed worker within policy
- block startup if strategy not approved
- track crash count
- emit deployment status events

## Safety controls
- max restart attempts in a window
- quarantine deployment after repeated failures
- require manual action for repeated live failures

# 20. Paper vs live runtime separation
This is non-negotiable.

## Paper runtime
- paper data or live market data
- emits signals
- portfolio targets routed to paper order flow only

## Live runtime
- live data
- live portfolio targets
- live risk and execution only after approvals

## Technical rule
Paper and live deployments must not share:
- accounts
- execution topics
- deployment ids
- operator permissions
Separation can be by:
- environment field
- topic namespace
- DB scope
- deployment scope
Best to use all of the above where practical.

# 21. New topic catalog for strategy and portfolio layers
Add these topics:
- `strategy.deployment.changed`
- `strategy.runtime.heartbeat`
- `strategy.signal.generated`
- `strategy.signal.rejected`
- `portfolio.target.generated`
- `portfolio.target.rejected`
- `allocation.updated`
Later:
- `regime.detected`
- `strategy.runtime.failed`
- `deployment.supervisor.action_taken`

# 22. Event schemas to add

## 22.1 `strategy.signal.generated`

```JSON
{
  "event_id": "uuid",
  "event_type": "strategy.signal.generated",
  "event_version": 1,
  "source_service": "strategy-runtime-service",
  "environment": "paper",
  "occurred_at": "2026-03-18T10:15:00Z",
  "correlation_id": "uuid",
  "causation_id": "market-event-id",
  "actor_type": "strategy",
  "actor_id": "deployment-uuid",
  "payload": {
    "signal_id": "uuid",
    "strategy_deployment_id": "uuid",
    "strategy_version_id": "uuid",
    "instrument_id": "uuid",
    "timestamp": "2026-03-18T10:15:00Z",
    "signal_type": "directional",
    "direction": "long",
    "strength": 0.82,
    "confidence": 0.76,
    "time_horizon": "short_term",
    "reason_codes": ["ma_cross"],
    "metadata": {}
  }
}
```

## 22.2 `portfolio.target.generated`

```JSON
{
  "event_id": "uuid",
  "event_type": "portfolio.target.generated",
  "event_version": 1,
  "source_service": "portfolio-service",
  "environment": "paper",
  "occurred_at": "2026-03-18T10:16:00Z",
  "correlation_id": "uuid",
  "causation_id": "signal-event-id",
  "actor_type": "system",
  "actor_id": "portfolio-service",
  "payload": {
    "target_id": "uuid",
    "account_id": null,
    "instrument_id": "uuid",
    "target_quantity": "1000",
    "current_quantity": "0",
    "delta_quantity": "1000",
    "source_signal_ids": ["uuid"],
    "allocation_snapshot": {
      "strategy_weight": 0.2,
      "capital_budget": 10000
    }
  }
}
```

## 22.3 strategy.runtime.heartbeat

```JSON
{
  "event_id": "uuid",
  "event_type": "strategy.runtime.heartbeat",
  "event_version": 1,
  "source_service": "strategy-runtime-service",
  "environment": "paper",
  "occurred_at": "2026-03-18T10:16:05Z",
  "correlation_id": "uuid",
  "causation_id": "deployment-uuid",
  "actor_type": "system",
  "actor_id": "worker-uuid",
  "payload": {
    "strategy_deployment_id": "uuid",
    "strategy_version_id": "uuid",
    "worker_id": "uuid",
    "status": "healthy",
    "last_processed_event_at": "2026-03-18T10:16:00Z"
  }
}
```

## 23. Database additions

### Create sql/008_strategy_portfolio.sql.

```SQL
CREATE TABLE IF NOT EXISTS strategy_signals (
    id UUID PRIMARY KEY,
    strategy_deployment_id UUID NOT NULL,
    strategy_version_id UUID NOT NULL,
    instrument_id UUID NOT NULL,
    signal_type VARCHAR(50) NOT NULL,
    direction VARCHAR(20),
    strength DOUBLE PRECISION,
    confidence DOUBLE PRECISION,
    time_horizon VARCHAR(50),
    reason_codes JSONB,
    metadata_json JSONB,
    correlation_id UUID,
    signal_timestamp TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS portfolio_targets (
    id UUID PRIMARY KEY,
    account_id UUID,
    instrument_id UUID NOT NULL,
    target_quantity NUMERIC(24,10),
    current_quantity NUMERIC(24,10),
    delta_quantity NUMERIC(24,10),
    source_signal_ids JSONB,
    allocation_snapshot JSONB,
    correlation_id UUID,
    target_timestamp TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS strategy_runtime_heartbeats (
    id UUID PRIMARY KEY,
    strategy_deployment_id UUID NOT NULL,
    strategy_version_id UUID NOT NULL,
    worker_id UUID NOT NULL,
    status VARCHAR(50) NOT NULL,
    last_processed_event_at TIMESTAMPTZ,
    correlation_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE strategy_deployments
ADD COLUMN IF NOT EXISTS deployment_status VARCHAR(50) DEFAULT 'draft';

ALTER TABLE strategy_deployments
ADD COLUMN IF NOT EXISTS runtime_mode VARCHAR(20) DEFAULT 'paper';

ALTER TABLE strategy_deployments
ADD COLUMN IF NOT EXISTS capital_budget NUMERIC(24,10);

ALTER TABLE strategy_deployments
ADD COLUMN IF NOT EXISTS instrument_scope_json JSONB;
```

# 24. Strategy runtime service design

## 24.1 Internal components
`strategy-runtime-service` should have:
- deployment loader
- artifact loader
- worker manager
- market event consumer
- signal emitter
- heartbeat emitter
- failure handler

## 24.2 Worker model
For the starter implementation:
- one Python process per deployment
- consume one timeframe stream
- emit signals into outbox
That is enough to prove the model.

## 24.3 Artifact loading
Approved strategy versions should reference:
- local file path in dev
- object storage URI later
The runtime loads the artifact, validates metadata, initializes the strategy class, and starts processing.

# 25. Portfolio service design

## 25.1 Inputs
- `strategy.signal.generated`
- current positions
- strategy deployment allocations
- instrument caps
- account-level budget

## 25.2 Outputs
- `portfolio.target.generated`

## 25.3 First implementation policy
For each signal:
- pull current position
- compute weighted score
- convert to target quantity
- if delta > threshold, emit target
Later, portfolio-service can combine multiple active signals over a time window before emitting.

# 26. Order-service changes under strategy mode
Order-service should now consume `portfolio.target.generated`.
Logic:
- compare target quantity vs current quantity
- compute delta order
- create order intent only when meaningful
- publish `order_intent.created`
This keeps order-service as the order lifecycle owner while portfolio-service owns intent formation.

# 27. UI additions

## 27.1 Admin UI
Add pages for:
- strategy deployments
- deployment detail
- runtime health
- signal history
- portfolio targets

## 27.2 Ops UI
Add pages for:
- live runtime monitor
- heartbeats by deployment
- recent signals
- target decisions
- stuck deployment alerts

## 27.3 Deployment detail page should show:
- deployment metadata
- assigned account
- capital budget
- instrument scope
- status
- recent heartbeats
- recent signals
- recent targets
- pause/resume controls

# 28. Manual test scenario for this stage
The first strategy-runtime proof should work like this:

## Step 1
Seed one approved deployment:
- strategy: moving average cross
- environment: paper
- instrument: EURUSD
- capital budget: 10000

## Step 2
Feed candle events into the runtime.

## Step 3
Strategy runtime emits signal:
- long EURUSD

## Step 4
Portfolio service consumes signal and emits target:
- target quantity 1000

## Step 5
Order-service consumes target and creates order intent.

## Step 6
Existing event-driven order lifecycle continues:
- risk
- execution
- position
- audit

## Step 7
Ops UI shows:
- signal
- target
- order
- position
That becomes the first true multi-layer engine demonstration.

# 29. Guardrails for strategy runtime
Add these now:
- max signals per deployment per minute
- min interval between repeated identical signals
- stale deployment auto-pause if no heartbeat
- reject signal if deployment not running
- reject signal if strategy version not approved
- block live deployment without risk approval
- pause deployment on repeated unhandled exceptions

# 30. Recommended implementation order
Do not build everything simultaneously.

## Stage 1
- add DB tables
- add strategy deployment status model
- create runtime heartbeat events

## Stage 2
- build strategy-runtime-service skeleton
- load one sample strategy artifact
- emit heartbeat events

## Stage 3
- consume one candle event type
- emit one sample signal event

## Stage 4
- build signal persistence
- build portfolio-service simple logic
- emit target events

## Stage 5
- connect order-service consumer to `portfolio.target.generated`

## Stage 6
- add admin and ops screens for deployments, signals, targets

# 31. What this unlocks
After this pack, the platform can support:
- many strategies side by side
- paper/live/shadow deployments
- centralized portfolio construction
- clear separation between signal generation and trade execution
- future expansion into:
    - regime switching
    - ensemble strategies
    - dynamic capital allocation
    - cross-market orchestration
This is the foundation of a real fund-style engine.

# 32. What should come next
The next correct step is:

## Volume 9: market data, feature store, and research/backtest alignment pack
That should add:
- canonical market data ingestion
- candle/tick normalization
- feature computation pipeline
- feature store
- research-to-runtime consistency
- backtest/live parity model
- warmup and replay mechanisms
That is critical because strategy runtimes are only as good as the data and features they consume.

This is the layer that determines whether the trading engine is merely functional or actually trustworthy. Most trading systems fail here, not because the order flow is wrong, but because:
- research data differs from live data
- backtests use cleaner data than production
- features are computed differently in research and runtime
- warmup windows are inconsistent
- timestamps are mishandled
- symbol mapping drifts across environments