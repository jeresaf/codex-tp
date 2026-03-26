from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import Venue

router = APIRouter()


@router.get("/")
def list_venues(
    code: str | None = Query(default=None),
    market_id: str | None = Query(default=None),
    db: Session = Depends(get_db),
):
    query = db.query(Venue)
    if code:
        query = query.filter(Venue.code == code)
    if market_id:
        query = query.filter(Venue.market_id == market_id)
    rows = query.order_by(Venue.code.asc()).all()
    return [
        {
            "id": x.id,
            "market_id": x.market_id,
            "code": x.code,
            "name": x.name,
            "venue_type": x.venue_type,
            "status": x.status,
        }
        for x in rows
    ]
