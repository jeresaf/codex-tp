import uuid
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import AuditEventModel
router = APIRouter()
class AuditCreateRequest(BaseModel):
    actor_type: str
    actor_id: str | None = None
    event_type: str
    resource_type: str
    resource_id: str | None = None
    before_json: dict | None = None
    after_json: dict | None = None
@router.get("/")
def list_audit(db: Session = Depends(get_db)):
    rows = db.query(AuditEventModel).order_by(AuditEventModel.created_at.desc()).limit(200).all()
    return [{"id": x.id, "actor_type": x.actor_type, "actor_id": x.actor_id, "event_type": x.event_type, "resource_type": x.resource_type, "resource_id": x.resource_id, "created_at": x.created_at} for x in rows]
@router.post("/")
def create_audit(payload: AuditCreateRequest, db: Session = Depends(get_db)):
    row = AuditEventModel(id=str(uuid.uuid4()), **payload.model_dump())
    db.add(row)
    db.commit()
    db.refresh(row)
    return {"id": row.id}
