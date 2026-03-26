from fastapi import FastAPI
from app.api.routes.replay import router as replay_router

app = FastAPI(title='replay-service', version='0.1.0')
app.include_router(replay_router, prefix='/api/replay', tags=['replay'])

@app.get('/health/live')
def health_live():
    return {'status': 'ok', 'service': 'replay-service'}

@app.get('/health/ready')
def health_ready():
    return {'status': 'ready', 'service': 'replay-service'}
