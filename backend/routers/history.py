from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import desc
from database import get_db
import models
import schemas
import auth

router = APIRouter(prefix="/api/history", tags=["Practice History"])

@router.get("/dashboard/me", response_model=schemas.StudentDashboardResponse)
def get_student_dashboard(
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(get_db)
):
    """Returns summarized stats and recent sessions for the logged-in student."""
    sessions = (
        db.query(models.PracticeSession)
        .filter(models.PracticeSession.student_id == current_user.id)
        .order_by(desc(models.PracticeSession.created_at))
        .all()
    )

    count = len(sessions)
    recent_score = sessions[0].overall_score if count > 0 else None
    overall_performance = (
        round(sum(s.overall_score for s in sessions if s.overall_score is not None) / count, 1)
        if count > 0 else 0.0
    )

    return schemas.StudentDashboardResponse(
        student_id=current_user.id,
        student_name=current_user.name,
        student_email=current_user.email,
        overall_performance=overall_performance,
        practice_sessions_count=count,
        recent_score=recent_score,
        recent_sessions=sessions[:5]
    )

@router.get("/student/{student_id}", response_model=List[schemas.PracticeSessionSchema])
def get_student_history(
    student_id: int,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(get_db)
):
    """
    Returns full practice history for a student.
    Enforces authorization: A student can only view their own history.
    Admins can view any student's history.
    """
    if current_user.role != "admin" and current_user.id != student_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access forbidden: You cannot view another student's practice history."
        )

    sessions = (
        db.query(models.PracticeSession)
        .filter(models.PracticeSession.student_id == student_id)
        .order_by(desc(models.PracticeSession.created_at))
        .all()
    )
    return sessions

@router.get("/{session_id}", response_model=schemas.PracticeSessionSchema)
def get_session_detail(
    session_id: int,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(get_db)
):
    """Returns full details and breakdown of a specific practice session."""
    session = db.query(models.PracticeSession).filter(models.PracticeSession.id == session_id).first()
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Practice session not found."
        )

    if current_user.role != "admin" and current_user.id != session.student_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access forbidden: You are not authorized to view this session."
        )

    return session
