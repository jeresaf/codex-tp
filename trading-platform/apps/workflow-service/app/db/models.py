from sqlalchemy import String, DateTime, JSON, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base

class WorkflowModel(Base):
    __tablename__ = 'workflows'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    workflow_code: Mapped[str] = mapped_column(String(100), nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str] = mapped_column(String, nullable=True)
    scope_type: Mapped[str] = mapped_column(String(50), nullable=False)
    definition_json: Mapped[dict] = mapped_column(JSON, nullable=False)
    enabled: Mapped[bool] = mapped_column()
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())

class WorkflowRunModel(Base):
    __tablename__ = 'workflow_runs'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    workflow_id: Mapped[str] = mapped_column(String, nullable=False)
    status: Mapped[str] = mapped_column(String(50), nullable=False)
    subject_type: Mapped[str] = mapped_column(String(50), nullable=False)
    subject_id: Mapped[str] = mapped_column(String, nullable=False)
    context_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    started_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    completed_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())

class WorkflowTaskModel(Base):
    __tablename__ = 'workflow_tasks'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    workflow_run_id: Mapped[str] = mapped_column(String, nullable=False)
    task_type: Mapped[str] = mapped_column(String(100), nullable=False)
    assignee_type: Mapped[str] = mapped_column(String(50), nullable=True)
    assignee_id: Mapped[str] = mapped_column(String, nullable=True)
    status: Mapped[str] = mapped_column(String(50), nullable=False)
    input_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    output_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    due_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
    completed_at: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
