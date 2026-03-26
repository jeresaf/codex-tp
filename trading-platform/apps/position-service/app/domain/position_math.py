from decimal import Decimal


def apply_fill(position: dict, side: str, fill_qty: Decimal, fill_price: Decimal) -> dict:
    current_qty = Decimal(str(position.get("net_quantity", "0")))
    avg_price = Decimal(str(position.get("avg_price", "0")))
    signed_qty = fill_qty if side == "buy" else -fill_qty
    new_qty = current_qty + signed_qty
    same_direction = current_qty == 0 or (current_qty > 0 and signed_qty > 0) or (current_qty < 0 and signed_qty < 0)
    if same_direction:
        total_cost = (current_qty * avg_price) + (signed_qty * fill_price)
        new_avg = total_cost / new_qty if new_qty != 0 else Decimal("0")
    else:
        new_avg = avg_price if new_qty != 0 else Decimal("0")
    return {"net_quantity": new_qty, "avg_price": new_avg}
