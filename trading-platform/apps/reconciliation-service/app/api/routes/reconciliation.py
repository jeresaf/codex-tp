from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import ReconciliationRunModel, ReconciliationIssueModel
from app.domain.reconcile import create_run, create_issue

router = APIRouter()

@router.post('/runs')
def create_reconciliation_run(payload: dict, db: Session = Depends(get_db)):
    row = create_run(db, run_type=payload['run_type'], account_id=payload.get('account_id'), venue_id=payload.get('venue_id'))
    db.commit()
    return {'id': row.id, 'status': row.status}

@router.get('/runs')
def list_reconciliation_runs(db: Session = Depends(get_db)):
    rows = db.query(ReconciliationRunModel).order_by(ReconciliationRunModel.created_at.desc()).limit(200).all()
    return [{'id': x.id, 'run_type': x.run_type, 'status': x.status, 'started_at': x.started_at} for x in rows]

@router.post('/issues')
def create_reconciliation_issue(payload: dict, db: Session = Depends(get_db)):
    row = create_issue(
        db,
        reconciliation_run_id=payload.get('reconciliation_run_id'),
        issue_type=payload['issue_type'],
        severity=payload['severity'],
        difference_json=payload.get('difference_json', {}),
        recommended_action=payload.get('recommended_action', 'manual_review'),
        account_id=payload.get('account_id'),
        venue_id=payload.get('venue_id'),
        internal_ref=payload.get('internal_ref'),
        external_ref=payload.get('external_ref'),
        correlation_id=payload.get('correlation_id'),
    )
    db.commit()
    return {'id': row.id, 'status': row.status}

@router.get('/issues')
def list_reconciliation_issues(db: Session = Depends(get_db)):
    rows = db.query(ReconciliationIssueModel).order_by(ReconciliationIssueModel.created_at.desc()).limit(200).all()
    return [{'id': x.id, 'issue_type': x.issue_type, 'severity': x.severity, 'status': x.status} for x in rows]
