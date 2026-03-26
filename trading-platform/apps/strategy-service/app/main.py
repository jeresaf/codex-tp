from fastapi import FastAPI
from app.api.routes.strategies import router as strategies_router
app = FastAPI(title="strategy-service", version="0.1.0")
app.include_router(strategies_router, prefix="/api/strategies", tags=["strategies"])
@app.get("/health/live")
def health_live(): return {"status": "ok", "service": "strategy-service"}
@app.get("/health/ready")
def health_ready(): return {"status": "ready", "service": "strategy-service"}
