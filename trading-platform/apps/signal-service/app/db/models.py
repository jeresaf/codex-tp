from sqlalchemy import String, DateTime, JSON, Double, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base


class StrategySignalModel(Base):
    __tablename__ = "strategy_signals"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    strategy_deployment_id: Mapped[str] = mapped_column(String, nullable=False)
    strategy_version_id: Mapped[str] = mapped_column(String, nullable=True)
    instrument_id: Mapped[str] = mapped_column(String, nullable=False)
    signal_type: Mapped[str] = mapped_column(String(50), nullable=False)
    direction: Mapped[str] = mapped_column(String(20), nullable=True)
    strength: Mapped[float] = mapped_column(Double, nullable=True)
    confidence: Mapped[float] = mapped_column(Double, nullable=True)
    time_horizon: Mapped[str] = mapped_column(String(50), nullable=True)
    reason_codes: Mapped[dict] = mapped_column(JSON, nullable=True)
    metadata_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    correlation_id: Mapped[str] = mapped_column(String, nullable=True)
    signal_timestamp: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
