ALLOWED_TRANSITIONS = {
    "draft": {"risk_pending"},
    "risk_pending": {"risk_passed", "risk_failed"},
    "risk_passed": {"submitted"},
    "submitted": {"filled", "execution_failed", "rejected"},
}


def can_transition(current_state: str, next_state: str) -> bool:
    return next_state in ALLOWED_TRANSITIONS.get(current_state, set())
