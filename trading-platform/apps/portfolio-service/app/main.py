from fastapi import FastAPI
from app.api.routes.targets import router as targets_router

app = FastAPI(title="portfolio-service", version="0.1.0")
app.include_router(targets_router, prefix='/api/targets', tags=['targets'])

@app.get('/health/live')
def health_live():
    return {'status': 'ok', 'service': 'portfolio-service'}

@app.get('/health/ready')
def health_ready():
    return {'status': 'ready', 'service': 'portfolio-service'}
