from fastapi import FastAPI
from app.api.routes.markets import router as markets_router
from app.api.routes.venues import router as venues_router

app = FastAPI(title="market-registry-service", version="0.2.0")
app.include_router(markets_router, prefix="/api/markets", tags=["markets"])
app.include_router(venues_router, prefix="/api/venues", tags=["venues"])


@app.get("/health/live")
def health_live():
    return {"status": "ok", "service": "market-registry-service"}


@app.get("/health/ready")
def health_ready():
    return {"status": "ready", "service": "market-registry-service"}
