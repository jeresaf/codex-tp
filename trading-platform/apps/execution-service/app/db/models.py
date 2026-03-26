from sqlalchemy import String, Numeric, DateTime, JSON, Integer, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base

class BrokerOrderModel(Base):
    __tablename__ = 'broker_orders'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    order_intent_id: Mapped[str] = mapped_column(String, nullable=False)
    venue_id: Mapped[str] = mapped_column(String, nullable=False)
    external_order_id: Mapped[str] = mapped_column(String(255), nullable=True)
    broker_status: Mapped[str] = mapped_column(String(50), nullable=False)
    raw_request: Mapped[dict] = mapped_column(JSON, nullable=True)
    raw_response: Mapped[dict] = mapped_column(JSON, nullable=True)
    correlation_id: Mapped[str] = mapped_column(String, nullable=True)
    submitted_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
    acknowledged_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)

class FillModel(Base):
    __tablename__ = 'fills'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    broker_order_id: Mapped[str] = mapped_column(String, nullable=False)
    instrument_id: Mapped[str] = mapped_column(String, nullable=False)
    fill_price: Mapped[float] = mapped_column(Numeric(24,10), nullable=False)
    fill_quantity: Mapped[float] = mapped_column(Numeric(24,10), nullable=False)
    fee_amount: Mapped[float] = mapped_column(Numeric(24,10), nullable=False, default=0)
    fee_currency: Mapped[str] = mapped_column(String(20), nullable=True)
    correlation_id: Mapped[str] = mapped_column(String, nullable=True)
    fill_time: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
    raw_payload: Mapped[dict] = mapped_column(JSON, nullable=True)

class BrokerOrderStateHistoryModel(Base):
    __tablename__ = 'broker_order_state_history'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    broker_order_id: Mapped[str] = mapped_column(String, nullable=False)
    from_state: Mapped[str] = mapped_column(String(50), nullable=True)
    to_state: Mapped[str] = mapped_column(String(50), nullable=False)
    transition_reason: Mapped[str] = mapped_column(String(255), nullable=True)
    metadata_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())

class ExecutionQualityMetricModel(Base):
    __tablename__ = 'execution_quality_metrics'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    broker_order_id: Mapped[str] = mapped_column(String, nullable=False)
    order_intent_id: Mapped[str] = mapped_column(String, nullable=False)
    strategy_deployment_id: Mapped[str] = mapped_column(String, nullable=True)
    instrument_id: Mapped[str] = mapped_column(String, nullable=False)
    venue_id: Mapped[str] = mapped_column(String, nullable=False)
    intended_price: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    submitted_price: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    avg_fill_price: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    slippage_amount: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    slippage_bps: Mapped[float] = mapped_column(Numeric(12,6), nullable=True)
    total_fee_amount: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    fee_currency: Mapped[str] = mapped_column(String(20), nullable=True)
    ack_latency_ms: Mapped[int] = mapped_column(Integer, nullable=True)
    full_fill_latency_ms: Mapped[int] = mapped_column(Integer, nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
