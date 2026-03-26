from shared_features.indicators.sma import sma

FEATURE_REGISTRY = {
    'SMA_20': {'fn': lambda values: sma(values, 20), 'warmup': 20, 'timeframe': '1m'},
    'SMA_50': {'fn': lambda values: sma(values, 50), 'warmup': 50, 'timeframe': '1m'},
}
