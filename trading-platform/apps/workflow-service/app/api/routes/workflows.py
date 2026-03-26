import uuid
from datetime import datetime, timezone
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import WorkflowModel, WorkflowRunModel

router = APIRouter()

@router.post('/')
def create_workflow(payload: dict, db: Session = Depends(get_db)):
    row = WorkflowModel(id=str(uuid.uuid4()), **payload)
    db.add(row)
    db.commit()
    return {'id': row.id}

@router.post('/runs')
def start_run(payload: dict, db: Session = Depends(get_db)):
    row = WorkflowRunModel(
        id=str(uuid.uuid4()),
        workflow_id=payload['workflow_id'],
        status='running',
        subject_type=payload['subject_type'],
        subject_id=payload['subject_id'],
        context_json=payload.get('context_json'),
        started_at=datetime.now(timezone.utc),
    )
    db.add(row)
    db.commit()
    return {'id': row.id}
