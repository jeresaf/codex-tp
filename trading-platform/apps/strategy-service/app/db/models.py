from sqlalchemy import String, Text, DateTime, JSON, Numeric, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base


class Strategy(Base):
    __tablename__ = "strategies"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    code: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    type: Mapped[str] = mapped_column(String(100), nullable=False)
    owner_user_id: Mapped[str] = mapped_column(String, nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(50), nullable=False, default="draft")
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class StrategyDeployment(Base):
    __tablename__ = "strategy_deployments"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    strategy_version_id: Mapped[str] = mapped_column(String, nullable=False)
    environment: Mapped[str] = mapped_column(String(50), nullable=False)
    account_id: Mapped[str] = mapped_column(String, nullable=True)
    status: Mapped[str] = mapped_column(String(50), nullable=False, default="stopped")
    capital_allocation_rule: Mapped[dict] = mapped_column(JSON, nullable=True)
    market_scope_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    deployment_status: Mapped[str] = mapped_column(String(50), nullable=False, default="draft")
    runtime_mode: Mapped[str] = mapped_column(String(20), nullable=False, default="paper")
    capital_budget: Mapped[float] = mapped_column(Numeric(24, 10), nullable=True)
    instrument_scope_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    started_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
    stopped_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
