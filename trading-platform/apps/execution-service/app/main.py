from fastapi import FastAPI
from app.api.routes.execution import router as execution_router

app = FastAPI(title='execution-service', version='0.3.0')
app.include_router(execution_router, prefix='/api/execution', tags=['execution'])

@app.get('/health/live')
def health_live():
    return {'status': 'ok', 'service': 'execution-service'}

@app.get('/health/ready')
def health_ready():
    return {'status': 'ready', 'service': 'execution-service'}
