# 1. Service catalog

## gateway-service
Public API entrypoint.
- auth handoff
- rate limits
- routing
- UI backend aggregation

## identity-service
- users
- roles
- permissions
- session policies
- MFA enforcement

## config-service
- central configs
- feature flags
- environment config resolution
- config versioning

## workflow-service
- approval flows
- promotion workflows
- change requests
- exception handling

## market-registry-service
- asset class definitions
- venue registry
- trading calendars
- market enablement

## instrument-master-service
- canonical instruments
- symbol mapping
- contract metadata
- rollover metadata

## market-data-service
- streaming ingestion
- raw feed handling
- normalized feed publication
- feed health tracking

## historical-data-service
- historical candles
- ticks
- order book snapshots
- economic event history
- replay data APIs

## feature-service
- feature jobs
- real-time derived values
- reusable feature definitions
- feature lineage metadata

## strategy-service
- strategy metadata
- version registry
- parameter templates
- deployment eligibility

## strategy-runtime-service
- executes approved strategy workers
- handles runtime lifecycle
- heartbeats
- isolation
- crash restart controls

## backtest-service
- backtest orchestration
- scenario config
- cost models
- result generation
- reproducibility tracking

## paper-trading-service
- simulated order handling
- paper fills
- live shadow monitoring
- discrepancy checks

## experiment-service
- experiment tracking
- metric recording
- dataset/model/code linkage

## model-registry-service
- model artifact registry
- version states
- approval states
- rollback candidates

## portfolio-service
- strategy aggregation
- exposure targeting
- capital allocation
- netting logic

## risk-service
- pre-trade checks
- post-trade checks
- real-time breach detection
- kill switch management

## order-service
- order intent lifecycle
- state transitions
- order storage
- event publication

## execution-service
- broker routing
- order submission
- cancel/replace
- fill ingestion
- execution metrics

## broker-adapter-service-*
One service per broker or venue family.
Examples:
- broker-adapter-oanda
- broker-adapter-binance
- broker-adapter-interactivebrokers
- broker-adapter-betfair

## position-service
- positions
- balances
- P&L
- fees
- account exposure state

## reconciliation-service
- broker-vs-platform comparison
- position and fill reconciliation
- discrepancy workflow

## audit-service
- immutable logs
- actor/event history
- change records
- compliance export

## reporting-service
- dashboards
- PDFs/exports later
- scheduled summaries
- performance attribution

## notification-service
- email
- SMS
- Slack/webhook integrations
- critical incident alerts

## observability-agent
- logs
- traces
- service metrics
- health heartbeat publishing

# 2. Service interaction pattern

## Synchronous APIs
Use for:
- admin CRUD
- approvals
- reporting queries
- configuration lookups

## Asynchronous events
Use for:
- market data
- features
- signals
- orders
- fills
- positions
- alerts
- deployment notifications