from dataclasses import dataclass, field
from typing import Any


@dataclass
class StrategySignal:
    signal_id: str
    strategy_deployment_id: str
    strategy_version_id: str | None
    instrument_id: str
    timestamp: str
    signal_type: str
    direction: str
    strength: float
    confidence: float
    time_horizon: str
    reason_codes: list[str] = field(default_factory=list)
    metadata: dict[str, Any] = field(default_factory=dict)


class BaseStrategy:
    strategy_code: str = "base"
    version: str = "0.1.0"
    supported_markets: list[str] = []
    supported_asset_classes: list[str] = []
    supported_timeframes: list[str] = []
    required_features: list[str] = []
    warmup_period: int = 0

    def on_candle(self, candle: dict, context: dict) -> list[StrategySignal]:
        raise NotImplementedError
