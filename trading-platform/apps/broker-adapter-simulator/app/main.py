from fastapi import FastAPI
app = FastAPI(title="broker-adapter-simulator", version="0.1.0")
@app.get("/health/live")
def health_live(): return {"status": "ok", "service": "broker-adapter-simulator"}
@app.get("/health/ready")
def health_ready(): return {"status": "ready", "service": "broker-adapter-simulator"}
@app.get("/api/simulator/status")
def simulator_status(): return {"mode": "paper", "status": "healthy"}
