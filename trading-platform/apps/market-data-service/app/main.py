from fastapi import FastAPI
from app.api.routes.market_data import router as market_data_router

app = FastAPI(title='market-data-service', version='0.1.0')
app.include_router(market_data_router, prefix='/api/market-data', tags=['market-data'])

@app.get('/health/live')
def health_live():
    return {'status': 'ok', 'service': 'market-data-service'}

@app.get('/health/ready')
def health_ready():
    return {'status': 'ready', 'service': 'market-data-service'}
