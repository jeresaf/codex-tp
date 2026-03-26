def gross_exposure(notional_values: list[float]) -> float:
    return sum(abs(x) for x in notional_values)


def net_exposure(signed_notional_values: list[float]) -> float:
    return sum(signed_notional_values)


def drawdown(current_equity: float, high_watermark: float) -> tuple[float, float]:
    amount = high_watermark - current_equity
    pct = 0.0 if high_watermark == 0 else amount / high_watermark
    return amount, pct
