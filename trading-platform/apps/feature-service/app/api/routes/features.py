import uuid
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import FeatureDefinitionModel, FeatureValueModel
from app.domain.backfill import backfill_features
from shared_features.registry.feature_registry import FEATURE_REGISTRY

router = APIRouter()

@router.post('/seed-definitions')
def seed_definitions(db: Session = Depends(get_db)):
    created = 0
    for code, meta in FEATURE_REGISTRY.items():
        exists = db.query(FeatureDefinitionModel).filter(FeatureDefinitionModel.feature_code == code).first()
        if exists:
            continue
        row = FeatureDefinitionModel(
            id=str(uuid.uuid4()),
            feature_code=code,
            name=code,
            description=f'{code} feature',
            timeframe=meta['timeframe'],
            formula_ref=code,
            implementation_version='0.1.0',
            required_warmup=meta['warmup'],
            null_handling='propagate',
            dependencies_json={},
            output_schema_json={'type': 'double'},
        )
        db.add(row)
        created += 1
    db.commit()
    return {'created': created}

@router.get('/definitions')
def list_definitions(db: Session = Depends(get_db)):
    rows = db.query(FeatureDefinitionModel).order_by(FeatureDefinitionModel.feature_code.asc()).all()
    return [{'id': x.id, 'feature_code': x.feature_code, 'timeframe': x.timeframe, 'required_warmup': x.required_warmup} for x in rows]

@router.get('/values')
def list_values(db: Session = Depends(get_db)):
    rows = db.query(FeatureValueModel).order_by(FeatureValueModel.created_at.desc()).limit(200).all()
    return [{'id': x.id, 'feature_code': x.feature_code, 'instrument_id': x.instrument_id, 'value_time': x.value_time, 'value_double': x.value_double} for x in rows]

@router.post('/backfill')
def backfill(payload: dict, db: Session = Depends(get_db)):
    return backfill_features(db, payload['candles'], payload['feature_codes'])
