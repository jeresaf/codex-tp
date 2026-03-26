from fastapi import FastAPI

app = FastAPI(title="paper-trading-service", version="0.1.0")

@app.get("/health/live")
def health_live():
    return {"status": "ok", "service": "paper-trading-service"}

@app.get("/health/ready")
def health_ready():
    return {"status": "ready", "service": "paper-trading-service"}
