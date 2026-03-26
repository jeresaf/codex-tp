from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.workers.runtime_runner import run_sample_strategy_once

router = APIRouter()


@router.post('/run-sample')
def run_sample(payload: dict, db: Session = Depends(get_db)):
    return run_sample_strategy_once(
        db=db,
        candle=payload['candle'],
        strategy_deployment_id=payload['strategy_deployment_id'],
        strategy_version_id=payload.get('strategy_version_id'),
        correlation_id=payload.get('correlation_id'),
    )
