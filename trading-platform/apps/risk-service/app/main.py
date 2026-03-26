from fastapi import FastAPI
from app.api.routes.risk import router as risk_router
from app.api.routes.controls import router as controls_router

app = FastAPI(title='risk-service', version='0.3.0')
app.include_router(risk_router, prefix='/api/risk', tags=['risk'])
app.include_router(controls_router, prefix='/api/risk', tags=['risk-controls'])

@app.get('/health/live')
def health_live():
    return {'status': 'ok', 'service': 'risk-service'}

@app.get('/health/ready')
def health_ready():
    return {'status': 'ready', 'service': 'risk-service'}
