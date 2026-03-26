# 1. Goal
Add a production-grade execution control layer for:
- broker/exchange abstraction
- routing rules
- partial fills
- cancel and replace flows
- execution quality measurement
- slippage and fee attribution
- reconciliation of broker vs internal state
- ambiguous-state handling
- execution incident workflows
This is what turns a trading platform into something that can safely operate against external venues.

# 2. Core principle
Execution must be treated as its own governed domain.
The platform should behave like this:

```
Portfolio Target
-> Order Intent
-> Risk Approved
-> Execution Routing
-> Broker Order Lifecycle
-> Fill Events
-> Position Update
-> Reconciliation
```

Not like this:

```
Order Intent
-> Submit Once
-> Assume Filled
```

No production trading platform should assume broker state equals internal state without verification.

# 3. Execution architecture layers
Execution should be separated into layers.

## 3.1 Order intent layer
Owned by order-service.
Represents:
- what the platform wants to do

## 3.2 Execution routing layer
Owned by execution-service.
Represents:
- where and how the order should be sent

## 3.3 Broker adapter layer
Owned by broker-adapter services.
Represents:
how
- venue-specific APIs are called and interpreted

## 3.4 Broker order lifecycle layer
Represents:
- submitted
- acknowledged
- partially filled
- filled
- cancel pending
- cancelled
- replaced
- rejected
- expired
- ambiguous

## 3.5 Reconciliation layer
Represents:
- what the broker says happened
- what the platform thinks happened
- what must be corrected or investigated

# 4. Broker abstraction model
Each venue must plug into a canonical interface.

## 4.1 Canonical adapter responsibilities
Every adapter should handle:
- authentication
- account state retrieval
- position retrieval
- order submission
- cancel order
- replace order
- order status polling or streaming
- fills retrieval
- historical data retrieval if supported
- symbol translation
- broker error normalization
- rate limiting

## 4.2 Canonical internal models
All adapters should map into standard internal objects:
- AccountState
- PositionSnapshot
- OrderRequest
- OrderAck
- OrderReject
- FillRecord
- CancelResult
- ReplaceResult
- BrokerHealthStatus

Strategies and core services should never handle venue-native payloads directly.

# 5. Order routing model
Execution-service should choose the venue path based on policy.

## 5.1 Initial routing modes
Support these first:
- fixed venue routing
- account-bound routing
- market-bound routing
Examples:
- all forex paper orders go to oanda-demo simulation adapter
- all crypto paper orders go to binance-testnet adapter
- EURUSD live orders use account X only

## 5.2 Later routing modes
Add later:
- best venue selection
- fee-aware routing
- liquidity-aware routing
- venue health-aware failover
Do not overbuild smart routing first. Fixed routing is enough initially.

# 6. Execution policy model
Execution policies should be explicit and configurable.
Each policy should define:
- policy id
- routing scope
- preferred venue/account
- allowed order types
- max slippage tolerance
- max retry count
- ambiguous-state handling mode
- cancel timeout
- replace timeout
- passive vs aggressive preference later
Examples:
- forex market orders: IOC only
- crypto breakout strategy: market allowed, max slippage 20 bps
- equities mean reversion: limit orders only during normal hours

# 7. Broker order lifecycle model
You now need a fuller lifecycle.

## 7.1 Canonical execution states
Use:
- `created`
- `submitted`
- `acknowledged`
- `partially_filled`
- `filled`
- `cancel_pending`
- `cancelled`
- `replace_pending`
- `replaced`
- `rejected`
- `expired`
- `ambiguous`

## 7.2 Ambiguous state
This is critical.
Use ambiguous when:
- broker response timed out
- submit result unknown
- cancel may or may not have succeeded
- network failure occurred after request dispatch
Ambiguous orders must not be ignored. They require reconciliation.

# 8. Partial fill handling
Partial fills are normal, especially outside perfect simulation.

## 8.1 What must be tracked
For every broker order:
- original quantity
- cumulative filled quantity
- remaining quantity
- average fill price
- fee accumulation
- last fill time

## 8.2 Lifecycle behavior
Example:

```
submitted
-> acknowledged
-> partially_filled
-> partially_filled
-> filled
```

## 8.3 Position update rule
Position-service must update incrementally per fill, not only at final fill.

# 9. Cancel and replace flows
These are first-class workflows.

## 9.1 Cancel flow
Used when:
- operator cancels
- timeout reached
- strategy invalidated
- risk escalation triggered
Flow:

```
broker order active
-> cancel requested
-> cancel submitted
-> cancelled or filled before cancel completed
```

## 9.2 Replace flow
Used when:
- repricing a limit order
- resizing a working order
- changing time-in-force where supported
Flow:

```
active order
-> replace requested
-> replace pending
-> replaced
```

Not all brokers support true replace. Some require cancel + resubmit. Adapters must hide that difference.

# 10. Broker adapter hardening
Adapters are one of the highest-risk parts of the system.

## 10.1 Required protections
Add:
- request timeouts
- rate limiting
- retry only where safe
- idempotency keys where broker supports them
- request/response raw payload logging
- normalized error codes
- health checks
- circuit breaker per broker

## 10.2 Error normalization
Map broker-specific errors to internal codes like:
- `BROKER_AUTH_FAILED`
- `BROKER_RATE_LIMITED`
- `BROKER_ORDER_REJECTED`
- `BROKER_ORDER_UNKNOWN`
- `BROKER_TIMEOUT`
- `BROKER_SYMBOL_INVALID`
- `BROKER_MARKET_CLOSED`
- `BROKER_INSUFFICIENT_MARGIN`
This keeps the rest of the platform consistent.

# 11. Fee and slippage attribution
Execution quality must be measurable.

## 11.1 Slippage
Track:
- intended price
- decision price
- submitted price if applicable
- fill price
- slippage amount
- slippage bps

## 11.2 Fees
Track:
- fee amount
- fee currency
- fee type if available
- maker/taker classification later if available

## 11.3 Attribution dimensions
Report by:
- strategy
- instrument
- venue
- account
- time period
- order type
This is essential for deciding whether a strategy is actually profitable after real execution.

# 12. Execution quality metrics
Add execution metrics as first-class records.

## 12.1 First metrics to compute
- average slippage bps
- median slippage bps
- fill ratio
- average time to acknowledgment
- average time to full fill
- reject rate
- cancel success rate
- replace success rate
- fee per notional traded

## 12.2 Quality views
Build read models for:
- execution by venue
- execution by strategy
- worst slippage instruments
- most rejected orders
- slowest acknowledgments

# 13. Reconciliation model
This is one of the most important layers.
Reconciliation compares:
- internal orders
- internal fills
- internal positions
- broker orders
- broker fills
- broker positions
- broker balances

## 13.1 Reconciliation types
Support:
- order reconciliation
- fill reconciliation
- position reconciliation
- balance reconciliation

## 13.2 Reconciliation timing
Run:
- near-real-time checks
- end-of-day full reconciliation
- start-of-day baseline reconciliation

# 14. Reconciliation issue model
When state differs, open a formal issue.
Each issue should record:
- issue id
- issue type
- account id
- venue id
- severity
- internal reference
- external reference
- detected difference
- recommended action
- status
- detected at
- resolved at

## Status values
- open
- investigating
- operator_review
- resolved_internal_adjustment
- resolved_broker_confirmed
- false_positive
- escalated

# 15. Ambiguous-state resolution workflow
Ambiguous broker outcomes are unavoidable.

## Example
Order submit request times out.
You do not know whether:
- broker never received it
- broker received it and accepted it
- broker received it and filled it

## Required workflow
1. mark broker order as ambiguous
2. raise execution incident or reconciliation issue
3. query broker state
4. reconcile against known internal state
5. resolve into one of:
    - rejected
    - active
    - partially filled
    - filled
    - cancelled

This should be an explicit operational flow, not a hidden retry loop.

# 16. Database additions

## Create sql/011_execution_reconciliation.sql.

```SQL
CREATE TABLE IF NOT EXISTS execution_policies (
    id UUID PRIMARY KEY,
    policy_code VARCHAR(100) UNIQUE NOT NULL,
    scope_type VARCHAR(50) NOT NULL,
    scope_id UUID,
    preferred_venue_id UUID,
    preferred_account_id UUID,
    allowed_order_types JSONB,
    max_slippage_bps NUMERIC(12,6),
    max_retry_count INT NOT NULL DEFAULT 0,
    cancel_timeout_seconds INT,
    replace_timeout_seconds INT,
    ambiguous_handling_mode VARCHAR(50) NOT NULL DEFAULT 'manual_review',
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS broker_order_state_history (
    id UUID PRIMARY KEY,
    broker_order_id UUID NOT NULL REFERENCES broker_orders(id),
    from_state VARCHAR(50),
    to_state VARCHAR(50) NOT NULL,
    transition_reason VARCHAR(255),
    metadata_json JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS execution_quality_metrics (
    id UUID PRIMARY KEY,
    broker_order_id UUID NOT NULL REFERENCES broker_orders(id),
    order_intent_id UUID NOT NULL REFERENCES order_intents(id),
    strategy_deployment_id UUID,
    instrument_id UUID NOT NULL,
    venue_id UUID NOT NULL,
    intended_price NUMERIC(24,10),
    submitted_price NUMERIC(24,10),
    avg_fill_price NUMERIC(24,10),
    slippage_amount NUMERIC(24,10),
    slippage_bps NUMERIC(12,6),
    total_fee_amount NUMERIC(24,10),
    fee_currency VARCHAR(20),
    ack_latency_ms INT,
    full_fill_latency_ms INT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS reconciliation_runs (
    id UUID PRIMARY KEY,
    run_type VARCHAR(50) NOT NULL,
    account_id UUID,
    venue_id UUID,
    status VARCHAR(50) NOT NULL DEFAULT 'running',
    summary_json JSONB,
    started_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS reconciliation_issues (
    id UUID PRIMARY KEY,
    reconciliation_run_id UUID REFERENCES reconciliation_runs(id),
    issue_type VARCHAR(100) NOT NULL,
    account_id UUID,
    venue_id UUID,
    severity VARCHAR(20) NOT NULL,
    internal_ref VARCHAR(255),
    external_ref VARCHAR(255),
    difference_json JSONB,
    recommended_action VARCHAR(100),
    status VARCHAR(50) NOT NULL DEFAULT 'open',
    correlation_id UUID,
    detected_at TIMESTAMPTZ NOT NULL,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

# 17. Execution-service responsibilities after this pack
Execution-service should now do more than simulate fills.
It should:
- select execution policy
- route to the correct adapter
- persist broker order state history
- track partial fills
- calculate execution quality metrics
- emit execution events
- raise ambiguous-state issues
- integrate with reconciliation workflows
Execution-service becomes the official owner of the broker-order lifecycle.

# 18. Broker adapter service contract update
Extend the adapter contract to include:
- `get_open_orders(account_ref)`
- `get_order(external_order_id)`
- `get_fills(account_ref, since_time)`
- `cancel_order(external_order_id)`
- `replace_order(external_order_id, changes)`
- `get_balances(account_ref)`
- `health_check()`
Also require normalized return objects for:
- ack
- reject
- partial fill update
- final fill
- cancel result
- replace result

# 19. Execution events to add
Add these topics:
- `execution.order_submitted`
- `execution.order_acknowledged`
- `execution.order_partially_filled`
- `execution.order_filled`
- `execution.order_cancelled`
- `execution.order_rejected`
- `execution.order_ambiguous`
- `execution.quality.computed`
- `reconciliation.issue.detected`
- `reconciliation.issue.resolved`
These should feed:
- audit-service
- ops read models
- reporting-service
- incident workflows

# 20. Order-service interaction changes
Order-service should remain the owner of order-intent lifecycle, but execution-service owns broker order lifecycle.
That means:
- order-service tracks intent and high-level state
- execution-service tracks broker specifics and fill progression
A good pattern is:
- order-service consumes execution events and updates intent status projection
- execution-service persists detailed broker order state history

# 21. Position-service interaction changes
Position-service must now consume:
- partial fill events
- final fill events
It should update incrementally and remain idempotent.
That means:
- duplicate fill event must not double-apply quantity
- fill ids must be tracked as processed events
This is especially important when using event-driven delivery.

# 22. Reconciliation service design
Add a dedicated `reconciliation-service` or expand an existing service.

## Responsibilities
- schedule reconciliation runs
- fetch broker state through adapters
- compare with internal state
- open issues
- expose issue APIs
- track resolution workflow

## First implementation order
1. order reconciliation
2. fill reconciliation
3. position reconciliation
4. balance reconciliation
That is a practical sequence.

# 23. First reconciliation rules
Start with simple deterministic comparisons.

## 23.1 Order reconciliation
Compare:
- internal broker_order external_order_id
- broker status
- internal status
- order quantity
- filled quantity

## 23.2 Fill reconciliation
Compare:
- broker fill ids or derived fill identity
- quantities
- prices
- fee values if available

## 23.3 Position reconciliation
Compare:
- net quantity by instrument
- optionally average price if broker provides it

## 23.4 Balance reconciliation
Compare:
- cash balances
- available margin
- used margin where provided

# 24. Execution incident handling
Some issues are more than reconciliation problems. They are incidents.
Examples:
- repeated ambiguous submits
- high reject rate spike
- unusual slippage spike
- adapter auth failure
- broker status endpoint down
- cancel requests not taking effect
These should raise:
- incident records
- alerts
- possible risk escalation
- possible temporary venue halt

# 25. Risk integration
Risk-service should consume execution and reconciliation signals too.
Examples:
- repeated execution rejects -> operational breach
- slippage above threshold -> warning or halt by policy
- unresolved reconciliation issue -> block new orders on account
- ambiguous orders above threshold -> account degradation
This is how execution quality becomes part of risk control.

# 26. Admin UI additions
Add pages for:
- execution policies
- broker adapters
- venue/account routing
- reconciliation runs
- reconciliation issues
- execution quality by strategy
- execution quality by venue

## Execution policy detail page
Show:
- scope
- preferred venue/account
- allowed order types
- max slippage
- retry/cancel timeouts
- ambiguous handling mode

# 27. Ops UI additions
Add pages for:
- live broker orders
- partial fills
- ambiguous orders
- reconciliation issues
- adapter health
- execution quality dashboard
- reject analysis

## Important dashboard widgets
- active ambiguous orders
- unresolved reconciliation issues
- reject rate by venue
- average slippage today
- average fill latency today
- account state drift alerts

# 28. Manual test scenarios
You should intentionally test ugly execution cases.

## Scenario 1: normal fill
Expected:
- submitted -> acknowledged -> filled
- quality metrics computed
- no reconciliation issue

## Scenario 2: partial fill
Expected:
- submitted -> acknowledged -> partially_filled -> filled
- position updates incrementally
- metrics computed on final completion

## Scenario 3: reject
Expected:
- rejected state
- normalized error code
- no position update
- audit visible

## Scenario 4: cancel race
Cancel submitted while order fills.
Expected:
- final state resolved clearly
- no silent inconsistency
- state history preserved

## Scenario 5: ambiguous timeout
Expected:
- ambiguous state
- reconciliation issue opened
- operator visibility in UI

## Scenario 6: broker/internal position mismatch
Expected:
- reconciliation issue created
- severity set
- status tracked to resolution

# 29. Suggested implementation order

## Stage 1
- add DB tables
- add broker order state history
- add execution quality metric calculation
- extend adapter interfaces

## Stage 2
- implement partial fill lifecycle
- add cancel/reject handling
- expose broker-order detail endpoints

## Stage 3
- build reconciliation-service
- implement order and fill reconciliation
- add issue persistence and UI

## Stage 4
- add position reconciliation
- add adapter health monitoring
- integrate execution incidents with risk

## Stage 5
- add better routing policies
- add venue/account dashboards
- tighten ambiguous-state handling

# 30. Guardrails for this stage
Implement these rules now:
- never assume broker fill == internal fill without durable persistence
- every broker state transition must be recorded
- ambiguous orders must open an explicit issue
- duplicate fill processing must be idempotent
- reconciliation issues must be visible and auditable
- execution quality must be measurable per strategy and venue
- repeated adapter failures must degrade trading eligibility

# 31. What this unlocks
After this pack, the platform gains:
- realistic broker lifecycle handling
- measurable execution quality
- safer live operations
- visibility into venue quality
- recovery path for ambiguous states
- controlled reconciliation across orders, fills, and positions
This is one of the biggest jumps toward production credibility.

# 32. What should come next
The next correct step is:

## Volume 12: governance, approvals, compliance, and operating workflows pack
That should add:
- promotion workflows for strategy versions
- deployment approvals
- change management
- exception approvals
- maker-checker flows
- compliance exports
- audit timelines by resource
- incident acknowledgment and resolution workflows
- role-based operating procedures
That is the layer that makes the platform enterprise-manageable by teams, not just technically capable.

This is the layer that makes the platform operable by a real team. Up to now, the platform is becoming technically strong, but enterprise trading systems also need controlled human processes around them. This pack adds:
- strategy promotion workflows
- deployment approvals
- maker-checker controls
- change management
- exception approvals
- compliance-ready exports
- incident workflows
- operational accountability
- role-based governance
This is what turns a strong trading engine into an enterprise operating system.