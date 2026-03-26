def weighted_direction_score(direction: str, strength: float, confidence: float, strategy_weight: float) -> float:
    sign = 1.0 if direction == 'long' else -1.0
    return sign * strength * confidence * strategy_weight


def target_quantity_from_score(score: float, base_quantity: float = 1000.0) -> float:
    if abs(score) < 0.01:
        return 0.0
    qty = base_quantity * abs(score)
    return qty if score > 0 else -qty
