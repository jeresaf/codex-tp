import uuid
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import DatasetVersionModel

router = APIRouter()

@router.post('/')
def create_dataset(payload: dict, db: Session = Depends(get_db)):
    row = DatasetVersionModel(
        id=str(uuid.uuid4()),
        dataset_code=payload['dataset_code'],
        dataset_version=payload['dataset_version'],
        manifest_json=payload['manifest_json'],
        storage_uri=payload.get('storage_uri'),
        checksum=payload.get('checksum'),
        created_by=payload.get('created_by'),
    )
    db.add(row)
    db.commit()
    return {'id': row.id}

@router.get('/')
def list_datasets(db: Session = Depends(get_db)):
    rows = db.query(DatasetVersionModel).order_by(DatasetVersionModel.created_at.desc()).all()
    return [{'id': x.id, 'dataset_code': x.dataset_code, 'dataset_version': x.dataset_version, 'created_at': x.created_at} for x in rows]
