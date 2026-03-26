from shared_config.settings import Settings


class OrderServiceSettings(Settings):
    risk_service_url: str = "http://risk-service:8000"
    execution_service_url: str = "http://execution-service:8000"
    position_service_url: str = "http://position-service:8000"
    audit_service_url: str = "http://audit-service:8000"
    internal_service_token: str = "internal-dev-token"


settings = OrderServiceSettings(app_name="order-service", port=8000)
