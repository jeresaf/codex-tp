from decimal import Decimal
from pydantic import BaseModel


class OrderIntentCreate(BaseModel):
    strategy_deployment_id: str | None = None
    account_id: str | None = None
    instrument_id: str
    signal_id: str | None = None
    side: str
    order_type: str
    quantity: Decimal
    limit_price: Decimal | None = None
    stop_price: Decimal | None = None
    tif: str
    venue_id: str
    execution_price: Decimal


class OrderSubmitResponse(BaseModel):
    order_id: str
    final_status: str
    risk_decision: str
    execution: dict | None = None
    position: dict | None = None
    correlation_id: str
    error: dict | None = None
