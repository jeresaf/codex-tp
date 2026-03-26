from fastapi import FastAPI
from app.api.routes.features import router as features_router

app = FastAPI(title='feature-service', version='0.1.0')
app.include_router(features_router, prefix='/api/features', tags=['features'])

@app.get('/health/live')
def health_live():
    return {'status': 'ok', 'service': 'feature-service'}

@app.get('/health/ready')
def health_ready():
    return {'status': 'ready', 'service': 'feature-service'}
