# Phase 0: foundation decisions
Deliverables:
- market selection for first live market
- broker selection
- canonical entity design
- service boundaries
- storage decisions
- event topic standards

# Phase 1: core platform MVP
Build:
- auth + RBAC
- market registry
- instrument master
- market data ingestion
- historical store
- strategy registry
- backtest service
- paper trading service
- risk service
- order service
- execution service
- one broker adapter
- audit service
- basic Vue 3 ops/admin UI
Outcome:
- one market, one or two strategies, full paper lifecycle

# Phase 2: controlled live trading
Build:
- production deployment pipeline
- approval workflow
- kill switches
- reconciliation service
- incident management
- live positions and balances
- slippage and fee reporting
Outcome:
- limited live trading with hard controls

# Phase 3: multi-strategy portfolio layer
Build:
- portfolio service
- allocation engine
- conflict netting
- drawdown-based capital allocation
- strategy performance attribution
Outcome:
- many strategies sharing capital safely

# Phase 4: multi-market enablement
Build:
- additional venue adapters
- futures/options/stock specifics
- calendar/session engine
- corporate action handling
- rollover logic
Outcome:
- platform becomes truly multi-market

# Phase 5: enterprise controls
Build:
- SSO/MFA
- deep compliance exports
- immutable audit improvements
- DR/backup/restore drills
- HA and failover
- advanced access governance

# Phase 6: advanced intelligence
Build:
- regime detection
- meta allocation
- model ensembles
- anomaly detection
- dynamic throttling under stress