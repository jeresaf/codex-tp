from sqlalchemy import String, Numeric, Integer
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base

class Instrument(Base):
    __tablename__ = "instruments"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    venue_id: Mapped[str] = mapped_column(String, nullable=False)
    canonical_symbol: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    external_symbol: Mapped[str] = mapped_column(String(100), nullable=True)
    asset_class: Mapped[str] = mapped_column(String(50), nullable=False)
    base_asset: Mapped[str] = mapped_column(String(50), nullable=True)
    quote_asset: Mapped[str] = mapped_column(String(50), nullable=True)
    tick_size: Mapped[float] = mapped_column(Numeric(24, 10), nullable=False)
    lot_size: Mapped[float] = mapped_column(Numeric(24, 10), nullable=False)
    price_precision: Mapped[int] = mapped_column(Integer, nullable=False)
    quantity_precision: Mapped[int] = mapped_column(Integer, nullable=False)
    contract_multiplier: Mapped[float] = mapped_column(Numeric(24, 10), nullable=True)
    status: Mapped[str] = mapped_column(String(50), nullable=False, default="active")
