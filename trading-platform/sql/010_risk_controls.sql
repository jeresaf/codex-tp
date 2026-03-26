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
