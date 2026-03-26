from fastapi import FastAPI
from app.api.routes.datasets import router as datasets_router

app = FastAPI(title='dataset-service', version='0.1.0')
app.include_router(datasets_router, prefix='/api/datasets', tags=['datasets'])

@app.get('/health/live')
def health_live():
    return {'status': 'ok', 'service': 'dataset-service'}

@app.get('/health/ready')
def health_ready():
    return {'status': 'ready', 'service': 'dataset-service'}
