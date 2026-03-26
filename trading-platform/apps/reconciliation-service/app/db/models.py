from sqlalchemy import String, DateTime, JSON, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base

class ReconciliationRunModel(Base):
    __tablename__ = 'reconciliation_runs'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    run_type: Mapped[str] = mapped_column(String(50), nullable=False)
    account_id: Mapped[str] = mapped_column(String, nullable=True)
    venue_id: Mapped[str] = mapped_column(String, nullable=True)
    status: Mapped[str] = mapped_column(String(50), nullable=False, default='running')
    summary_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    started_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    completed_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())

class ReconciliationIssueModel(Base):
    __tablename__ = 'reconciliation_issues'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    reconciliation_run_id: Mapped[str] = mapped_column(String, nullable=True)
    issue_type: Mapped[str] = mapped_column(String(100), nullable=False)
    account_id: Mapped[str] = mapped_column(String, nullable=True)
    venue_id: Mapped[str] = mapped_column(String, nullable=True)
    severity: Mapped[str] = mapped_column(String(20), nullable=False)
    internal_ref: Mapped[str] = mapped_column(String(255), nullable=True)
    external_ref: Mapped[str] = mapped_column(String(255), nullable=True)
    difference_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    recommended_action: Mapped[str] = mapped_column(String(100), nullable=True)
    status: Mapped[str] = mapped_column(String(50), nullable=False, default='open')
    correlation_id: Mapped[str] = mapped_column(String, nullable=True)
    detected_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    resolved_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
