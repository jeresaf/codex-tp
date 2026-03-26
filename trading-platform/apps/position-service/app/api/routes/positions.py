import uuid
from decimal import Decimal
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import PositionModel
from app.domain.position_math import apply_fill
router = APIRouter()
class ApplyFillRequest(BaseModel):
    account_id: str | None = None
    instrument_id: str
    side: str
    fill_quantity: Decimal
    fill_price: Decimal
@router.get("/")
def list_positions(db: Session = Depends(get_db)):
    rows = db.query(PositionModel).order_by(PositionModel.instrument_id.asc()).all()
    return [{"id": x.id, "account_id": x.account_id, "instrument_id": x.instrument_id, "net_quantity": str(x.net_quantity), "avg_price": str(x.avg_price), "market_value": str(x.market_value), "unrealized_pnl": str(x.unrealized_pnl), "realized_pnl": str(x.realized_pnl)} for x in rows]
@router.post("/apply-fill")
def update_position(payload: ApplyFillRequest, db: Session = Depends(get_db)):
    row = db.query(PositionModel).filter(PositionModel.account_id == payload.account_id).filter(PositionModel.instrument_id == payload.instrument_id).first()
    if not row:
        row = PositionModel(id=str(uuid.uuid4()), account_id=payload.account_id, instrument_id=payload.instrument_id, net_quantity=0, avg_price=0, market_value=0, unrealized_pnl=0, realized_pnl=0)
        db.add(row)
        db.flush()
    updated = apply_fill({"net_quantity": row.net_quantity, "avg_price": row.avg_price}, payload.side, payload.fill_quantity, payload.fill_price)
    row.net_quantity = updated["net_quantity"]
    row.avg_price = updated["avg_price"]
    db.commit()
    db.refresh(row)
    return {"id": row.id, "account_id": row.account_id, "instrument_id": row.instrument_id, "net_quantity": str(row.net_quantity), "avg_price": str(row.avg_price), "market_value": str(row.market_value), "unrealized_pnl": str(row.unrealized_pnl), "realized_pnl": str(row.realized_pnl)}
