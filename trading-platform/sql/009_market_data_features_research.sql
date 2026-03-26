CREATE TABLE IF NOT EXISTS raw_market_events (
    id UUID PRIMARY KEY,
    provider_code VARCHAR(100) NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    external_symbol VARCHAR(100),
    payload_json JSONB NOT NULL,
    event_time TIMESTAMPTZ,
    arrival_time TIMESTAMPTZ NOT NULL,
    checksum VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS normalized_candles (
    id UUID PRIMARY KEY,
    instrument_id UUID NOT NULL,
    timeframe VARCHAR(20) NOT NULL,
    open_time TIMESTAMPTZ NOT NULL,
    close_time TIMESTAMPTZ NOT NULL,
    open NUMERIC(24,10) NOT NULL,
    high NUMERIC(24,10) NOT NULL,
    low NUMERIC(24,10) NOT NULL,
    close NUMERIC(24,10) NOT NULL,
    volume NUMERIC(24,10),
    source VARCHAR(100) NOT NULL,
    quality_flag VARCHAR(20) NOT NULL DEFAULT 'ok',
    arrival_time TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS normalized_ticks (
    id UUID PRIMARY KEY,
    instrument_id UUID NOT NULL,
    event_time TIMESTAMPTZ NOT NULL,
    bid NUMERIC(24,10),
    ask NUMERIC(24,10),
    last NUMERIC(24,10),
    bid_size NUMERIC(24,10),
    ask_size NUMERIC(24,10),
    source VARCHAR(100) NOT NULL,
    quality_flag VARCHAR(20) NOT NULL DEFAULT 'ok',
    arrival_time TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS data_quality_issues (
    id UUID PRIMARY KEY,
    provider_code VARCHAR(100) NOT NULL,
    instrument_id UUID,
    timeframe VARCHAR(20),
    issue_type VARCHAR(100) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    details_json JSONB,
    detected_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS feature_definitions (
    id UUID PRIMARY KEY,
    feature_code VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    timeframe VARCHAR(20) NOT NULL,
    formula_ref VARCHAR(255),
    implementation_version VARCHAR(50) NOT NULL,
    required_warmup INT NOT NULL DEFAULT 0,
    null_handling VARCHAR(50) NOT NULL DEFAULT 'propagate',
    dependencies_json JSONB,
    output_schema_json JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS feature_values (
    id UUID PRIMARY KEY,
    feature_code VARCHAR(100) NOT NULL,
    instrument_id UUID NOT NULL,
    timeframe VARCHAR(20) NOT NULL,
    value_time TIMESTAMPTZ NOT NULL,
    value_double DOUBLE PRECISION,
    value_json JSONB,
    quality_flag VARCHAR(20) NOT NULL DEFAULT 'ok',
    source_run_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS dataset_versions (
    id UUID PRIMARY KEY,
    dataset_code VARCHAR(100) NOT NULL,
    dataset_version VARCHAR(50) NOT NULL,
    manifest_json JSONB NOT NULL,
    storage_uri TEXT,
    checksum VARCHAR(255),
    created_by UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(dataset_code, dataset_version)
);

CREATE TABLE IF NOT EXISTS replay_jobs (
    id UUID PRIMARY KEY,
    dataset_version_id UUID NOT NULL REFERENCES dataset_versions(id),
    strategy_version_id UUID,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'queued',
    config_json JSONB,
    result_uri TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
