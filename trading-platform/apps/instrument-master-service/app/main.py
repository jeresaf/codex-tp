from fastapi import FastAPI
from app.api.routes.instruments import router as instruments_router
app = FastAPI(title="instrument-master-service", version="0.1.0")
app.include_router(instruments_router, prefix="/api/instruments", tags=["instruments"])
@app.get("/health/live")
def health_live(): return {"status": "ok", "service": "instrument-master-service"}
@app.get("/health/ready")
def health_ready(): return {"status": "ready", "service": "instrument-master-service"}
