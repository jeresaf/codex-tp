import uuid
from datetime import datetime, timezone
from app.db.models import ReconciliationRunModel, ReconciliationIssueModel


def create_run(db, *, run_type: str, account_id: str | None = None, venue_id: str | None = None):
    row = ReconciliationRunModel(
        id=str(uuid.uuid4()),
        run_type=run_type,
        account_id=account_id,
        venue_id=venue_id,
        status='running',
        summary_json={},
        started_at=datetime.now(timezone.utc),
    )
    db.add(row)
    db.flush()
    return row


def create_issue(db, *, reconciliation_run_id: str | None, issue_type: str, severity: str, difference_json: dict, recommended_action: str, account_id: str | None = None, venue_id: str | None = None, internal_ref: str | None = None, external_ref: str | None = None, correlation_id: str | None = None):
    row = ReconciliationIssueModel(
        id=str(uuid.uuid4()),
        reconciliation_run_id=reconciliation_run_id,
        issue_type=issue_type,
        account_id=account_id,
        venue_id=venue_id,
        severity=severity,
        internal_ref=internal_ref,
        external_ref=external_ref,
        difference_json=difference_json,
        recommended_action=recommended_action,
        status='open',
        correlation_id=correlation_id,
        detected_at=datetime.now(timezone.utc),
    )
    db.add(row)
    return row
