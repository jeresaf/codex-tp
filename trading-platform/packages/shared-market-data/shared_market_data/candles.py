def validate_candle(candle: dict) -> list[str]:
    issues = []
    if float(candle['low']) > float(candle['high']):
        issues.append('low_gt_high')
    if float(candle['open']) < 0 or float(candle['high']) < 0 or float(candle['low']) < 0 or float(candle['close']) < 0:
        issues.append('negative_price')
    return issues
