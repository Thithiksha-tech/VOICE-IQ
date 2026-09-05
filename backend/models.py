import datetime
from sqlalchemy import Column, Integer, String, Float, Text, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    email = Column(String(150), unique=True, index=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    role = Column(String(20), default="student", nullable=False)  # "student" or "admin"
    created_at = Column(DateTime, default=datetime.datetime.utcnow, nullable=False)

    # Relationships
    sessions = relationship("PracticeSession", back_populates="student", cascade="all, delete-orphan")


class PracticeSession(Base):
    __tablename__ = "practice_sessions"

    id = Column(Integer, primary_key=True, index=True)
    student_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    prompt = Column(Text, nullable=False)
    audio_path = Column(String(255), nullable=True)
    transcript = Column(Text, nullable=True)
    overall_score = Column(Float, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow, nullable=False, index=True)

    # Relationships
    student = relationship("User", back_populates="sessions")
    analysis = relationship("SpeechAnalysis", back_populates="session", uselist=False, cascade="all, delete-orphan")


class SpeechAnalysis(Base):
    __tablename__ = "speech_analysis"

    id = Column(Integer, primary_key=True, index=True)
    practice_session_id = Column(Integer, ForeignKey("practice_sessions.id", ondelete="CASCADE"), nullable=False, unique=True, index=True)
    fluency_score = Column(Float, nullable=False)
    pronunciation_score = Column(Float, nullable=False)
    grammar_score = Column(Float, nullable=False)
    vocabulary_score = Column(Float, nullable=False)
    confidence_score = Column(Float, nullable=False)
    words_per_minute = Column(Float, nullable=False)
    filler_word_count = Column(Integer, nullable=False, default=0)
    feedback = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow, nullable=False)

    # Relationships
    session = relationship("PracticeSession", back_populates="analysis")
