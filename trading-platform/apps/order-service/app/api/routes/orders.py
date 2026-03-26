import uuid
from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.db.models import OrderIntentModel, OutboxEventModel
from app.api.schemas import OrderIntentCreate
from app.domain.idempotency import get_idempotent_response, store_idempotent_response
from app.domain.state_machine import transition_order
from app.config import settings
from shared_auth.dependencies import require_user_context
from shared_observability.correlation import get_or_create_correlation_id
from shared_events.outbox import append_outbox_event

router = APIRouter()


@router.get("/")
def list_orders(
    db: Session = Depends(get_db),
    user=Depends(require_user_context(settings.jwt_secret, settings.jwt_algorithm)),
):
    rows = db.query(OrderIntentModel).order_by(OrderIntentModel.created_at.desc()).all()
    return [
        {
            "id": x.id,
            "instrument_id": x.instrument_id,
            "side": x.side,
            "order_type": x.order_type,
            "quantity": str(x.quantity),
            "intent_status": x.intent_status,
            "correlation_id": x.correlation_id,
            "created_at": x.created_at,
        }
        for x in rows
    ]


@router.post("/submit")
async def submit_order(
    payload: OrderIntentCreate,
    db: Session = Depends(get_db),
    user=Depends(require_user_context(settings.jwt_secret, settings.jwt_algorithm)),
    correlation_id: str = Depends(get_or_create_correlation_id),
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
):
    if idempotency_key:
        cached = get_idempotent_response(db, "order_submit_async", idempotency_key)
        if cached:
            return cached

    row = OrderIntentModel(
        id=str(uuid.uuid4()),
        strategy_deployment_id=payload.strategy_deployment_id,
        account_id=payload.account_id,
        instrument_id=payload.instrument_id,
        signal_id=payload.signal_id,
        side=payload.side,
        order_type=payload.order_type,
        quantity=payload.quantity,
        limit_price=payload.limit_price,
        stop_price=payload.stop_price,
        tif=payload.tif,
        intent_status="draft",
        correlation_id=correlation_id,
    )
    db.add(row)
    db.flush()

    append_outbox_event(
        db=db,
        model_cls=OutboxEventModel,
        aggregate_type="order_intent",
        aggregate_id=row.id,
        event_type="order_intent.created",
        event_version=1,
        correlation_id=correlation_id,
        causation_id=None,
        payload_json={
            "order_intent_id": row.id,
            "account_id": row.account_id,
            "instrument_id": row.instrument_id,
            "side": row.side,
            "order_type": row.order_type,
            "quantity": str(row.quantity),
            "tif": row.tif,
            "venue_id": payload.venue_id,
            "execution_price": str(payload.execution_price),
        },
    )
    transition_order(db, row, "risk_pending", reason="event_pipeline_started")
    db.commit()
    db.refresh(row)

    response = {
        "order_id": row.id,
        "status": "accepted",
        "intent_status": row.intent_status,
        "correlation_id": correlation_id,
    }
    if idempotency_key:
        store_idempotent_response(db, "order_submit_async", idempotency_key, response)
        db.commit()
    return response
