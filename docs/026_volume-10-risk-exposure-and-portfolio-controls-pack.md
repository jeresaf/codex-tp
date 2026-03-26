# 1. Goal
Add a full control framework for:
- pre-trade risk
- post-trade risk
- intraday risk
- strategy-level limits
- sleeve-level limits
- account-level limits
- portfolio-level limits
- live breach handling
- kill switches
- escalation workflows
- operator visibility
This pack makes the engine safer across:
- multiple markets
- multiple strategies
- multiple accounts
- multiple environments

# 2. Core principle
Risk control must sit **above** strategy logic and **before** execution.
The platform should always behave like this:

```
Signal
-> Portfolio Target
-> Order Intent
-> Risk Validation
-> Execution
```

Not this:

```
Signal
-> Execution
```

No strategy should ever bypass risk.

# 3. Risk architecture layers
Risk should exist in stacked layers.

## 3.1 Strategy-level risk
Controls that apply to one strategy deployment.

Examples:
- max position size per strategy
- max trades per hour/day
- max open positions
- cooldown after stop-loss
- signal confidence minimum
- max notional exposure per instrument

## 3.2 Sleeve-level risk
Controls for a group of related strategies.
Examples:
- FX sleeve max gross exposure
- crypto sleeve max drawdown
- mean-reversion sleeve max capital
- event-driven sleeve max concentration

## 3.3 Account-level risk
Controls for the brokerage or exchange account.
Examples:
- max leverage
- max margin usage
- max daily loss
- max open orders
- max notional exposure

## 3.4 Portfolio-level risk
Controls across the whole firm or master portfolio.
Examples:
- total gross exposure
- total net exposure
- currency concentration
- sector concentration
- correlated positions
- aggregate VaR later
- max portfolio drawdown

## 3.5 Operational risk
Controls not driven by market view, but system safety.
Examples:
- stale feed halt
- missing heartbeats
- repeated execution rejects
- reconciliation mismatch
- dependency outage
- clock drift
- abnormal slippage

## 3.6 Governance risk
Controls for approvals and operating policy.
Examples:
- live deployment not approved
- expired credentials
- frozen market
- change window closed
- live trading globally disabled

# 4. Risk service expansion
Your existing `risk-service` should now become a full risk engine.

## Responsibilities
- evaluate order intents pre-trade
- monitor exposures continuously
- monitor P&L and drawdown
- detect breaches
- recommend or enforce actions
- manage kill switches
- persist breach history
- publish risk events
- support operator workflows

## Risk service internal modules
- policy registry
- exposure calculator
- breach detector
- kill-switch manager
- intraday monitor
- post-trade monitor
- escalation engine
- incident integration

# 5. New risk control flow

## Pre-trade flow

```
portfolio.target.generated
  -> order-service creates order_intent
  -> risk-service evaluates:
       strategy scope
       sleeve scope
       account scope
       portfolio scope
       operational scope
  -> result:
       pass
       reject
       pass_with_warning
       force_reduce_only later if needed
```

## Post-trade flow

```
execution.fill.recorded
  -> risk-service updates exposures
  -> risk-service updates realized / unrealized risk state
  -> risk-service checks for breaches
  -> publish breach or exposure update events
```

## Continuous monitoring flow

```
positions.updated / pnl.updated / runtime heartbeat / feed health
  -> risk-service evaluates operating conditions
  -> triggers alerts or kill switches if needed
```

# 6. Risk policy model
Risk policies must be data-driven, not hardcoded.
Each policy should define:
- policy id
- policy code
- scope type
- scope id
- rule type
- threshold config
- severity
- action mode
- enabled flag
- effective time window
- created by
- approval metadata

## Scope types
- strategy_deployment
- strategy_group
- sleeve
- account
- market
- venue
- portfolio
- global

## Severity
- info
- warning
- high
- critical

## Action modes
- alert_only
- reject_new_orders
- pause_strategy
- kill_strategy
- kill_sleeve
- kill_account
- global_halt

# 7. First risk policies to implement
Do not start with advanced VaR. Start with hard, enforceable controls.

## 7.1 Max position size
Per instrument or per strategy.
Example:
- no strategy may hold more than 50,000 EURUSD units

## 7.2 Max daily loss
At strategy, sleeve, account, or portfolio scope.
Example:
- stop new trades if daily realized + unrealized loss exceeds threshold

## 7.3 Max gross exposure
Total absolute exposure across open positions.

## 7.4 Max net exposure
Net directional exposure, useful for currencies and asset classes.

## 7.5 Max open orders
Protect against order storms.

## 7.6 Max leverage / margin usage
Essential for leveraged markets.

## 7.7 Max instrument concentration
Example:
- no more than 25% of sleeve capital in one instrument

## 7.8 Stale feed halt
If market data is stale, reject new trades.

## 7.9 Runtime heartbeat halt
If strategy runtime is unhealthy, block its new orders.

## 7.10 Repeated execution reject halt
If broker rejects too many orders, stop sending new ones until reviewed.
These ten controls will already make the system much safer.

# 8. Exposure model
You need consistent exposure calculations across markets.

## 8.1 Canonical exposure fields
Each open position or target should support:
- quantity
- notional
- direction
- base currency
- quote currency
- leverage effect if relevant
- market value
- unrealized P&L
- realized P&L
- margin used if available

## 8.2 Exposure views to compute
- by strategy
- by sleeve
- by account
- by market
- by instrument
- by currency
- by portfolio total

## 8.3 Market-specific considerations

### Forex
Track:
- base/quote exposure
- pip value
- cross-currency aggregation

### Crypto
Track:
- coin exposure
- stablecoin concentration
- exchange concentration

### Stocks
Track:
- symbol concentration
- sector concentration later
- short vs long exposure

### Futures
Track:
- contract multiplier
- expiry concentration
- rollover risk later

### Options
Add later:
- delta/gamma/vega aggregation

# 9. Breach model
A breach is not just an error. It is a governed event.
Each breach record should store:
- breach id
- policy id
- scope type
- scope id
- severity
- breach type
- current measured value
- threshold
- action taken
- status
- detected at
- resolved at
- correlation id

## Breach statuses
- open
- acknowledged
- action_taken
- resolved
- suppressed
- false_positive

# 10. Kill-switch design
Kill switches must exist at multiple levels.

## 10.1 Global kill switch
Stops all new live trading.

## 10.2 Portfolio kill switch
Stops one portfolio or fund.

## 10.3 Sleeve kill switch
Stops one sleeve, such as crypto.

## 10.4 Account kill switch
Stops one broker/exchange account.

## 10.5 Strategy deployment kill switch
Stops one specific strategy.

## 10.6 Market kill switch
Stops trading in one market, instrument group, or venue.

## 10.7 Kill switch actions
Support:
- reject new orders
- cancel open orders
- pause strategy runtimes
- force reduce-only mode later
- notify operators
Do not make flatten-all automatic in the first implementation unless clearly controlled.
Start with:
- stop new orders
- optionally cancel open orders
- operator decides next step

# 11. Risk event topics
Add these topics:
- `risk.exposure.updated`
- `risk.breach.detected`
- `risk.breach.resolved`
- `risk.policy.updated`
- `risk.kill_switch.triggered`
- `risk.kill_switch.released`
- `risk.order.rejected`
- `risk.order.warning`
These should be consumed by:
- audit-service
- ops UI projections
- notification-service
- incident-service later

# 12. Database additions

## Create sql/010_risk_controls.sql.

```SQL
CREATE TABLE IF NOT EXISTS risk_breaches (
    id UUID PRIMARY KEY,
    risk_policy_id UUID NOT NULL REFERENCES risk_policies(id),
    scope_type VARCHAR(50) NOT NULL,
    scope_id UUID NOT NULL,
    breach_type VARCHAR(100) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    measured_value NUMERIC(24,10),
    threshold_value NUMERIC(24,10),
    details_json JSONB,
    action_taken VARCHAR(100),
    status VARCHAR(50) NOT NULL DEFAULT 'open',
    correlation_id UUID,
    detected_at TIMESTAMPTZ NOT NULL,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS kill_switches (
    id UUID PRIMARY KEY,
    scope_type VARCHAR(50) NOT NULL,
    scope_id UUID,
    switch_action VARCHAR(100) NOT NULL,
    reason TEXT,
    triggered_by_actor_type VARCHAR(50) NOT NULL,
    triggered_by_actor_id UUID,
    status VARCHAR(50) NOT NULL DEFAULT 'active',
    correlation_id UUID,
    triggered_at TIMESTAMPTZ NOT NULL,
    released_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS risk_exposure_snapshots (
    id UUID PRIMARY KEY,
    scope_type VARCHAR(50) NOT NULL,
    scope_id UUID NOT NULL,
    exposure_type VARCHAR(100) NOT NULL,
    instrument_id UUID,
    currency_code VARCHAR(20),
    gross_exposure NUMERIC(24,10),
    net_exposure NUMERIC(24,10),
    notional_value NUMERIC(24,10),
    leverage_value NUMERIC(24,10),
    margin_used NUMERIC(24,10),
    unrealized_pnl NUMERIC(24,10),
    realized_pnl NUMERIC(24,10),
    snapshot_time TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS drawdown_trackers (
    id UUID PRIMARY KEY,
    scope_type VARCHAR(50) NOT NULL,
    scope_id UUID NOT NULL,
    equity_high_watermark NUMERIC(24,10) NOT NULL,
    current_equity NUMERIC(24,10) NOT NULL,
    drawdown_amount NUMERIC(24,10) NOT NULL,
    drawdown_percent NUMERIC(12,6) NOT NULL,
    snapshot_time TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

# 13. Risk service internal rule categories
Organize rule logic cleanly.

## 13.1 Pre-trade rules
Run before execution.
Examples:
- position size
- notional cap
- open order cap
- max leverage
- stale feed
- active kill switch
- runtime unhealthy

## 13.2 Post-trade rules
Run after fills.
Examples:
- gross exposure breach
- concentration breach
- daily loss breach
- drawdown breach

## 13.3 Continuous rules
Run on periodic schedules or event streams.
Examples:
- feed stale
- missed heartbeats
- cumulative execution rejects
- reconciliation drift

# 14. Pre-trade evaluation sequence
The pre-trade risk engine should evaluate in a deterministic order.

## Recommended sequence
1. governance checks
2. kill-switch checks
3. operational checks
4. strategy-level checks
5. sleeve-level checks
6. account-level checks
7. portfolio-level checks
Return:
- decision
- rule results
- strongest severity
- required action
This order helps fail fast when the environment is unsafe.

# 15. Order risk decisions
Support these outcomes first:
- `pass`
- `reject`
- `pass_with_warning`
Later you can add:
- `reduce_only`
- `resize_to_limit`
For now, keep action simple and auditable.

# 16. Drawdown control design
Drawdown is one of the most important operational controls.

## 16.1 Track drawdown at:
- strategy deployment
- sleeve
- account
- total portfolio

## 16.2 Data needed
- realized P&L
- unrealized P&L
- equity snapshots
- high-water marks

## 16.3 Example policies
- pause strategy after 5% drawdown
- halt sleeve after 8% drawdown
- global review after 10% portfolio drawdown
Start with strategy and portfolio drawdown.

# 17. Daily loss control design
This is simpler and should be added early.

## Policy example
If daily P&L for account drops below -$1,000:
- reject all new orders for that account
- raise critical breach
- optionally trigger account kill switch

## Daily reset rule
Use a clear trading day boundary:
- UTC day
or
- market/session day per account
Pick one and keep it consistent. For simplicity, start with UTC day and document it.

# 18. Concentration control design
Concentration risk becomes serious in multi-strategy systems.

## First concentration checks
- max notional per instrument
- max capital per market
- max capital per sleeve
- max exposure per currency

## Later additions
- issuer concentration for equities
- sector concentration
- exchange concentration
- correlated cluster concentration

# 19. Correlation-aware controls
This should start simple.
You do not need a full covariance engine on day one, but you should reserve the design.

## First approximation
Use instrument groups or tags.
Examples:
- EURUSD, GBPUSD, AUDUSD all tagged as `usd_fx_major`
- BTCUSDT, ETHUSDT, SOLUSDT tagged as `crypto_beta`
Then define rules like:
- max net exposure in `crypto_beta`
- max total long USD concentration across FX majors
This is a practical early substitute for full statistical correlation controls.

# 20. Risk projections for UI
Build read models for operator visibility.

## Needed views
- active breaches
- kill switches
- exposures by account
- exposures by strategy
- drawdown by scope
- daily P&L by scope
- rejected orders by risk rule
- feed/risk dependency status
These should be projection-friendly so the UI stays fast.

# 21. Admin UI additions
Add pages for:
- risk policies
- risk policy detail
- kill switches
- exposure dashboard
- drawdown dashboard
- breach history
- rejected order analysis

## Risk policy detail page
Show:
- scope
- thresholds
- severity
- enabled state
- approval metadata
- recent breaches triggered by this policy

# 22. Ops UI additions
Add pages for:
- live breaches
- active kill switches
- account exposure monitor
- strategy exposure monitor
- drawdown monitor
- daily loss monitor

## Ops dashboard badges
Show:
- active critical breaches
- strategies paused by risk
- accounts halted
- markets blocked
- stale feed count
- risk rejection count last hour

# 23. Manual risk test scenarios
You should test the system with intentional breach conditions.

## Scenario 1: max position size reject
Submit target/order above cap.
Expected:
- risk reject
- breach optionally logged if configured
- no execution

## Scenario 2: stale feed halt
Stop market data updates beyond threshold.
Expected:
- new orders rejected
- breach created
- ops dashboard warning

## Scenario 3: daily loss halt
Simulate losses beyond threshold.
Expected:
- account or strategy blocked for new trades
- critical breach recorded

## Scenario 4: strategy heartbeat missing
Stop strategy runtime heartbeat.
Expected:
- operational breach
- strategy orders blocked
- deployment flagged degraded

## Scenario 5: manual kill switch
Trigger strategy kill switch.
Expected:
- new orders rejected for that strategy
- status visible in UI
- audit trail recorded

# 24. Risk evaluation persistence model
The risk evaluation table from earlier should now capture more details.
Add fields or use JSON to include:
- evaluated scopes
- triggered policies
- measured exposures
- kill-switch states
- warnings
- correlation id
That lets you answer:
- why was this order rejected?
- which scope caused the block?
- what was the measured value at the time?

# 25. Breach escalation model
Not all breaches should behave the same.

## Example escalation rules

### Warning
- UI alert only
- no trading halt

### High
- reject new orders in scope
- notify ops

### Critical
- trigger kill switch
- notify ops and risk
- require acknowledgment

Start with rule-based escalation driven by policy severity + action mode.

# 26. Integration with runtime supervision
Risk must be able to influence strategy runtime state.
Examples:
- pause deployment after drawdown breach
- pause deployment after repeated reject storm
- block restart until manual review for repeated failures
This can happen via:
- `risk.breach.detected`
- `risk.kill_switch.triggered`
- `strategy.deployment.changed`
The supervisor should listen and act accordingly.

# 27. Integration with order-service
Order-service should remain the owner of order lifecycle, but it must respect risk state.
When consuming `portfolio.target.generated`:
- check whether scope is blocked
- create order intent
- publish risk request or await risk decision depending on current architecture
- record `risk_rejected` reason cleanly in order detail if blocked
The important point is:
**blocked orders must remain visible, not disappear silently.**

# 28. Suggested implementation order

## Stage 1
- add DB tables
- add active kill-switch lookup
- add max position size and stale feed rules

## Stage 2
- add breach persistence
- add active breach projections
- add UI for policies and breaches

## Stage 3
- add daily loss and drawdown trackers
- compute exposure snapshots
- expose risk dashboards

## Stage 4
- add manual kill switches
- integrate runtime supervisor actions

## Stage 5
- add group/correlation proxy limits via tags
- add sleeve and account controls

# 29. First formulas and computations to implement
Keep them simple and transparent.

## Max position size check
Compare proposed resulting quantity against configured threshold.

## Gross exposure
Sum absolute notionals across positions in scope.

## Net exposure
Sum signed notionals across positions in scope.

## Daily P&L
Use realized + unrealized snapshots within current trading day boundary.

## Drawdown
Track:
- current equity
- peak equity
- drawdown amount
- drawdown percent
These calculations should live in shared packages so runtime, reporting, and risk remain aligned.

# 30. Guardrails for this stage
Implement these rules now:
- no live order can skip pre-trade risk
- kill switches must be checked before new order approval
- risk rejections must be persisted
- breaches must be visible in UI
- operator-triggered risk actions must be audited
- stale feeds must affect trading eligibility
- missing heartbeats must affect trading eligibility
- drawdown and daily-loss policies must be deterministic and documented

# 31. What this unlocks
After this pack, the platform gains:
- enforceable trading safety boundaries
- operator trust
- multi-strategy survivability
- controlled scaling across markets and accounts
- a real control room experience
- a much safer path to live capital
This is the layer that makes the engine operationally credible.

# 32. What should come next
The next correct step is:

## Volume 11: execution quality, broker abstraction, and reconciliation pack
That should add:
- broker/exchange adapter hardening
- order routing policies
- partial fills and cancel/replace flows
- execution quality metrics
- slippage and fee attribution
- reconciliation workflows
- broker state vs internal state comparison
- execution incident handling
That is the next major step toward an enterprise live-trading platform.

This is the layer that makes the platform capable of handling real trading conditions instead of idealized fills. Up to now, execution has mostly been treated as a clean outcome. In production, execution is messy:
- partial fills happen
- cancels race with fills
- brokers reject valid-looking orders
- symbols differ across venues
- fees vary by market and order type
- internal state drifts from broker state
- network failures create ambiguity
This pack closes that gap.