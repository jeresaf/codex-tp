import uuid
from datetime import datetime, timezone
from shared_risk.policies import max_position_size_check
from shared_risk.exposure import drawdown
from app.db.models import RiskBreachModel, KillSwitchModel, DrawdownTrackerModel


def evaluate_pretrade(quantity: float, threshold: float = 100000.0) -> dict:
    return max_position_size_check(quantity, threshold)


def create_breach(db, *, risk_policy_id: str, scope_type: str, scope_id: str, breach_type: str, severity: str, measured_value: float, threshold_value: float, correlation_id: str | None, action_taken: str | None = None, details_json: dict | None = None):
    row = RiskBreachModel(
        id=str(uuid.uuid4()),
        risk_policy_id=risk_policy_id,
        scope_type=scope_type,
        scope_id=scope_id,
        breach_type=breach_type,
        severity=severity,
        measured_value=measured_value,
        threshold_value=threshold_value,
        details_json=details_json or {},
        action_taken=action_taken,
        status='open',
        correlation_id=correlation_id,
        detected_at=datetime.now(timezone.utc),
    )
    db.add(row)
    return row


def activate_kill_switch(db, *, scope_type: str, scope_id: str | None, action: str, reason: str, actor_type: str, actor_id: str | None, correlation_id: str | None):
    row = KillSwitchModel(
        id=str(uuid.uuid4()),
        scope_type=scope_type,
        scope_id=scope_id,
        switch_action=action,
        reason=reason,
        triggered_by_actor_type=actor_type,
        triggered_by_actor_id=actor_id,
        status='active',
        correlation_id=correlation_id,
        triggered_at=datetime.now(timezone.utc),
    )
    db.add(row)
    return row


def track_drawdown(db, *, scope_type: str, scope_id: str, current_equity: float, high_watermark: float):
    amount, pct = drawdown(current_equity, high_watermark)
    row = DrawdownTrackerModel(
        id=str(uuid.uuid4()),
        scope_type=scope_type,
        scope_id=scope_id,
        equity_high_watermark=high_watermark,
        current_equity=current_equity,
        drawdown_amount=amount,
        drawdown_percent=pct,
        snapshot_time=datetime.now(timezone.utc),
    )
    db.add(row)
    return row
