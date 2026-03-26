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
    instrument_id UUID NOT NULL REFERENCES instruments(id),
    venue_id UUID NOT NULL REFERENCES venues(id),
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
