# 1. Core entities

## User
- id
- name
- email
- status
- auth_provider
- mfa_enabled
- created_at
- updated_at

## Role
- id
- name
- description

## Permission
- id
- code
- description

## Team
- id
- name
- type

## Market
- id
- code
- name
- asset_class
- timezone
- trading_hours_definition

## Venue
- id
- code
- name
- market_id
- type
- status

## Instrument
- id
- canonical_symbol
- base_asset
- quote_asset
- asset_class
- venue_id
- tick_size
- lot_size
- contract_multiplier
- price_precision
- quantity_precision
- expiry_date nullable
- status

## InstrumentMapping
- id
- instrument_id
- venue_id
- external_symbol
- mapping_status

## Account
- id
- venue_id
- account_code
- base_currency
- status
- legal_entity
- margin_profile

## Strategy
- id
- code
- name
- type
- owner_user_id
- description
- status

## StrategyVersion
- id
- strategy_id
- version
- artifact_uri
- code_commit_hash
- parameter_schema
- runtime_requirements
- approval_state
- created_at

## ModelArtifact
- id
- strategy_version_id
- model_type
- artifact_uri
- metrics_json
- approved_for_use

## StrategyDeployment
- id
- strategy_version_id
- environment
- account_id
- market_scope_json
- capital_allocation_rule
- status
- started_at
- stopped_at

## FeatureDefinition
- id
- code
- name
- description
- formula_ref
- timeframe
- input_requirements_json

## Signal
- id
- strategy_version_id
- instrument_id
- timestamp
- signal_type
- direction
- strength
- confidence
- metadata_json

## PortfolioTarget
- id
- strategy_deployment_id
- instrument_id
- target_quantity
- target_weight
- target_notional
- timestamp

## RiskPolicy
- id
- scope_type
- scope_id
- rule_type
- rule_config_json
- severity
- enabled

## OrderIntent
- id
- strategy_deployment_id
- account_id
- instrument_id
- side
- order_type
- quantity
- limit_price nullable
- stop_price nullable
- tif
- intent_status
- created_at

## BrokerOrder
- id
- order_intent_id
- venue_id
- external_order_id
- broker_status
- submitted_at
- acknowledged_at

## Fill
- id
- broker_order_id
- instrument_id
- fill_price
- fill_quantity
- fee_amount
- fee_currency
- fill_time

## Position
- id
- account_id
- instrument_id
- net_quantity
- avg_price
- market_value
- unrealized_pnl
- realized_pnl
- updated_at

## BalanceSnapshot
- id
- account_id
- currency
- cash_balance
- available_margin
- used_margin
- equity
- snapshot_time

## BacktestRun
- id
- strategy_version_id
- dataset_version
- config_json
- started_at
- completed_at
- result_summary_json
- status

## ExperimentRun
- id
- strategy_id
- dataset_version
- code_ref
- params_json
- metrics_json
- artifact_uri
- status

## AuditEvent
- id
- actor_type
- actor_id
- event_type
- resource_type
- resource_id
- before_json
- after_json
- created_at

## Incident
- id
- severity
- source_service
- incident_type
- description
- status
- opened_at
- resolved_at

## ReconciliationIssue
- id
- account_id
- issue_type
- severity
- external_ref
- internal_ref
- status
- detected_at
- resolved_at

# 2. Storage recommendations

## PostgreSQL
Use for transactional entities.

## TimescaleDB or ClickHouse
Use for:
- candles
- ticks
- features
- signals
- high-frequency metrics

## Object storage
Use for:
- backtest artifacts
- parquet snapshots
- model files
- raw
- feed dumps
- compliance exports

## Redis
Use for:
- hot caches
- locking
- fast runtime state
- throttling counters