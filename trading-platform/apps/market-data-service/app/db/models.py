from sqlalchemy import String, DateTime, JSON, Numeric, Integer, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base

class RawMarketEventModel(Base):
    __tablename__ = 'raw_market_events'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    provider_code: Mapped[str] = mapped_column(String(100), nullable=False)
    event_type: Mapped[str] = mapped_column(String(50), nullable=False)
    external_symbol: Mapped[str] = mapped_column(String(100), nullable=True)
    payload_json: Mapped[dict] = mapped_column(JSON, nullable=False)
    event_time: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
    arrival_time: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    checksum: Mapped[str] = mapped_column(String(255), nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())

class NormalizedCandleModel(Base):
    __tablename__ = 'normalized_candles'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    instrument_id: Mapped[str] = mapped_column(String, nullable=False)
    timeframe: Mapped[str] = mapped_column(String(20), nullable=False)
    open_time: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    close_time: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    open: Mapped[float] = mapped_column(Numeric(24,10), nullable=False)
    high: Mapped[float] = mapped_column(Numeric(24,10), nullable=False)
    low: Mapped[float] = mapped_column(Numeric(24,10), nullable=False)
    close: Mapped[float] = mapped_column(Numeric(24,10), nullable=False)
    volume: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    source: Mapped[str] = mapped_column(String(100), nullable=False)
    quality_flag: Mapped[str] = mapped_column(String(20), nullable=False, default='ok')
    arrival_time: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())

class OutboxEventModel(Base):
    __tablename__ = 'outbox_events'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    aggregate_type: Mapped[str] = mapped_column(String(100), nullable=False)
    aggregate_id: Mapped[str] = mapped_column(String, nullable=False)
    event_type: Mapped[str] = mapped_column(String(150), nullable=False)
    event_version: Mapped[int] = mapped_column(Integer, nullable=False)
    correlation_id: Mapped[str] = mapped_column(String, nullable=True)
    causation_id: Mapped[str] = mapped_column(String, nullable=True)
    payload_json: Mapped[dict] = mapped_column(JSON, nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default='pending')
    retry_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    next_attempt_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    published_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
    last_error: Mapped[str] = mapped_column(String, nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
