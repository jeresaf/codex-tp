from fastapi import FastAPI
from app.api.routes.auth import router as auth_router
app = FastAPI(title="identity-service", version="0.1.0")
app.include_router(auth_router, prefix="/api/auth", tags=["auth"])
@app.get("/health/live")
def health_live(): return {"status": "ok", "service": "identity-service"}
@app.get("/health/ready")
def health_ready(): return {"status": "ready", "service": "identity-service"}
