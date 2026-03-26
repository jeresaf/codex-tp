from fastapi import FastAPI

app = FastAPI(title="reporting-service", version="0.1.0")

@app.get("/health/live")
def health_live():
    return {"status": "ok", "service": "reporting-service"}

@app.get("/health/ready")
def health_ready():
    return {"status": "ready", "service": "reporting-service"}
