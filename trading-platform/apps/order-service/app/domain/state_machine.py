from app.domain.history import record_order_transition
from shared_domain.order_state import can_transition


def transition_order(db, row, next_state: str, reason: str | None = None):
    current_state = row.intent_status
    if not can_transition(current_state, next_state):
        raise ValueError(f"Illegal order state transition: {current_state} -> {next_state}")
    row.intent_status = next_state
    record_order_transition(
        db=db,
        order_intent_id=row.id,
        from_state=current_state,
        to_state=next_state,
        transition_reason=reason,
        actor_type="system",
        metadata_json=None,
    )
    return row
