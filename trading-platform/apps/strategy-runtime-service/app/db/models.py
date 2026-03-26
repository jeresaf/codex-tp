from sqlalchemy import String, DateTime, JSON, Integer, Double, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base


class StrategyRuntimeHeartbeatModel(Base):
    __tablename__ = "strategy_runtime_heartbeats"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    strategy_deployment_id: Mapped[str] = mapped_column(String, nullable=False)
    strategy_version_id: Mapped[str] = mapped_column(String, nullable=True)
    worker_id: Mapped[str] = mapped_column(String, nullable=False)
    status: Mapped[str] = mapped_column(String(50), nullable=False)
    last_processed_event_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
    correlation_id: Mapped[str] = mapped_column(String, nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())


class OutboxEventModel(Base):
    __tablename__ = "outbox_events"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    aggregate_type: Mapped[str] = mapped_column(String(100), nullable=False)
    aggregate_id: Mapped[str] = mapped_column(String, nullable=False)
    event_type: Mapped[str] = mapped_column(String(150), nullable=False)
    event_version: Mapped[int] = mapped_column(Integer, nullable=False)
    correlation_id: Mapped[str] = mapped_column(String, nullable=True)
    causation_id: Mapped[str] = mapped_column(String, nullable=True)
    payload_json: Mapped[dict] = mapped_column(JSON, nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="pending")
    retry_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    next_attempt_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    published_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
    last_error: Mapped[str] = mapped_column(String, nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
