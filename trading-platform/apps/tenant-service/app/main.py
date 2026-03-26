from fastapi import FastAPI

app = FastAPI(title="tenant-service", version="0.1.0")

@app.get("/health/live")
def health_live():
    return {"status": "ok", "service": "tenant-service"}

@app.get("/health/ready")
def health_ready():
    return {"status": "ready", "service": "tenant-service"}
