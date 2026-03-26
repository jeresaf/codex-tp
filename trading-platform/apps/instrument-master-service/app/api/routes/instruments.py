from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import Instrument
router = APIRouter()
@router.get("/")
def list_instruments(db: Session = Depends(get_db)):
    rows = db.query(Instrument).order_by(Instrument.canonical_symbol.asc()).all()
    return [{"id": x.id, "canonical_symbol": x.canonical_symbol, "external_symbol": x.external_symbol, "asset_class": x.asset_class, "base_asset": x.base_asset, "quote_asset": x.quote_asset, "tick_size": str(x.tick_size), "lot_size": str(x.lot_size), "price_precision": x.price_precision, "quantity_precision": x.quantity_precision, "status": x.status} for x in rows]
