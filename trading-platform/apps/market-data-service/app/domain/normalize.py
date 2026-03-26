import uuid
from datetime import datetime, timezone
from shared_market_data.candles import validate_candle


def normalize_demo_candle(payload: dict) -> tuple[dict, list[str]]:
    candle = {
        'id': str(uuid.uuid4()),
        'instrument_id': payload['instrument_id'],
        'timeframe': payload.get('timeframe', '1m'),
        'open_time': payload['open_time'],
        'close_time': payload['close_time'],
        'open': payload['open'],
        'high': payload['high'],
        'low': payload['low'],
        'close': payload['close'],
        'volume': payload.get('volume', 0),
        'source': payload.get('source', 'demo-feed'),
        'quality_flag': 'ok',
        'arrival_time': datetime.now(timezone.utc).isoformat(),
    }
    issues = validate_candle(candle)
    if issues:
        candle['quality_flag'] = 'warning'
    return candle, issues
