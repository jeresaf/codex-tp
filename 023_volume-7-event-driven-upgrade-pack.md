# 1. Goal
Move the platform from:
- synchronous service chaining
- fragile direct dependencies
- limited replayability
- harder scale-out
to:
- event-driven workflows
- looser coupling
- durable lifecycle streams
- replayable processing
- scalable multi-strategy runtime
- better observability and resilience
This is the correct upgrade for supporting:
- multiple strategies
- multiple markets
- more brokers
- more operators
- more audit and reporting demands

# 2. Architectural shift

## Before
Current flow:

>order-service
>-> risk-service
>-> execution-service
>-> position-service
>-> audit-service

This is simple, but:
- one service failure can interrupt the chain
- services are tightly coupled
- retries are tricky
- downstream systems cannot easily subscribe
- replaying workflow history is hard

## After
New flow:

```
order-service -> publishes order event
risk-service -> consumes order event, publishes risk decision
execution-service -> consumes risk pass event, publishes execution result
position-service -> consumes fill event, publishes position update
audit-service -> consumes all important events
reporting-service -> consumes all important events
notification-service -> consumes alerts/incidents
```

This gives you:
- better separation
- better fan-out
- better scale
- durable event history

# 3. Event-driven principles

## 3.1 Events are facts
Events should describe what happened, not what might happen.
Good:
- `order_intent.created`
- `risk.evaluation.completed`
- `execution.fill.recorded`
- `position.updated`
Bad:
- `process_order_now`
- `run_execution_next`

## 3.2 Services own state, not each other
Each service:
- owns its own database tables
- reacts to events
- writes its own state
- publishes resulting events

## 3.3 Use eventual consistency
The platform should accept that:
- order created now
- risk decision arrives shortly after
- execution result arrives after that
- position update comes after fill
This is normal.

## 3.4 Consumers must be idempotent
Because event delivery can be at least once, every consumer must safely handle duplicates.

# 4. Target event-driven order lifecycle

## 4.1 New order flow

```
API/UI
-> order-service creates order_intent (draft)
-> order-service publishes order_intent.created
risk-service consumes order_intent.created
-> evaluates risk
-> stores risk_evaluation
-> publishes risk.evaluation.completed
order-service consumes risk.evaluation.completed
-> updates order state to risk_passed or risk_failed
-> publishes order_intent.state_changed
execution-service consumes risk.evaluation.completed where decision=pass
-> submits/simulates execution
-> stores broker_order/fill
-> publishes execution.fill.recorded
position-service consumes execution.fill.recorded
-> updates position
-> publishes position.updated
audit-service consumes all lifecycle events
-> writes audit events
```

# 5. Topic catalog for the upgraded platform
Start with a focused topic set

## 5.1 Core workflow topics
- `order_intent.created`
- `order_intent.state_changed`
- `risk.evaluation.completed`
- `execution.order_submitted`
- `execution.fill.recorded`
- `position.updated`
- `audit.event.recorded`
- `incident.raised`

## 5.2 Later expansion topics
- `market_data.tick.normalized`
- `market_data.candle.closed`
- `strategy.signal.generated`
- `portfolio.target.generated`
- `reconciliation.issue.detected`
- `notification.dispatch.requested`
Do not add too many on day one.

# 6. Event payload standards
Every event must use a standard envelope.

## 6.1 Event envelope

```JSON
{
  "event_id": "uuid",
  "event_type": "order_intent.created",
  "event_version": 1,
  "source_service": "order-service",
  "environment": "paper",
  "occurred_at": "2026-03-18T10:15:00Z",
  "correlation_id": "uuid",
  "causation_id": "uuid",
  "actor_type": "user",
  "actor_id": "uuid",
  "payload": {}
}
```

## 6.2 Required rules
- `event_id` unique per emitted event
- `correlation_id` shared across the workflow
- `causation_id` points to the triggering event or request
- `event_version` required for schema evolution
payload must be serializable JSON only

# 7. Event schemas

## 7.1 `order_intent.created`

```JSON
{
  "event_id": "uuid",
  "event_type": "order_intent.created",
  "event_version": 1,
  "source_service": "order-service",
  "environment": "paper",
  "occurred_at": "2026-03-18T10:15:00Z",
  "correlation_id": "uuid",
  "causation_id": "uuid",
  "actor_type": "user",
  "actor_id": "uuid",
  "payload": {
    "order_intent_id": "uuid",
    "strategy_deployment_id": null,
    "account_id": null,
    "instrument_id": "uuid",
    "side": "buy",
    "order_type": "market",
    "quantity": "1000",
    "limit_price": null,
    "stop_price": null,
    "tif": "IOC",
    "intent_status": "draft"
  }
}
```

## 7.2 `risk.evaluation.completed`

```JSON
{
  "event_id": "uuid",
  "event_type": "risk.evaluation.completed",
  "event_version": 1,
  "source_service": "risk-service",
  "environment": "paper",
  "occurred_at": "2026-03-18T10:15:01Z",
  "correlation_id": "uuid",
  "causation_id": "order-created-event-id",
  "actor_type": "system",
  "actor_id": "risk-service",
  "payload": {
    "risk_evaluation_id": "uuid",
    "order_intent_id": "uuid",
    "decision": "pass",
    "next_state": "risk_passed",
    "rule_results": [
      {
        "rule_type": "max_position_size",
        "passed": true,
        "message": "Passed",
        "severity": "info"
      }
    ]
  }
}
```

## 7.3 `execution.fill.recorded`

```JSON
{
  "event_id": "uuid",
  "event_type": "execution.fill.recorded",
  "event_version": 1,
  "source_service": "execution-service",
  "environment": "paper",
  "occurred_at": "2026-03-18T10:15:02Z",
  "correlation_id": "uuid",
  "causation_id": "risk-evaluation-event-id",
  "actor_type": "system",
  "actor_id": "execution-service",
  "payload": {
    "broker_order_id": "uuid",
    "fill_id": "uuid",
    "order_intent_id": "uuid",
    "instrument_id": "uuid",
    "side": "buy",
    "quantity": "1000",
    "price": "1.0850",
    "fee_amount": "0.0",
    "fee_currency": "USD"
  }
}
```

## 7.4 `position.updated`

```JSON
{
  "event_id": "uuid",
  "event_type": "position.updated",
  "event_version": 1,
  "source_service": "position-service",
  "environment": "paper",
  "occurred_at": "2026-03-18T10:15:03Z",
  "correlation_id": "uuid",
  "causation_id": "fill-recorded-event-id",
  "actor_type": "system",
  "actor_id": "position-service",
  "payload": {
    "position_id": "uuid",
    "account_id": null,
    "instrument_id": "uuid",
    "net_quantity": "1000",
    "avg_price": "1.0850"
  }
}
```

# 8. Topic-to-service responsibilities

## order-service
Publishes:
- `order_intent.created`
- `order_intent.state_changed`
Consumes:
- `risk.evaluation.completed`

## risk-service
Consumes:
- `order_intent.created`
Publishes:
- `risk.evaluation.completed`

## execution-service
Consumes:
- `risk.evaluation.completed`
Publishes:
- `execution.order_submitted`
- `execution.fill.recorded`

## position-service
Consumes:
- `execution.fill.recorded`
Publishes:
- `position.updated`

## audit-service
Consumes:
- all major lifecycle events
Publishes:
- optional `audit.event.recorded`

## reporting-service
Consumes:
- order, risk, execution, position events

# 9. Outbox pattern
This is the most important reliability improvement.

## 9.1 Why you need it
Without outbox:
- service writes DB row
- then tries to publish event
- if publish fails, DB and event stream diverge
With outbox:
- service writes DB row and outbox row in same transaction
- publisher later reads outbox and publishes
- when successful, marks outbox row as published
This is the correct enterprise pattern.

# 10. Outbox table design

## SQL migration

```SQL
CREATE TABLE IF NOT EXISTS outbox_events (
    id UUID PRIMARY KEY,
    aggregate_type VARCHAR(100) NOT NULL,
    aggregate_id UUID NOT NULL,
    event_type VARCHAR(150) NOT NULL,
    event_version INT NOT NULL,
    correlation_id UUID,
    causation_id UUID,
    payload_json JSONB NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    retry_count INT NOT NULL DEFAULT 0,
    next_attempt_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    published_at TIMESTAMPTZ,
    last_error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## Status values
- `pending`
- `published`
- `failed`

# 11. Inbox / processed-events pattern
Consumers also need protection.

## 11.1 Why
Kafka/Redpanda delivery can be repeated.
A consumer may receive the same event more than once.

## 11.2 Solution
Track processed event IDs.

### SQL migration

```SQL
CREATE TABLE IF NOT EXISTS processed_events (
    id UUID PRIMARY KEY,
    consumer_service VARCHAR(100) NOT NULL,
    event_id UUID NOT NULL,
    event_type VARCHAR(150) NOT NULL,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(consumer_service, event_id)
);
```

Before processing an event:
- check if already processed
- if yes, skip
- if no, process and insert record
This is essential for idempotency.

# 12. Publisher worker design
Each service that emits events should have an outbox publisher worker.

## Flow

```
Service transaction:
  write business row(s)
  write outbox row

Publisher worker:
  poll outbox pending rows
  publish to Kafka
  mark row published
  or increment retry_count / set last_error
```

## Retry policy
- exponential backoff
- max retry threshold before alerting
- do not discard silently

# 13. Consumer worker design
Each consumer service should run one or more background consumers.

## Consumer flow

```
Receive event
  validate schema
  check processed_events
  if already processed -> ack and skip
  apply business logic
  write service DB changes
  optionally write outbox events
  mark processed_events
  commit
```

All of that should happen in one local DB transaction where possible.

# 14. Service changes for the event-driven upgrade

## 14.1 order-service

Change:
- `/api/orders/submit` no longer directly calls risk/execution/position
- it creates order + outbox event
- returns accepted response
Response becomes:

```JSON

```

Then background processing handles the rest.

## 14.2 risk-service
Add:
- consumer for `order_intent.created`
- persist risk evaluation
- emit `risk.evaluation.completed`

## 14.3 execution-service
Add:
- consumer for `risk.evaluation.completed`
- only continue when decision = `pass`
- persist broker order and fill
- emit `execution.fill.recorded`

## 14.4 position-service
Add:
- consumer for `execution.fill.recorded`
- apply fill
- emit `position.updated`

## 14.5 audit-service
Add:
- event consumer that subscribes to all relevant topics
- write audit rows automatically

# 15. New order states under event-driven mode
Order lifecycle becomes more natural.
Suggested states:
- `draft`
- `risk_pending`
- `risk_passed`
- `risk_failed`
- `submitted`
- `filled`
- `execution_failed`

Flow:
- order-service sets `draft`
- risk-service completion leads order-service consumer to set `risk_passed` or `risk_failed`
- execution-service success leads order-service consumer or reconciliation logic to set `submitted / filled`
You can either:
- let order-service remain the official state owner and consume downstream events, or
- let order-service state be partly projection-based

Best choice now:
**order-service remains lifecycle owner.**
So it should consume:
- `risk.evaluation.completed`
- `execution.fill.recorded`
and update order states accordingly.

# 16. Projection/read-model pattern
For UI performance, build read models later.
Instead of every UI page joining multiple services live, create projection tables like:
- `order_detail_view`
- `position_summary_view`
- `risk_breach_view`
These can be updated from events.
This makes the UI:
- faster
- simpler
- more resilient

# 17. Kafka / Redpanda topic design

## 17.1 Partitioning strategy
Partition high-cardinality topics by:
- `order_intent_id` for order lifecycle topics
- `instrument_id` for market/position topics if needed
- `account_id` for account-centric streams later
For core order workflow:
- key by `order_intent_id`
This preserves ordering for one order’s lifecycle.

## 17.2 Retention
For important business topics:
- longer retention preferred
- audit-critical topics may be archived to object storage too
Examples:
- order/risk/execution/position: 30–90 days or more depending on storage policy
- market data: shorter in Kafka, longer in object storage

# 18. Event schema versioning rules
You will need this early.

## Rules
- never change meaning of existing fields silently
- add new optional fields when possible
- increment `event_version` when incompatible changes happen
- consumer should explicitly handle known versions
- keep old versions readable during migration window
Example:
- `execution.fill.recorded` v1
- `execution.fill.recorded` v2 adds `slippage_amount`

# 19. Error handling in event-driven flows

## 19.1 Poison messages
If a consumer keeps failing on the same event:
- do not block the whole topic forever
- move to dead-letter flow after retry threshold

## 19.2 Dead-letter topic
Create:
- `dlq.order`
- `dlq.risk`
- `dlq.execution`
- or a shared `dlq.platform`
Dead-letter message should include:
- original event
- error
- consumer service
- retry count
- timestamp

## 19.3 Incident creation
DLQ entries should raise:
- incident row
- alert
- operator action requirement

# 20. SQL migration pack for event-driven upgrade

## Create `sql/007_event_driven.sql`

```SQL
CREATE TABLE IF NOT EXISTS outbox_events (
    id UUID PRIMARY KEY,
    aggregate_type VARCHAR(100) NOT NULL,
    aggregate_id UUID NOT NULL,
    event_type VARCHAR(150) NOT NULL,
    event_version INT NOT NULL,
    correlation_id UUID,
    causation_id UUID,
    payload_json JSONB NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    retry_count INT NOT NULL DEFAULT 0,
    next_attempt_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    published_at TIMESTAMPTZ,
    last_error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS processed_events (
    id UUID PRIMARY KEY,
    consumer_service VARCHAR(100) NOT NULL,
    event_id UUID NOT NULL,
    event_type VARCHAR(150) NOT NULL,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(consumer_service, event_id)
);
```

You may also later add:
- `dead_letter_events`
- `event_replay_jobs`

# 21. Shared event publisher package
Add package:
- `packages/shared-events/shared_events/publisher.py`
- `packages/shared-events/shared_events/consumer.py`

## Publisher contract
Provide a helper like:

```Python
class EventPublisher:
    def publish(self, topic: str, key: str, event: dict): ...
```

But for correctness, first publish from outbox workers, not directly from business logic.

## Outbox helper
Business logic should call:

```Python
append_outbox_event(
    db=db,
    aggregate_type="order_intent",
    aggregate_id=row.id,
    event_type="order_intent.created",
    event_version=1,
    correlation_id=correlation_id,
    causation_id=causation_id,
    payload_json=payload,
)
```

# 22. Example outbox helper

```Python
import uuid
from app.db.models import OutboxEventModel


def append_outbox_event(
    db,
    aggregate_type: str,
    aggregate_id: str,
    event_type: str,
    event_version: int,
    correlation_id: str | None,
    causation_id: str | None,
    payload_json: dict,
):
    row = OutboxEventModel(
        id=str(uuid.uuid4()),
        aggregate_type=aggregate_type,
        aggregate_id=aggregate_id,
        event_type=event_type,
        event_version=event_version,
        correlation_id=correlation_id,
        causation_id=causation_id,
        payload_json=payload_json,
        status="pending",
    )
    db.add(row)
```

# 23. Example consumer idempotency helper

```Python
import uuid
from app.db.models import ProcessedEventModel


def has_processed_event(db, consumer_service: str, event_id: str) -> bool:
    row = (
        db.query(ProcessedEventModel)
        .filter(ProcessedEventModel.consumer_service == consumer_service)
        .filter(ProcessedEventModel.event_id == event_id)
        .first()
    )
    return row is not None


def mark_event_processed(db, consumer_service: str, event_id: str, event_type: str):
    row = ProcessedEventModel(
        id=str(uuid.uuid4()),
        consumer_service=consumer_service,
        event_id=event_id,
        event_type=event_type,
    )
    db.add(row)
```

# 24. UI changes for eventual consistency
The UI must reflect that workflows are no longer instantly complete.

## 24.1 Order submit UX
Instead of returning “filled” immediately, UI should show:
- order accepted
- correlation ID
- current state = `draft` or `risk_pending`
- refresh or live update

## 24.2 Order detail page
Show:
- order current state
- state history timeline
- risk evaluation panel
- execution panel
- position impact panel
- audit timeline

## 24.3 Status badges
Use statuses like:
- Draft
- Risk Pending
- Risk Passed
- Risk Failed
- Submitted
- Filled
- Execution Failed

# 25. Suggested first event-driven implementation order
Do not convert everything at once.

## Stage 1
- introduce outbox tables
- order-service writes `order_intent.created` to outbox
- build publisher worker
- validate topic publishing

## Stage 2
- risk-service consumes `order_intent.created`
- stores evaluation
- emits `risk.evaluation.completed`

## Stage 3
- order-service consumes `risk.evaluation.completed`
- updates order state history

## Stage 4
- execution-service consumes `risk.evaluation.completed`
- writes fill
- emits `execution.fill.recorded`

## Stage 5
- position-service consumes `execution.fill.recorded`
- updates position
- emits `position.updated`

## Stage 6
- audit-service consumes all important events

This phased path is much safer than a full rewrite.

# 26. Manual test flow after event-driven upgrade

## Step 1
Submit order from ops UI or API.

### Expected immediate result
Response:
- order accepted
- order id
- correlation id

## Step 2
Check order list after a short delay.
Expected:
- order transitions from `draft` to `risk_passed` to `filled`

## Step 3
Check positions.
Expected:
- updated quantity and average price

## Step 4
Check audit log.
Expected:
- multiple lifecycle events automatically recorded

## Step 5
Force a consumer failure test.
Expected:
- retry attempts
- failure surfaced clearly
- no duplicate business record creation

# 27. New operational runbooks you need
Add these runbooks:
- outbox backlog increasing
- consumer lag increasing
- dead-letter topic receiving events
- duplicate event suspicion
- event schema mismatch
- replaying missed business events
- reprocessing a failed order lifecycle
These become part of real platform operations.

# 28. What you gain after this upgrade
After this event-driven pass, the platform becomes:
- much easier to scale
- much easier to extend
- better for many strategies
- better for many read models
- better for audit and replay
- more fault-tolerant
This is the right backbone for enterprise growth.

# 29. What should come next
The next correct step is:

## Volume 8: strategy runtime and portfolio orchestration pack
That should add:
- strategy runtime workers
- signal generation events
- portfolio target generation
- capital allocation layer
- multi-strategy conflict resolution
- strategy deployment model
- paper/live runtime separation
- strategy health monitoring
That is where the system starts behaving like a real multi-strategy trading engine, not just an order workflow platform.