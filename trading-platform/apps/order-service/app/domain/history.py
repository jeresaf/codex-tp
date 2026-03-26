import uuid
from app.db.models import OrderStateHistoryModel


def record_order_transition(
    db,
    order_intent_id: str,
    from_state: str | None,
    to_state: str,
    transition_reason: str | None,
    actor_type: str,
    actor_id: str | None = None,
    metadata_json: dict | None = None,
):
    row = OrderStateHistoryModel(
        id=str(uuid.uuid4()),
        order_intent_id=order_intent_id,
        from_state=from_state,
        to_state=to_state,
        transition_reason=transition_reason,
        actor_type=actor_type,
        actor_id=actor_id,
        metadata_json=metadata_json,
    )
    db.add(row)
