# 1. Event backbone
Use Kafka or Redpanda topics.

# 2. Topic catalog

## Market data topics
- `market.ticks.raw`
- `market.ticks.normalized`
- `market.candles.1m`
- `market.candles.5m`
- `market.orderbook.snapshots`
- `market.sessions.status`

## Data quality topics
- `market.feed.gaps.detected`
- `market.feed.stale`
- `market.feed.recovered`

## Feature topics
- `features.updated`
- `features.failed`

## Strategy topics
- `strategies.deployment.changed`
- `signals.generated`
- `signals.rejected`

## Portfolio topics
- `portfolio.targets.created`
- `portfolio.allocations.changed`

## Risk topics
- `risk.check.requested`
- `risk.check.passed`
- `risk.check.failed`
- `risk.breach.detected`
- `risk.kill_switch.triggered`

## Order topics
- `orders.intent.created`
- `orders.intent.cancel_requested`
- `orders.submitted`
- `orders.acknowledged`
- `orders.partially_filled`
- `orders.filled`
- `orders.cancelled`
- `orders.rejected`

## Position topics
- `positions.updated`
- `balances.updated`
- `pnl.updated`

## Workflow topics
- `workflow.request.created`
- `workflow.request.approved`
- `workflow.request.rejected`

## Audit topics
- `audit.events.recorded`

## Alert topics
- `alerts.critical`
- `alerts.warning`
- `alerts.info`

# 3. Event envelope standard
Each event should have:
- event_id
- event_type
- event_version
- source_service
- environment
- occurred_at
- correlation_id
- causation_id
- actor_type
- actor_id
- payload