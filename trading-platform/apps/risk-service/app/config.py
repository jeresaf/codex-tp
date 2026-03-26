from shared_config.settings import Settings


class RiskServiceSettings(Settings):
    internal_service_token: str = "internal-dev-token"


settings = RiskServiceSettings(app_name="risk-service", port=8000)
