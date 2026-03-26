from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "service"
    env: str = "local"
    host: str = "0.0.0.0"
    port: int = 8000
    db_host: str = "postgres"
    db_port: int = 5432
    db_name: str = "trading_platform"
    db_user: str = "postgres"
    db_password: str = "postgres"
    jwt_secret: str = "dev-secret"
    jwt_algorithm: str = "HS256"
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @property
    def sqlalchemy_url(self) -> str:
        return f"postgresql+psycopg://{self.db_user}:{self.db_password}@{self.db_host}:{self.db_port}/{self.db_name}"
