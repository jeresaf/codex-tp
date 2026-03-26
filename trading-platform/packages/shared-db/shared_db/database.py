from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

Base = declarative_base()


def build_engine(url: str):
    return create_engine(url, future=True, pool_pre_ping=True)


def build_session_factory(url: str):
    engine = build_engine(url)
    return sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)
