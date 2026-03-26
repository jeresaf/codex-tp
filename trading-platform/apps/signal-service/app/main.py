from fastapi import FastAPI
from app.api.routes.signals import router as signals_router

app = FastAPI(title="signal-service", version="0.1.0")
app.include_router(signals_router, prefix='/api/signals', tags=['signals'])

@app.get('/health/live')
def health_live():
    return {'status': 'ok', 'service': 'signal-service'}

@app.get('/health/ready')
def health_ready():
    return {'status': 'ready', 'service': 'signal-service'}
