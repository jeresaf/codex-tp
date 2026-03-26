from shared_config.settings import Settings


class StrategyRuntimeSettings(Settings):
    internal_service_token: str = "internal-dev-token"


settings = StrategyRuntimeSettings(app_name="strategy-runtime-service", port=8000)
