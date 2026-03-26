import uuid
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import RiskBreachModel, KillSwitchModel, RiskExposureSnapshotModel, DrawdownTrackerModel
from app.domain.controls import create_breach, activate_kill_switch, track_drawdown

router = APIRouter()

@router.get('/breaches')
def list_breaches(db: Session = Depends(get_db)):
    rows = db.query(RiskBreachModel).order_by(RiskBreachModel.created_at.desc()).limit(200).all()
    return [{'id': x.id, 'breach_type': x.breach_type, 'severity': x.severity, 'status': x.status, 'detected_at': x.detected_at} for x in rows]

@router.post('/kill-switches')
def create_kill_switch(payload: dict, db: Session = Depends(get_db)):
    row = activate_kill_switch(
        db,
        scope_type=payload['scope_type'],
        scope_id=payload.get('scope_id'),
        action=payload.get('switch_action', 'reject_new_orders'),
        reason=payload.get('reason', 'manual'),
        actor_type=payload.get('triggered_by_actor_type', 'user'),
        actor_id=payload.get('triggered_by_actor_id'),
        correlation_id=payload.get('correlation_id'),
    )
    db.commit()
    return {'id': row.id, 'status': row.status}

@router.get('/kill-switches')
def list_kill_switches(db: Session = Depends(get_db)):
    rows = db.query(KillSwitchModel).order_by(KillSwitchModel.created_at.desc()).limit(200).all()
    return [{'id': x.id, 'scope_type': x.scope_type, 'scope_id': x.scope_id, 'switch_action': x.switch_action, 'status': x.status} for x in rows]

@router.post('/drawdown-trackers')
def create_drawdown_tracker(payload: dict, db: Session = Depends(get_db)):
    row = track_drawdown(db, scope_type=payload['scope_type'], scope_id=payload['scope_id'], current_equity=float(payload['current_equity']), high_watermark=float(payload['high_watermark']))
    db.commit()
    return {'id': row.id, 'drawdown_amount': str(row.drawdown_amount), 'drawdown_percent': str(row.drawdown_percent)}

@router.get('/drawdown-trackers')
def list_drawdown_trackers(db: Session = Depends(get_db)):
    rows = db.query(DrawdownTrackerModel).order_by(DrawdownTrackerModel.created_at.desc()).limit(200).all()
    return [{'id': x.id, 'scope_type': x.scope_type, 'scope_id': x.scope_id, 'drawdown_amount': str(x.drawdown_amount), 'drawdown_percent': str(x.drawdown_percent)} for x in rows]
