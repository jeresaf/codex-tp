# 1. System purpose
Build a unified trading platform that supports:
- multiple markets
    - forex
    - equities
    - crypto
    - futures
    - options
    - sports/event markets later if desired
- multiple strategies running in parallel
- research, backtesting, paper trading, live trading
- centralized risk controls
- strong auditability
- enterprise user and approval workflows
- broker and exchange abstraction
- phased scaling from MVP to institutional platform

# 2. Architecture principles

## Risk-first
No component may bypass the risk engine.

## Decision-execution separation
Strategies generate signals and intents. Execution happens only through controlled services.

## Canonical internal model
All markets and venues map into internal standard entities.

## Event-driven core
Market data, signals, orders, fills, positions, and alerts move through an event backbone.

## Environment promotion
Research → Backtest → Paper → Limited Live → Full Live.

## Full traceability
Every strategy version, parameter set, model artifact, order, fill, and override is auditable.

## Modular bounded domains
Services are organized by domain, not by random technical concerns.

# 3. High-level context diagram

Users / Teams
├─ Admins
├─ Quants
├─ Traders
├─ Risk Officers
├─ Compliance
└─ Executives
│
▼
Web UI / APIs / Gateway
│
▼
Control Plane
├─ Strategy Registry
├─ Config Service
├─ Workflow / Approval Engine
├─ Market Registry
├─ Deployment Manager
└─ Secrets Access Broker
│
├─────────────────────────────────────────────┐
▼                                             ▼
Research / Backtest / Paper Systems           Live Trading Systems
│                                             │
└──────────────────────┬──────────────────────┘
▼
Strategy Execution Fabric
├─ Signal Engine
├─ Portfolio Engine
├─ Risk Engine
├─ Order Service
└─ Execution Router
│
▼
Data Platform
├─ Market Data Ingestion
├─ Historical Storage
├─ Feature Store
├─ Event Bus
└─ Reporting Warehouse
│
▼
External Connectivity
├─ Brokers
├─ Exchanges
├─ News Providers
├─ Economic Calendars
├─ Odds Providers
└─ Banking / Treasury / Custody

# 4. Environment model

## Research
Loose, exploratory, non-live.

## Backtest
Historical simulation with reproducible datasets and assumptions.

## Paper trading
Real-time market data, simulated execution, full monitoring.

## Limited live
Restricted capital, reduced instrument scope, extra approvals.

## Full live
Production capital with all controls.

# 5. Core flow

>Market Data
>→ Normalization
>→ Feature Computation
>→ Strategy Signal
>→ Portfolio Target
>→ Risk Validation
>→ Order Intent
>→ Execution Routing
>→ Broker Submission
>→ Fills / Order Updates
>→ Positions / P&L / Reports