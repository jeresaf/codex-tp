import uuid
from decimal import Decimal
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.db.models import RiskEvaluationModel, KillSwitchModel
from app.config import settings
from shared_auth.dependencies import validate_internal_service
from shared_observability.correlation import get_or_create_correlation_id
from app.domain.controls import evaluate_pretrade, create_breach

router = APIRouter()

class RiskEvaluationRequest(BaseModel):
    order_intent_id: str
    quantity: Decimal
    side: str
    instrument_id: str
    account_id: str | None = None

@router.post('/evaluate')
def evaluate_order(
    payload: RiskEvaluationRequest,
    db: Session = Depends(get_db),
    internal=Depends(validate_internal_service(settings.internal_service_token)),
    correlation_id: str = Depends(get_or_create_correlation_id),
):
    active_switch = db.query(KillSwitchModel).filter(KillSwitchModel.status == 'active').first()
    if active_switch:
        results = [{
            'passed': False,
            'rule_type': 'kill_switch',
            'message': 'Trading blocked by active kill switch',
            'severity': 'critical',
        }]
        decision = 'reject'
        next_state = 'risk_failed'
    else:
        control = evaluate_pretrade(float(payload.quantity), 100000.0)
        results = [control]
        failed = [r for r in results if not r['passed']]
        decision = 'reject' if failed else 'pass'
        next_state = 'risk_failed' if failed else 'risk_passed'
        if failed:
            create_breach(
                db,
                risk_policy_id=str(uuid.uuid4()),
                scope_type='order',
                scope_id=payload.order_intent_id,
                breach_type=failed[0]['rule_type'],
                severity=failed[0]['severity'],
                measured_value=float(payload.quantity),
                threshold_value=float(failed[0].get('threshold', 0)),
                correlation_id=correlation_id,
                action_taken='reject_new_orders',
                details_json={'order_intent_id': payload.order_intent_id},
            )

    row = RiskEvaluationModel(
        id=str(uuid.uuid4()),
        order_intent_id=payload.order_intent_id,
        decision=decision,
        next_state=next_state,
        rule_results={'rule_results': results},
        evaluated_by_service='risk-service',
        correlation_id=correlation_id,
    )
    db.add(row)
    db.commit()
    return {
        'order_intent_id': payload.order_intent_id,
        'decision': decision,
        'rule_results': results,
        'next_state': next_state,
        'correlation_id': correlation_id,
    }
