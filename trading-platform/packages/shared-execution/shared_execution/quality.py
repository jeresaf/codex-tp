def slippage_amount(intended_price: float, fill_price: float, side: str) -> float:
    if side == 'buy':
        return fill_price - intended_price
    return intended_price - fill_price


def slippage_bps(intended_price: float, fill_price: float, side: str) -> float:
    if intended_price == 0:
        return 0.0
    amt = slippage_amount(intended_price, fill_price, side)
    return (amt / intended_price) * 10000.0
