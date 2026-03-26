from fastapi import FastAPI
from app.api.routes.runtime import router as runtime_router

app = FastAPI(title="strategy-runtime-service", version="0.1.0")
app.include_router(runtime_router, prefix="/api/runtime", tags=["runtime"])

@app.get('/health/live')
def health_live():
    return {'status': 'ok', 'service': 'strategy-runtime-service'}

@app.get('/health/ready')
def health_ready():
    return {'status': 'ready', 'service': 'strategy-runtime-service'}
