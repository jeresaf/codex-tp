from sqlalchemy import String, DateTime, JSON, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base

class DatasetVersionModel(Base):
    __tablename__ = 'dataset_versions'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    dataset_code: Mapped[str] = mapped_column(String(100), nullable=False)
    dataset_version: Mapped[str] = mapped_column(String(50), nullable=False)
    manifest_json: Mapped[dict] = mapped_column(JSON, nullable=False)
    storage_uri: Mapped[str] = mapped_column(String, nullable=True)
    checksum: Mapped[str] = mapped_column(String(255), nullable=True)
    created_by: Mapped[str] = mapped_column(String, nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
