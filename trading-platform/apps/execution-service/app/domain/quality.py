import uuid
from shared_execution.quality import slippage_amount, slippage_bps
from app.db.models import ExecutionQualityMetricModel, BrokerOrderStateHistoryModel


def record_state_history(db, *, broker_order_id: str, from_state: str | None, to_state: str, reason: str | None, metadata_json: dict | None = None):
    row = BrokerOrderStateHistoryModel(
        id=str(uuid.uuid4()),
        broker_order_id=broker_order_id,
        from_state=from_state,
        to_state=to_state,
        transition_reason=reason,
        metadata_json=metadata_json or {},
    )
    db.add(row)
    return row


def record_execution_quality(db, *, broker_order_id: str, order_intent_id: str, instrument_id: str, venue_id: str, side: str, intended_price: float, submitted_price: float, fill_price: float, fee_amount: float = 0.0, fee_currency: str = 'USD'):
    row = ExecutionQualityMetricModel(
        id=str(uuid.uuid4()),
        broker_order_id=broker_order_id,
        order_intent_id=order_intent_id,
        strategy_deployment_id=None,
        instrument_id=instrument_id,
        venue_id=venue_id,
        intended_price=intended_price,
        submitted_price=submitted_price,
        avg_fill_price=fill_price,
        slippage_amount=slippage_amount(intended_price, fill_price, side),
        slippage_bps=slippage_bps(intended_price, fill_price, side),
        total_fee_amount=fee_amount,
        fee_currency=fee_currency,
        ack_latency_ms=0,
        full_fill_latency_ms=0,
    )
    db.add(row)
    return row
