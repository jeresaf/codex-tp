from fastapi import FastAPI

app = FastAPI(title="broker-adapter-interactivebrokers", version="0.1.0")

@app.get("/health/live")
def health_live():
    return {"status": "ok", "service": "broker-adapter-interactivebrokers"}

@app.get("/health/ready")
def health_ready():
    return {"status": "ready", "service": "broker-adapter-interactivebrokers"}
