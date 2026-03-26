from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import PortfolioTargetModel

router = APIRouter()


@router.get('/')
def list_targets(db: Session = Depends(get_db)):
    rows = db.query(PortfolioTargetModel).order_by(PortfolioTargetModel.created_at.desc()).limit(200).all()
    return [
        {
            'id': x.id,
            'instrument_id': x.instrument_id,
            'target_quantity': str(x.target_quantity),
            'delta_quantity': str(x.delta_quantity),
            'correlation_id': x.correlation_id,
        }
        for x in rows
    ]
