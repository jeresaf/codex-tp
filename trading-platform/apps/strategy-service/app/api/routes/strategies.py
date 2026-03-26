from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import Strategy
router = APIRouter()
@router.get("/")
def list_strategies(db: Session = Depends(get_db)):
    rows = db.query(Strategy).order_by(Strategy.code.asc()).all()
    return [{"id": x.id, "code": x.code, "name": x.name, "type": x.type, "owner_user_id": x.owner_user_id, "description": x.description, "status": x.status} for x in rows]
