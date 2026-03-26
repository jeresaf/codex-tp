from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import StrategySignalModel

router = APIRouter()


@router.get('/')
def list_signals(db: Session = Depends(get_db)):
    rows = db.query(StrategySignalModel).order_by(StrategySignalModel.created_at.desc()).limit(200).all()
    return [
        {
            'id': x.id,
            'strategy_deployment_id': x.strategy_deployment_id,
            'instrument_id': x.instrument_id,
            'direction': x.direction,
            'strength': x.strength,
            'confidence': x.confidence,
            'signal_timestamp': x.signal_timestamp,
        }
        for x in rows
    ]
