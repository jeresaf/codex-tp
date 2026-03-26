import uuid
from datetime import datetime, timezone
from strategy_sdk.contracts import BaseStrategy, StrategySignal


class MovingAverageCrossSampleStrategy(BaseStrategy):
    strategy_code = "fx_ma_cross"
    version = "0.1.0"
    supported_markets = ["forex"]
    supported_asset_classes = ["forex"]
    supported_timeframes = ["1m"]
    required_features = []
    warmup_period = 1

    def on_candle(self, candle: dict, context: dict) -> list[StrategySignal]:
        if candle.get("close") is None:
            return []
        direction = "long" if float(candle["close"]) >= float(candle["open"]) else "short"
        return [
            StrategySignal(
                signal_id=str(uuid.uuid4()),
                strategy_deployment_id=context["strategy_deployment_id"],
                strategy_version_id=context.get("strategy_version_id"),
                instrument_id=candle["instrument_id"],
                timestamp=datetime.now(timezone.utc).isoformat(),
                signal_type="directional",
                direction=direction,
                strength=0.8,
                confidence=0.75,
                time_horizon="short_term",
                reason_codes=["demo_candle_direction"],
                metadata={"open": candle["open"], "close": candle["close"]},
            )
        ]
