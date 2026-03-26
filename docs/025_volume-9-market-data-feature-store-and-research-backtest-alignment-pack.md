# 1. Goal
Create one consistent data foundation for:
- research
- backtests
- paper trading
- live trading
- reporting
- replay
- incident investigation
This pack adds:
- canonical market data ingestion
- normalized candle/tick/event model
- feature store
- point-in-time correctness
- warmup/replay rules
- research/runtime parity
- backtest/live alignment
- data quality controls
- event calendar integration hooks

# 2. Core principle
You must make this true:
**the same strategy logic, given the same inputs, should produce the same decisions in research, backtest, paper, and live—subject only to execution differences.**

That means:
- same symbol model
- same feature definitions
- same timestamp rules
- same warmup logic
- same missing-data behavior
- same corporate action and rollover handling rules where relevant

# 3. New bounded domains added

## 3.1 Market data domain
Responsibilities:
- ingest external market data
- normalize symbols and payloads
- validate timestamps
- store raw and normalized data
- detect gaps/staleness
- publish canonical market events

## 3.2 Feature domain
Responsibilities:
- define features
- compute features in batch and streaming modes
- persist feature outputs
- expose point-in-time reads
- maintain lineage

## 3.3 Research data domain
Responsibilities:
- create dataset versions
- freeze research inputs
- support reproducible experiments
- bridge research and runtime

## 3.4 Replay and warmup domain
Responsibilities:
- reconstruct market and feature sequences
- warm strategy runtimes correctly
- support incident replay
- support deterministic backtests

# 4. Data architecture shift
The engine now becomes:

```
External Feeds
-> Market Data Ingestion
-> Canonical Market Events
-> Historical Store
-> Feature Computation
-> Feature Store
-> Strategy Runtime / Backtest / Research
-> Signals
-> Portfolio Targets
-> Orders
```

This is the correct order.

# 5. Canonical market data model
The system should never let strategies depend on raw broker/exchange payloads.
Define internal canonical event types.

## 5.1 Core event types
Support these first:
- tick
- quote
- candle
- order book snapshot later
- economic event later
- funding rate later
- corporate action later
- sports odds event later if that market is added

## 5.2 Canonical candle model
Each candle should include:
- instrument_id
- timeframe
- open_time
- close_time
- open
- high
- low
- close
- volume
- source
- arrival_time
- quality_flag

## 5.3 Canonical tick model
Each tick should include:
- instrument_id
- event_time
- bid
- ask
- last
- bid_size nullable
- ask_size nullable
- source
- arrival_time
- quality_flag

# 6. Raw vs normalized storage
Store both.

## 6.1 Raw storage
Keep:
- exact payload from broker/exchange/provider
- fetch time
- source metadata
- checksum if useful
Use raw storage for:
- audits
- debugging adapters
- rebuilding normalization
- provider disputes

## 6.2 Normalized storage
Keep:
- canonical fields only
- clean timestamps
- mapped instrument ids
- consistent numeric precision
Strategies and backtests should use normalized storage, not raw payloads.

# 7. Timestamp rules
This is one of the most important rules in the whole system.

## 7.1 Required timestamps
For market data, separate:
- event_time: when the market event occurred
- arrival_time: when your system received it
- processed_time: when your system normalized/persisted it

## 7.2 Candle semantics
Pick one rule and keep it everywhere.
Best practice:
- candle is considered tradable only after close_time
- strategy on candle-close uses fully closed candle only
Do not let backtests use incomplete candles while live uses closed candles only.

## 7.3 Timezone standard
Store all system event times in UTC.
Display timezones only in UI formatting.

# 8. Market sessions and calendars
Strategies must know whether a market is tradeable.

## 8.1 Session model
Store:
- market id
- venue id
- timezone
- open/close schedule
- holidays
- half days
- maintenance windows

## 8.2 Needed by
- signal generation
- order generation
- backtest session filtering
- live execution gating

## 8.3 Market examples

### Forex
- nearly 24/5
- weekend close
- session liquidity windows matter

### Crypto
- 24/7
- exchange maintenance matters

### Stocks
- exchange hours
- pre/post market rules

### Futures
- rolling sessions
- exchange-specific maintenance windows

# 9. Market data ingestion service design
Add or expand `market-data-service`.

## Responsibilities
- connect to providers
- fetch/pull/stream data
- normalize symbols
- validate structure
- deduplicate repeated events
- publish canonical events
- store raw and normalized records
- surface feed health

## Internal modules
- connector adapters
- symbol mapper
- validator
- normalizer
- raw writer
- normalized writer
- event publisher
- feed health monitor

# 10. Data quality controls
You need data quality as a first-class concern.

## 10.1 Checks to implement
- missing timestamps
- future timestamps
- negative prices
- low > high
- duplicates
- out-of-order candles
- stale feeds
- suspicious jumps
- zero volume where impossible
- session-invalid events

## 10.2 Quality flags
Each normalized record should carry a simple quality status:
- `ok`
- `warning`
- `rejected`
- `synthetic`
- `corrected`

## 10.3 Gap detection
Track missing bars or missing tick intervals by instrument/timeframe.
Emit events like:
- `market_data.gap.detected`
- `market_data.feed.stale`
- `market_data.feed.recovered`

# 11. Historical storage design
You need time-series storage with clear retention and indexing.

## 11.1 Store types
Use:
- PostgreSQL + TimescaleDB for first serious implementation
- ClickHouse later if scale demands it

## 11.2 Main tables
- raw_market_events
- normalized_ticks
- normalized_candles
- data_quality_issues
- provider_sync_runs

## 11.3 Partitioning
Partition by:
- event date
- optionally instrument_id/timeframe
This matters once the data grows.

# 12. Feature store design
This is a major part of the platform.

## 12.1 Why feature store
Without a feature store:
- research computes indicators one way
- runtime computes them another way
- backtests silently differ
- debugging becomes painful
With a feature store:
- feature definitions are centralized
- outputs are reproducible
- runtime and research can consume the same definitions

## 12.2 Feature store responsibilities
- register feature definitions
- compute features in batch
- compute features in streaming mode
- expose point-in-time reads
- persist feature values
- store lineage and dependencies

# 13. Feature definition model
Each feature definition should store:
- feature code
- name
- description
- input type
- timeframe
- formula reference
- implementation version
- required warmup length
- null-handling behavior
- dependencies
- output schema
Example features:
- SMA_20
- SMA_50
- RSI_14
- ATR_14
- Bollinger_Band_20
- rolling_vol_30
- zscore_20

# 14. Feature computation modes
Support both.

## 14.1 Batch mode
Used for:
- research
- backfill
- dataset creation
- backtests

## 14.2 Streaming mode
Used for:
- live runtime
- paper runtime
- intraday monitoring
These two modes must use the same logic implementation or compatible shared library.

# 15. Point-in-time correctness
This is non-negotiable.
A feature read for timestamp `T` must only use information available at or before `T`.
Never leak future information into:
- features
- labels
- training data
- backtests
This requires:
- timestamp discipline
- delayed availability awareness
- correct join rules for external datasets
Example:
- if an economic indicator is published at 13:30 UTC, it must not appear in a 13:00 decision row

# 16. Warmup and lookback rules
Strategies need warmup windows before producing valid signals.

## 16.1 Example
A 50-period SMA needs at least 50 periods of history.

## 16.2 Warmup model
Every strategy deployment should define:
- required lookback bars
- required features
- readiness condition

## 16.3 Runtime behavior
Before warmup is satisfied:
- no signal should be emitted
- heartbeat should report `warming_up`

## 16.4 Backtest behavior
Backtests must use the same warmup rule as runtime.

# 17. Research/runtime parity
This is one of the most important design sections.

## You need one source of truth for:
- instrument mapping
- candle construction
- feature formulas
- session filtering
- warmup behavior
- missing-data policy
- target generation math

## Best practice
Create shared packages for:
- market data schema
- feature definitions
- strategy SDK
- portfolio math
Research notebooks should call the same underlying libraries where possible.

# 18. Dataset versioning
Research results are meaningless unless datasets are versioned.

## 18.1 Dataset version should capture
- source provider
- extraction date/time
- instrument universe
- timeframe
- transformation rules
- feature version set
- calendar/session rules
- quality filters applied

## 18.2 Dataset record
Store:
- dataset_id
- dataset_version
- manifest file
- storage URI
- record counts
- checksum/hashes
- creation metadata

## 18.3 Use cases
- reproducible backtests
- experiment comparisons
- incident replay
- model promotion review

# 19. Backtest/live alignment model
The backtest engine should not invent its own market behavior independently of live runtime semantics.

## 19.1 Must align on:
- candle-close decision timing
- warmup rules
- session rules
- feature definitions
- target generation
- order threshold logic

## 19.2 May differ on:
- execution realism
- slippage
- fees
- partial fills
- latency
So:
- decision logic must align
- execution model can vary by environment

# 20. Replay engine design
You will need replay for:
- debugging
- model review
- incident analysis
- paper-vs-live comparison
- strategy validation

## 20.1 Replay inputs
- dataset version
- instrument set
- timeframe
- start/end time
- feature versions
- strategy version
- portfolio parameters

## 20.2 Replay outputs
- signals
- targets
- orders
- positions
- differences vs original run if applicable

## 20.3 Replay modes
- market-data only replay
- signal replay
- full pipeline replay

# 21. Feature store events and APIs

## Event topics to add
- `market_data.candle.closed`
- `market_data.tick.normalized`
- `feature.value.computed`
- `feature.backfill.completed`
- `dataset.version.created`

## APIs to add
- `GET /api/features/definitions`
- `POST /api/features/definitions`
- `GET /api/features/values`
- `POST /api/features/backfill`
- `GET /api/datasets`
- `POST /api/datasets`
- `POST /api/replay-jobs`

# 22. Database additions

## Create sql/009_market_data_features_research.sql.

```SQL
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
```

# 23. Market data service internal design
`market-data-service` should now have:
- provider adapters
- symbol map resolver
- raw event writer
- normalizer
- validator
- candle builder if source gives ticks only
- feed health tracker
- outbox publisher

## Starter provider path
Pick one first:
- OANDA for forex
or
- Binance for crypto
Do not start with too many providers.

# 24. Candle builder rules
If candles are derived from ticks, you must define rules once.

## Rules
- candles aligned exactly on timeframe boundaries
- open = first valid trade/price in interval
- high = max
- low = min
- close = last valid trade/price in interval
- volume aggregated if present
- missing interval behavior explicit

## Missing interval options
- emit no candle
- emit synthetic flat candle
- emit flagged synthetic candle
Pick one per market/timeframe policy and stay consistent.
Best initial choice:
- emit no candle unless your strategy framework explicitly requires synthetic bars

# 25. Feature service internal design
`feature-service` should contain:
- feature registry
- batch compute jobs
- streaming feature consumer
- feature persistence
- point-in-time query API
- lineage metadata

## Recommended implementation pattern
Feature definitions reference code implementations in a shared package, for example:
- `shared_features.sma.compute`
- `shared_features.rsi.compute`
This prevents research and runtime drift.

# 26. Shared feature package
Create a shared package like:
- `packages/shared-features`
Structure:

packages/shared-features/
├─ indicators/
│ ├─ sma.py
│ ├─ ema.py
│ ├─ rsi.py
│ ├─ atr.py
│ └─ bollinger.py
├─ transforms/
│ ├─ returns.py
│ ├─ zscore.py
│ └─ volatility.py
├─ registry/
│ └─ feature_registry.py
└─ tests/

Use the same implementations in:
- feature-service batch jobs
- feature-service streaming jobs
- research notebooks
- backtests where possible

# 27. Research environment alignment
Your research stack should consume:
- normalized candles/ticks
- versioned datasets
- shared feature library
- same strategy SDK
- same portfolio math
Avoid ad hoc notebook-only feature code that never goes into production.

## Research workflow
1. choose dataset version
2. choose feature definition versions
3. choose strategy version
4. run experiment
5. record outputs and artifacts
6. compare against live/paper behavior later

# 28. Backtest alignment checklist
Every backtest should declare:
- dataset version
- feature version set
- strategy version
- execution model version
- fee model version
- session/calendar rules
- warmup rules
- target generation settings
Without that, backtest results are not promotable.

# 29. UI additions

## Admin UI
Add pages for:
- providers
- feed health
- data quality issues
- feature definitions
- dataset versions
- replay jobs

## Ops UI
Add pages for:
- feed status
- stale/gap alerts
- recent feature computation failures
- runtime warmup status

## Research UI later
Add:
- dataset browser
- feature lineage explorer
- replay comparison page

# 30. Manual test sequence for this stage
The first meaningful test should be:

## Step 1
Ingest one provider’s EURUSD candles.

## Step 2
Normalize and persist them.

## Step 3
Define two features:
- SMA_20
- SMA_50

## Step 4
Run a feature backfill over recent candles.

## Step 5
Launch one paper strategy deployment.

## Step 6
Feed closed candles to runtime.

## Step 7
Verify:
- strategy warms up until enough history exists
- after warmup, signal emits correctly
- portfolio target is created
- order lifecycle continues

## Step 8
Run a replay on the same dataset and verify the same signal sequence.
That last step is crucial.

# 31. Critical guardrails for this stage
Implement these rules now:
- no strategy can subscribe directly to provider-specific payloads
- no feature can use future data
- no backtest can run without dataset version reference
- no runtime can emit signals before warmup satisfied
- no market data record can enter canonical store without validation
- all feed gaps above threshold raise alerts
- all feature definitions must be versioned

# 32. Suggested implementation order

## Stage 1
- add DB tables
- add raw + normalized candle storage
- build one provider adapter

## Stage 2
- publish `market_data.candle.closed`
- build feed health and gap detection

## Stage 3
- build feature definitions + shared feature library
- implement batch feature backfill

## Stage 4
- implement streaming feature computation
- persist feature values

## Stage 5
- wire strategy runtime to use feature/warmup rules

## Stage 6
- implement dataset versioning and replay jobs

# 33. What this unlocks
After this pack, the platform gains:
- trustworthy data lineage
- backtest/live consistency
- reusable feature computation
- deterministic warmup behavior
- incident replay ability
- confidence to promote strategies responsibly
This is one of the most important maturity steps in the whole system.

# 34. What should come next
The next correct step is:

## Volume 10: risk, exposure, and portfolio controls pack
That should add:
- multi-level exposure controls
- instrument and market caps
- strategy sleeve caps
- portfolio concentration rules
- daily loss and drawdown halts
- correlation-aware controls
- pre-trade and post-trade risk views
- live breach handling and kill-switch escalation
That is the layer that makes the multi-strategy, multi-market engine safe to operate.