CREATE TABLE IF NOT EXISTS markets (
    id UUID PRIMARY KEY,
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    asset_class VARCHAR(50) NOT NULL,
    timezone VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'active'
);
CREATE TABLE IF NOT EXISTS venues (
    id UUID PRIMARY KEY,
    market_id UUID NOT NULL REFERENCES markets(id),
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    venue_type VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'active'
);
CREATE TABLE IF NOT EXISTS instruments (
    id UUID PRIMARY KEY,
    venue_id UUID NOT NULL REFERENCES venues(id),
    canonical_symbol VARCHAR(100) UNIQUE NOT NULL,
    external_symbol VARCHAR(100),
    asset_class VARCHAR(50) NOT NULL,
    base_asset VARCHAR(50),
    quote_asset VARCHAR(50),
    tick_size NUMERIC(24,10) NOT NULL,
    lot_size NUMERIC(24,10) NOT NULL,
    price_precision INT NOT NULL,
    quantity_precision INT NOT NULL,
    contract_multiplier NUMERIC(24,10),
    status VARCHAR(50) NOT NULL DEFAULT 'active'
);
