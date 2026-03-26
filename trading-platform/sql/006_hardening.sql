CREATE TABLE IF NOT EXISTS order_state_history (
    id UUID PRIMARY KEY,
    order_intent_id UUID NOT NULL REFERENCES order_intents(id),
    from_state VARCHAR(50),
    to_state VARCHAR(50) NOT NULL,
    transition_reason VARCHAR(255),
    actor_type VARCHAR(50) NOT NULL,
    actor_id UUID,
    metadata_json JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS risk_evaluations (
    id UUID PRIMARY KEY,
    order_intent_id UUID NOT NULL REFERENCES order_intents(id),
    decision VARCHAR(20) NOT NULL,
    next_state VARCHAR(50) NOT NULL,
    rule_results JSONB NOT NULL,
    evaluated_by_service VARCHAR(100) NOT NULL,
    correlation_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS idempotency_keys (
    id UUID PRIMARY KEY,
    scope VARCHAR(100) NOT NULL,
    idempotency_key VARCHAR(255) NOT NULL,
    response_json JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(scope, idempotency_key)
);

ALTER TABLE order_intents ADD COLUMN IF NOT EXISTS correlation_id UUID;
ALTER TABLE broker_orders ADD COLUMN IF NOT EXISTS correlation_id UUID;
ALTER TABLE fills ADD COLUMN IF NOT EXISTS correlation_id UUID;
ALTER TABLE audit_events ADD COLUMN IF NOT EXISTS correlation_id UUID;
