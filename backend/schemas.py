from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel, EmailStr, Field

# --- Auth Schemas ---

class UserLogin(BaseModel):
    username: str = Field(..., min_length=1, max_length=150)  # register number, or email for the admin
    password: str

class ForgotPasswordRequest(BaseModel):
    username: str = Field(..., min_length=1, max_length=150)  # register number or verified email

class ResetPasswordRequest(BaseModel):
    username: str = Field(..., min_length=1, max_length=150)
    code: str = Field(..., pattern=r"^\d{6}$")
    new_password: str = Field(..., min_length=6, max_length=100)

class SendEmailCodeRequest(BaseModel):
    email: EmailStr

class VerifyEmailRequest(BaseModel):
    code: str = Field(..., pattern=r"^\d{6}$")

class SetPasswordRequest(BaseModel):
    new_password: str = Field(..., min_length=6, max_length=100)

class MessageResponse(BaseModel):
    message: str

class UserResponse(BaseModel):
    id: int
    name: str
    register_number: Optional[str] = None
    email: Optional[str] = None
    email_verified: bool = False
    must_change_password: bool = False
    role: str
    created_at: datetime

    class Config:
        from_attributes = True

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    name: str
    register_number: Optional[str] = None
    email: Optional[str] = None
    email_verified: bool = False
    must_change_password: bool = False
    role: str

class StudentImportItem(BaseModel):
    register_number: str = Field(..., min_length=1, max_length=30)
    name: str = Field(..., min_length=1, max_length=100)

class StudentImportRequest(BaseModel):
    students: List[StudentImportItem]

class StudentImportResponse(BaseModel):
    created: int
    skipped_existing: List[str] = []

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

class AnalysisJobResponse(BaseModel):
    job_id: int
    status: str  # processing | done | failed
    error: Optional[str] = None
    session_id: Optional[int] = None

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
    student_email: Optional[str] = None
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
    activated_students: int = 0
    total_practice_sessions: int
    average_performance: float
    recent_activity: List[AdminActivityItem] = []

class AdminStudentListItem(BaseModel):
    id: int
    name: str
    register_number: Optional[str] = None
    email: Optional[str] = None
    activated: bool  # finished first-login setup (verified email + own password)
    created_at: datetime
    sessions_count: int
    average_score: float
    last_practice_at: Optional[datetime] = None
    skill_averages: dict = {}

class AdminStudentDetailResponse(BaseModel):
    student: UserResponse
    sessions_count: int
    average_score: float
    highest_score: float
    lowest_score: float
    metric_averages: dict
    history: List[PracticeSessionSchema] = []
