from sqlalchemy import String, Numeric, DateTime, Integer, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base


class PositionModel(Base):
    __tablename__ = "positions"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    account_id: Mapped[str] = mapped_column(String, nullable=True)
    instrument_id: Mapped[str] = mapped_column(String, nullable=False)
    net_quantity: Mapped[float] = mapped_column(Numeric(24, 10), nullable=False, default=0)
    avg_price: Mapped[float] = mapped_column(Numeric(24, 10), nullable=False, default=0)
    market_value: Mapped[float] = mapped_column(Numeric(24, 10), nullable=False, default=0)
    unrealized_pnl: Mapped[float] = mapped_column(Numeric(24, 10), nullable=False, default=0)
    realized_pnl: Mapped[float] = mapped_column(Numeric(24, 10), nullable=False, default=0)
    updated_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class ProcessedEventModel(Base):
    __tablename__ = "processed_events"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    consumer_service: Mapped[str] = mapped_column(String(100), nullable=False)
    event_id: Mapped[str] = mapped_column(String, nullable=False)
    event_type: Mapped[str] = mapped_column(String(150), nullable=False)
    processed_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
