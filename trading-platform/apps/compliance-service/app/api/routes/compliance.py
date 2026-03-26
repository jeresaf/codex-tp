import uuid
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import ComplianceExportModel

router = APIRouter()

@router.post('/exports')
def create_export(payload: dict, db: Session = Depends(get_db)):
    row = ComplianceExportModel(id=str(uuid.uuid4()), status='pending', **payload)
    db.add(row)
    db.commit()
    return {'id': row.id}

@router.get('/exports')
def list_exports(db: Session = Depends(get_db)):
    rows = db.query(ComplianceExportModel).order_by(ComplianceExportModel.created_at.desc()).all()
    return [{'id': x.id, 'export_type': x.export_type, 'status': x.status} for x in rows]
