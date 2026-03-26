from fastapi import FastAPI
from app.api.routes.orders import router as orders_router

app = FastAPI(title="order-service", version="0.2.0")
app.include_router(orders_router, prefix="/api/orders", tags=["orders"])

@app.get("/health/live")
def health_live():
    return {"status": "ok", "service": "order-service"}

@app.get("/health/ready")
def health_ready():
    return {"status": "ready", "service": "order-service"}
