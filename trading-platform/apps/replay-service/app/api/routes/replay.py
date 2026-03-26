import uuid
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import ReplayJobModel
from app.domain.replay_runner import run_replay_stub

router = APIRouter()

@router.post('/jobs')
def create_replay_job(payload: dict, db: Session = Depends(get_db)):
    row = ReplayJobModel(
        id=str(uuid.uuid4()),
        dataset_version_id=payload['dataset_version_id'],
        strategy_version_id=payload.get('strategy_version_id'),
        start_time=payload['start_time'],
        end_time=payload['end_time'],
        status='queued',
        config_json=payload.get('config_json', {}),
        result_uri=None,
    )
    db.add(row)
    db.commit()
    return {'id': row.id, **run_replay_stub(payload)}

@router.get('/jobs')
def list_replay_jobs(db: Session = Depends(get_db)):
    rows = db.query(ReplayJobModel).order_by(ReplayJobModel.created_at.desc()).all()
    return [{'id': x.id, 'dataset_version_id': x.dataset_version_id, 'status': x.status, 'created_at': x.created_at} for x in rows]
