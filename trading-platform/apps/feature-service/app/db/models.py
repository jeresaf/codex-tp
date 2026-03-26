from sqlalchemy import String, DateTime, JSON, Integer, Double, func
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base

class FeatureDefinitionModel(Base):
    __tablename__ = 'feature_definitions'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    feature_code: Mapped[str] = mapped_column(String(100), nullable=False, unique=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str] = mapped_column(String, nullable=True)
    timeframe: Mapped[str] = mapped_column(String(20), nullable=False)
    formula_ref: Mapped[str] = mapped_column(String(255), nullable=True)
    implementation_version: Mapped[str] = mapped_column(String(50), nullable=False)
    required_warmup: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    null_handling: Mapped[str] = mapped_column(String(50), nullable=False, default='propagate')
    dependencies_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    output_schema_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())

class FeatureValueModel(Base):
    __tablename__ = 'feature_values'
    id: Mapped[str] = mapped_column(String, primary_key=True)
    feature_code: Mapped[str] = mapped_column(String(100), nullable=False)
    instrument_id: Mapped[str] = mapped_column(String, nullable=False)
    timeframe: Mapped[str] = mapped_column(String(20), nullable=False)
    value_time: Mapped[str] = mapped_column(DateTime(timezone=True), nullable=False)
    value_double: Mapped[float] = mapped_column(Double, nullable=True)
    value_json: Mapped[dict] = mapped_column(JSON, nullable=True)
    quality_flag: Mapped[str] = mapped_column(String(20), nullable=False, default='ok')
    source_run_id: Mapped[str] = mapped_column(String, nullable=True)
    created_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
