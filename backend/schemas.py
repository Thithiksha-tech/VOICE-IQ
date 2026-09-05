from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel, EmailStr, Field

# --- Auth Schemas ---

class UserRegister(BaseModel):
    name: str = Field(..., min_length=2, max_length=100)
    email: EmailStr
    password: str = Field(..., min_length=6, max_length=100)

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class AdminLogin(BaseModel):
    email: EmailStr
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    name: str
    email: str
    role: str

class UserResponse(BaseModel):
    id: int
    name: str
    email: str
    role: str
    created_at: datetime

    class Config:
        from_attributes = True

# --- Analysis & Session Schemas ---

class SpeechAnalysisSchema(BaseModel):
    id: int
    practice_session_id: int
    fluency_score: float
    pronunciation_score: float
    grammar_score: float
    vocabulary_score: float
    confidence_score: float
    words_per_minute: float
    filler_word_count: int
    feedback: str
    created_at: datetime

    class Config:
        from_attributes = True

class PracticeSessionSchema(BaseModel):
    id: int
    student_id: int
    prompt: str
    audio_path: Optional[str] = None
    transcript: Optional[str] = None
    overall_score: Optional[float] = None
    created_at: datetime
    analysis: Optional[SpeechAnalysisSchema] = None

    class Config:
        from_attributes = True

class AudioAnalyzeResponse(BaseModel):
    session_id: int
    prompt: str
    transcript: str
    overall_score: float
    analysis: SpeechAnalysisSchema

# --- Dashboard Schemas ---

class StudentDashboardResponse(BaseModel):
    student_id: int
    student_name: str
    student_email: str
    overall_performance: float
    practice_sessions_count: int
    recent_score: Optional[float] = None
    recent_sessions: List[PracticeSessionSchema] = []

class AdminActivityItem(BaseModel):
    session_id: int
    student_id: int
    student_name: str
    prompt: str
    overall_score: float
    created_at: datetime

class AdminDashboardResponse(BaseModel):
    total_students: int
    total_practice_sessions: int
    average_performance: float
    recent_activity: List[AdminActivityItem] = []

class AdminStudentListItem(BaseModel):
    id: int
    name: str
    email: str
    created_at: datetime
    sessions_count: int
    average_score: float

class AdminStudentDetailResponse(BaseModel):
    student: UserResponse
    sessions_count: int
    average_score: float
    highest_score: float
    lowest_score: float
    metric_averages: dict
    history: List[PracticeSessionSchema] = []
