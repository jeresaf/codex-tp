from sqlalchemy import String, DateTime, JSON, Integer, Numeric, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base


class RiskEvaluationModel(Base):
    __tablename__ = 'risk_evaluations'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    order_intent_id: Mapped[str] = mapped_column(String, nullable=False)
    decision: Mapped[str] = mapped_column(String(20), nullable=False)
    next_state: Mapped[str] = mapped_column(String(50), nullable=False)
    rule_results: Mapped[dict] = mapped_column(JSON, nullable=False)
    evaluated_by_service: Mapped[str] = mapped_column(String(100), nullable=False)
    correlation_id: Mapped[str] = mapped_column(String, nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())


class RiskBreachModel(Base):
    __tablename__ = 'risk_breaches'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    risk_policy_id: Mapped[str] = mapped_column(String, nullable=False)
    scope_type: Mapped[str] = mapped_column(String(50), nullable=False)
    scope_id: Mapped[str] = mapped_column(String, nullable=False)
    breach_type: Mapped[str] = mapped_column(String(100), nullable=False)
    severity: Mapped[str] = mapped_column(String(20), nullable=False)
    measured_value: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    threshold_value: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    details_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    action_taken: Mapped[str] = mapped_column(String(100), nullable=True)
    status: Mapped[str] = mapped_column(String(50), nullable=False, default='open')
    correlation_id: Mapped[str] = mapped_column(String, nullable=True)
    detected_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    resolved_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())


class KillSwitchModel(Base):
    __tablename__ = 'kill_switches'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    scope_type: Mapped[str] = mapped_column(String(50), nullable=False)
    scope_id: Mapped[str] = mapped_column(String, nullable=True)
    switch_action: Mapped[str] = mapped_column(String(100), nullable=False)
    reason: Mapped[str] = mapped_column(String, nullable=True)
    triggered_by_actor_type: Mapped[str] = mapped_column(String(50), nullable=False)
    triggered_by_actor_id: Mapped[str] = mapped_column(String, nullable=True)
    status: Mapped[str] = mapped_column(String(50), nullable=False, default='active')
    correlation_id: Mapped[str] = mapped_column(String, nullable=True)
    triggered_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    released_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())


class RiskExposureSnapshotModel(Base):
    __tablename__ = 'risk_exposure_snapshots'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    scope_type: Mapped[str] = mapped_column(String(50), nullable=False)
    scope_id: Mapped[str] = mapped_column(String, nullable=False)
    exposure_type: Mapped[str] = mapped_column(String(100), nullable=False)
    instrument_id: Mapped[str] = mapped_column(String, nullable=True)
    currency_code: Mapped[str] = mapped_column(String(20), nullable=True)
    gross_exposure: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    net_exposure: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    notional_value: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    leverage_value: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    margin_used: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    unrealized_pnl: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    realized_pnl: Mapped[float] = mapped_column(Numeric(24,10), nullable=True)
    snapshot_time: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())


class DrawdownTrackerModel(Base):
    __tablename__ = 'drawdown_trackers'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    scope_type: Mapped[str] = mapped_column(String(50), nullable=False)
    scope_id: Mapped[str] = mapped_column(String, nullable=False)
    equity_high_watermark: Mapped[float] = mapped_column(Numeric(24,10), nullable=False)
    current_equity: Mapped[float] = mapped_column(Numeric(24,10), nullable=False)
    drawdown_amount: Mapped[float] = mapped_column(Numeric(24,10), nullable=False)
    drawdown_percent: Mapped[float] = mapped_column(Numeric(12,6), nullable=False)
    snapshot_time: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
