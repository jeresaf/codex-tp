from fastapi import FastAPI
from app.api.routes.workflows import router as workflows_router

app = FastAPI(title='workflow-service', version='0.1.0')
app.include_router(workflows_router, prefix='/api/workflows', tags=['workflows'])

@app.get('/health/live')
def health_live():
    return {'status': 'ok'}
