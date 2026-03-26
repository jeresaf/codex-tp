def max_position_size_check(quantity: float, threshold: float) -> dict:
    if quantity > threshold:
        return {
            'passed': False,
            'rule_type': 'max_position_size',
            'message': 'Order exceeds configured max position size',
            'severity': 'high',
            'threshold': threshold,
            'measured': quantity,
        }
    return {
        'passed': True,
        'rule_type': 'max_position_size',
        'message': 'Passed',
        'severity': 'info',
        'threshold': threshold,
        'measured': quantity,
    }
