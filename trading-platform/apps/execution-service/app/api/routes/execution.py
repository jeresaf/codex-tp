import uuid
from decimal import Decimal
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import BrokerOrderModel, FillModel, ExecutionQualityMetricModel
from app.domain.quality import record_execution_quality, record_state_history

router = APIRouter()

class SimulateExecutionRequest(BaseModel):
    order_intent_id: str
    venue_id: str
    instrument_id: str
    quantity: Decimal
    price: Decimal
    fee_amount: Decimal = Decimal('0.0')
    fee_currency: str = 'USD'
    side: str = 'buy'

@router.post('/simulate')
def simulate_execution(payload: SimulateExecutionRequest, db: Session = Depends(get_db)):
    broker_order = BrokerOrderModel(
        id=str(uuid.uuid4()),
        order_intent_id=payload.order_intent_id,
        venue_id=payload.venue_id,
        external_order_id=f'sim-{uuid.uuid4()}',
        broker_status='filled',
        raw_request=payload.model_dump(mode='json'),
        raw_response={'status': 'filled'},
    )
    db.add(broker_order)
    db.flush()
    record_state_history(db, broker_order_id=broker_order.id, from_state=None, to_state='submitted', reason='simulated_submit')
    record_state_history(db, broker_order_id=broker_order.id, from_state='submitted', to_state='filled', reason='simulated_fill')
    fill = FillModel(
        id=str(uuid.uuid4()),
        broker_order_id=broker_order.id,
        instrument_id=payload.instrument_id,
        fill_price=payload.price,
        fill_quantity=payload.quantity,
        fee_amount=payload.fee_amount,
        fee_currency=payload.fee_currency,
        raw_payload={'simulation': True},
    )
    db.add(fill)
    record_execution_quality(
        db,
        broker_order_id=broker_order.id,
        order_intent_id=payload.order_intent_id,
        instrument_id=payload.instrument_id,
        venue_id=payload.venue_id,
        side=payload.side,
        intended_price=float(payload.price),
        submitted_price=float(payload.price),
        fill_price=float(payload.price),
        fee_amount=float(payload.fee_amount),
        fee_currency=payload.fee_currency,
    )
    db.commit()
    return {
        'broker_order_id': broker_order.id,
        'external_order_id': broker_order.external_order_id,
        'fill_id': fill.id,
        'status': 'filled',
        'fill': {
            'instrument_id': payload.instrument_id,
            'quantity': str(payload.quantity),
            'price': str(payload.price),
            'fee_amount': str(payload.fee_amount),
            'fee_currency': payload.fee_currency,
        },
    }

@router.get('/quality-metrics')
def list_quality_metrics(db: Session = Depends(get_db)):
    rows = db.query(ExecutionQualityMetricModel).order_by(ExecutionQualityMetricModel.created_at.desc()).limit(200).all()
    return [{'id': x.id, 'broker_order_id': x.broker_order_id, 'slippage_bps': str(x.slippage_bps), 'total_fee_amount': str(x.total_fee_amount)} for x in rows]
