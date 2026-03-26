from sqlalchemy.orm import Session
from shared_db.database import build_session_factory
from app.config import settings

SessionLocal = build_session_factory(settings.sqlalchemy_url)


def get_db():
    db: Session = SessionLocal()
    try:
        yield db
    finally:
        db.close()
