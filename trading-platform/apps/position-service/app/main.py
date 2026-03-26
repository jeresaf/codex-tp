from fastapi import FastAPI
from app.api.routes.positions import router as positions_router

app = FastAPI(title="position-service", version="0.2.0")
app.include_router(positions_router, prefix="/api/positions", tags=["positions"])

@app.get("/health/live")
def health_live():
    return {"status": "ok", "service": "position-service"}

@app.get("/health/ready")
def health_ready():
    return {"status": "ready", "service": "position-service"}
