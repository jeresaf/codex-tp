from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import Market

router = APIRouter()


@router.get("/")
def list_markets(db: Session = Depends(get_db)):
    rows = db.query(Market).order_by(Market.code.asc()).all()
    return [
        {
            "id": x.id,
            "code": x.code,
            "name": x.name,
            "asset_class": x.asset_class,
            "timezone": x.timezone,
            "status": x.status,
        }
        for x in rows
    ]
