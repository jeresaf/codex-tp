CREATE TABLE IF NOT EXISTS strategy_signals (
    id UUID PRIMARY KEY,
    strategy_deployment_id UUID NOT NULL,
    strategy_version_id UUID,
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
    strategy_version_id UUID,
    worker_id UUID NOT NULL,
    status VARCHAR(50) NOT NULL,
    last_processed_event_at TIMESTAMPTZ,
    correlation_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE strategy_deployments ADD COLUMN IF NOT EXISTS deployment_status VARCHAR(50) DEFAULT 'draft';
ALTER TABLE strategy_deployments ADD COLUMN IF NOT EXISTS runtime_mode VARCHAR(20) DEFAULT 'paper';
ALTER TABLE strategy_deployments ADD COLUMN IF NOT EXISTS capital_budget NUMERIC(24,10);
ALTER TABLE strategy_deployments ADD COLUMN IF NOT EXISTS instrument_scope_json JSONB;
