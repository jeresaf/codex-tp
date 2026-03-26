# 1. Major platform domains

## A. Identity and access
Responsibilities:
- users
- roles
- permissions
- teams
- MFA
- SSO
- service accounts
- environment access rules

## B. Market registry
Responsibilities:
- markets
- venues
- session calendars
- supported asset classes
- market status
- enable/disable flags

## C. Instrument master
Responsibilities:
- canonical symbols
- broker/exchange symbol mapping
- tick sizes
- lot sizes
- contract multipliers
- currency metadata
- corporate action references
- expiry/roll rules

## D. Data ingestion
Responsibilities:
- live market feeds
- historical backfill
- normalization
- deduplication
- time alignment
- bad tick filtering

## E. Feature engine
Responsibilities:
- indicators
- rolling stats
- volatility
- cross-market features
- sentiment features
- point-in-time correct feature generation

## F. Strategy management
Responsibilities:
- strategy definitions
- versions
- parameters
- eligibility for paper/live
- capital assignment
- lifecycle states

## G. Research and model management
Responsibilities:
- experiment tracking
- model registry
- backtest runs
- validation reports
- promotion artifacts

## H. Portfolio engine
Responsibilities:
- aggregate strategy outputs
- resolve conflicts
- target weights
- exposure balancing
- allocation logic

## I. Risk engine
Responsibilities:
- pre-trade limits
- portfolio-level constraints
- drawdown controls
- kill switches
- operational halts
- market condition constraints

## J. Order and execution
Responsibilities:
- order intents
- broker routing
- execution instructions
- cancel/replace
- fill handling
- error mapping
- retry policies

## K. Positions and accounting
Responsibilities:
- positions
- balances
- realized/unrealized P&L
- fees
- margin
- account snapshots

## L. Reconciliation
Responsibilities:
- compare internal and broker states
- detect drift
- resolve discrepancies
- daily close integrity

## M. Audit and compliance
Responsibilities:
- immutable event trails
- approvals
- overrides
- change history
- deployment logs
- operator actions

## N. Reporting
Responsibilities:
- strategy reports
- risk reports
- investor summaries
- operational reports
- incident reports