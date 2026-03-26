import uuid
from shared_features.registry.feature_registry import FEATURE_REGISTRY
from app.db.models import FeatureValueModel


def backfill_features(db, candles: list[dict], feature_codes: list[str]) -> dict:
    grouped = {}
    for c in sorted(candles, key=lambda x: x['close_time']):
        grouped.setdefault(c['instrument_id'], []).append(float(c['close']))
    written = 0
    for instrument_id, closes in grouped.items():
        for feature_code in feature_codes:
            meta = FEATURE_REGISTRY[feature_code]
            value = meta['fn'](closes)
            if value is None:
                continue
            row = FeatureValueModel(
                id=str(uuid.uuid4()),
                feature_code=feature_code,
                instrument_id=instrument_id,
                timeframe=meta['timeframe'],
                value_time=candles[-1]['close_time'],
                value_double=value,
                value_json=None,
                quality_flag='ok',
                source_run_id=None,
            )
            db.add(row)
            written += 1
    db.commit()
    return {'written': written}
