from fastapi import FastAPI
from app.api.routes.compliance import router as compliance_router

app = FastAPI(title='compliance-service', version='0.1.0')
app.include_router(compliance_router, prefix='/api/compliance', tags=['compliance'])

@app.get('/health/live')
def health_live():
    return {'status': 'ok'}
