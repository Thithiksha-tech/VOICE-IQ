import os
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv

load_dotenv()

# Database URL defaults to SQLite. For PostgreSQL/Supabase, set DATABASE_URL=postgresql://...
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./voiceiq.db")

# SQLite needs check_same_thread=False for multi-threaded FastAPI requests
connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}

engine = create_engine(
    DATABASE_URL,
    connect_args=connect_args,
    echo=False
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db():
    """Dependency that provides a database session and closes it when done."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
