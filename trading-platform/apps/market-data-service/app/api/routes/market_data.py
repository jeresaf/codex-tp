import uuid
from datetime import datetime, timezone
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import RawMarketEventModel, NormalizedCandleModel, OutboxEventModel
from app.domain.normalize import normalize_demo_candle
from shared_events.outbox import append_outbox_event

router = APIRouter()

@router.post('/ingest-candle')
def ingest_candle(payload: dict, db: Session = Depends(get_db)):
    raw = RawMarketEventModel(
        id=str(uuid.uuid4()),
        provider_code=payload.get('provider_code', 'demo'),
        event_type='candle',
        external_symbol=payload.get('external_symbol'),
        payload_json=payload,
        event_time=payload.get('close_time'),
        arrival_time=datetime.now(timezone.utc),
        checksum=None,
    )
    db.add(raw)
    db.flush()
    candle, issues = normalize_demo_candle(payload)
    norm = NormalizedCandleModel(**candle)
    db.add(norm)
    db.flush()
    append_outbox_event(
        db=db,
        model_cls=OutboxEventModel,
        aggregate_type='normalized_candle',
        aggregate_id=norm.id,
        event_type='market_data.candle.closed',
        event_version=1,
        correlation_id=payload.get('correlation_id'),
        causation_id=None,
        payload_json={
            'candle_id': norm.id,
            'instrument_id': norm.instrument_id,
            'timeframe': norm.timeframe,
            'open_time': str(norm.open_time),
            'close_time': str(norm.close_time),
            'open': str(norm.open),
            'high': str(norm.high),
            'low': str(norm.low),
            'close': str(norm.close),
            'volume': str(norm.volume or 0),
            'quality_flag': norm.quality_flag,
        },
    )
    db.commit()
    return {'raw_id': raw.id, 'normalized_id': norm.id, 'issues': issues}

@router.get('/candles')
def list_candles(db: Session = Depends(get_db)):
    rows = db.query(NormalizedCandleModel).order_by(NormalizedCandleModel.close_time.desc()).limit(200).all()
    return [{
        'id': x.id,
        'instrument_id': x.instrument_id,
        'timeframe': x.timeframe,
        'open_time': x.open_time,
        'close_time': x.close_time,
        'open': str(x.open),
        'high': str(x.high),
        'low': str(x.low),
        'close': str(x.close),
        'quality_flag': x.quality_flag,
    } for x in rows]
