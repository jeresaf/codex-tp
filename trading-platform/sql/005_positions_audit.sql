CREATE TABLE IF NOT EXISTS positions (
    id UUID PRIMARY KEY,
    account_id UUID,
    instrument_id UUID NOT NULL REFERENCES instruments(id),
    net_quantity NUMERIC(24,10) NOT NULL DEFAULT 0,
    avg_price NUMERIC(24,10) NOT NULL DEFAULT 0,
    market_value NUMERIC(24,10) NOT NULL DEFAULT 0,
    unrealized_pnl NUMERIC(24,10) NOT NULL DEFAULT 0,
    realized_pnl NUMERIC(24,10) NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS audit_events (
    id UUID PRIMARY KEY,
    actor_type VARCHAR(50) NOT NULL,
    actor_id UUID,
    event_type VARCHAR(100) NOT NULL,
    resource_type VARCHAR(100) NOT NULL,
    resource_id UUID,
    before_json JSONB,
    after_json JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
