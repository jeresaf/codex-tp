CREATE TABLE IF NOT EXISTS risk_policies (
    id UUID PRIMARY KEY,
    scope_type VARCHAR(50) NOT NULL,
    scope_id UUID NOT NULL,
    rule_type VARCHAR(100) NOT NULL,
    rule_config_json JSONB NOT NULL,
    severity VARCHAR(20) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS order_intents (
    id UUID PRIMARY KEY,
    strategy_deployment_id UUID REFERENCES strategy_deployments(id),
    account_id UUID,
    instrument_id UUID NOT NULL REFERENCES instruments(id),
    signal_id UUID,
    side VARCHAR(10) NOT NULL,
    order_type VARCHAR(20) NOT NULL,
    quantity NUMERIC(24,10) NOT NULL,
    limit_price NUMERIC(24,10),
    stop_price NUMERIC(24,10),
    tif VARCHAR(20) NOT NULL,
    intent_status VARCHAR(50) NOT NULL DEFAULT 'draft',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS broker_orders (
    id UUID PRIMARY KEY,
    order_intent_id UUID NOT NULL REFERENCES order_intents(id),
    venue_id UUID NOT NULL REFERENCES venues(id),
    external_order_id VARCHAR(255),
    broker_status VARCHAR(50) NOT NULL,
    raw_request JSONB,
    raw_response JSONB,
    submitted_at TIMESTAMPTZ,
    acknowledged_at TIMESTAMPTZ
);
CREATE TABLE IF NOT EXISTS fills (
    id UUID PRIMARY KEY,
    broker_order_id UUID NOT NULL REFERENCES broker_orders(id),
    instrument_id UUID NOT NULL REFERENCES instruments(id),
    fill_price NUMERIC(24,10) NOT NULL,
    fill_quantity NUMERIC(24,10) NOT NULL,
    fee_amount NUMERIC(24,10) DEFAULT 0,
    fee_currency VARCHAR(20),
    fill_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    raw_payload JSONB
);
