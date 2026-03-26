from sqlalchemy import String, DateTime, JSON, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base

class ComplianceExportModel(Base):
    __tablename__ = 'compliance_exports'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    export_type: Mapped[str] = mapped_column(String(100), nullable=False)
    scope_type: Mapped[str] = mapped_column(String(50), nullable=True)
    scope_id: Mapped[str] = mapped_column(String, nullable=True)
    format: Mapped[str] = mapped_column(String(20), nullable=False)
    status: Mapped[str] = mapped_column(String(50), nullable=False)
    request_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    result_uri: Mapped[str] = mapped_column(String, nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
    completed_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
