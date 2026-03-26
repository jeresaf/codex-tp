from fastapi import FastAPI
from app.api.routes.reconciliation import router as reconciliation_router

app = FastAPI(title='reconciliation-service', version='0.1.0')
app.include_router(reconciliation_router, prefix='/api/reconciliation', tags=['reconciliation'])

@app.get('/health/live')
def health_live():
    return {'status': 'ok', 'service': 'reconciliation-service'}

@app.get('/health/ready')
def health_ready():
    return {'status': 'ready', 'service': 'reconciliation-service'}
