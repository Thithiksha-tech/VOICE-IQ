from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import desc
from database import get_db
import models
import schemas
import auth

router = APIRouter(prefix="/api/admin", tags=["Administrator Dashboard"])

@router.get("/dashboard", response_model=schemas.AdminDashboardResponse)
def get_admin_dashboard(
    admin: models.User = Depends(auth.get_current_admin),
    db: Session = Depends(get_db)
):
    """Calculates high-level educational metrics for the entire institute."""
    students = db.query(models.User).filter(models.User.role == "student").all()
    sessions = db.query(models.PracticeSession).order_by(desc(models.PracticeSession.created_at)).all()

    total_students = len(students)
    total_sessions = len(sessions)

    avg_performance = (
        round(sum(s.overall_score for s in sessions if s.overall_score is not None) / total_sessions, 1)
        if total_sessions > 0 else 0.0
    )

    recent_activity = []
    for s in sessions[:10]:
        student_name = s.student.name if s.student else f"Student #{s.student_id}"
        recent_activity.append(
            schemas.AdminActivityItem(
                session_id=s.id,
                student_id=s.student_id,
                student_name=student_name,
                prompt=s.prompt,
                overall_score=s.overall_score or 0.0,
                created_at=s.created_at
            )
        )

    return schemas.AdminDashboardResponse(
        total_students=total_students,
        total_practice_sessions=total_sessions,
        average_performance=avg_performance,
        recent_activity=recent_activity
    )

@router.get("/students", response_model=List[schemas.AdminStudentListItem])
def list_all_students(
    admin: models.User = Depends(auth.get_current_admin),
    db: Session = Depends(get_db)
):
    """Returns roster of all enrolled students with aggregate performance statistics."""
    students = db.query(models.User).filter(models.User.role == "student").order_by(models.User.name).all()

    result = []
    for st in students:
        st_sessions = st.sessions
        sess_count = len(st_sessions)
        avg_score = (
            round(sum(s.overall_score for s in st_sessions if s.overall_score is not None) / sess_count, 1)
            if sess_count > 0 else 0.0
        )
        result.append(
            schemas.AdminStudentListItem(
                id=st.id,
                name=st.name,
                email=st.email,
                created_at=st.created_at,
                sessions_count=sess_count,
                average_score=avg_score
            )
        )
    return result

@router.get("/students/{student_id}", response_model=schemas.AdminStudentDetailResponse)
def get_student_detail_for_admin(
    student_id: int,
    admin: models.User = Depends(auth.get_current_admin),
    db: Session = Depends(get_db)
):
    """Provides complete diagnostic drill-down for a selected student."""
    student = db.query(models.User).filter(models.User.id == student_id, models.User.role == "student").first()
    if not student:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student account not found."
        )

    sessions = (
        db.query(models.PracticeSession)
        .filter(models.PracticeSession.student_id == student_id)
        .order_by(desc(models.PracticeSession.created_at))
        .all()
    )

    scores = [s.overall_score for s in sessions if s.overall_score is not None]
    sessions_count = len(sessions)
    average_score = round(sum(scores) / len(scores), 1) if scores else 0.0
    highest_score = max(scores) if scores else 0.0
    lowest_score = min(scores) if scores else 0.0

    # Calculate metric averages from speech_analysis records
    analyses = [s.analysis for s in sessions if s.analysis is not None]
    if analyses:
        metric_averages = {
            "fluency": round(sum(a.fluency_score for a in analyses) / len(analyses), 1),
            "pronunciation": round(sum(a.pronunciation_score for a in analyses) / len(analyses), 1),
            "grammar": round(sum(a.grammar_score for a in analyses) / len(analyses), 1),
            "vocabulary": round(sum(a.vocabulary_score for a in analyses) / len(analyses), 1),
            "confidence": round(sum(a.confidence_score for a in analyses) / len(analyses), 1),
            "words_per_minute": round(sum(a.words_per_minute for a in analyses) / len(analyses), 1),
            "average_fillers": round(sum(a.filler_word_count for a in analyses) / len(analyses), 1),
        }
    else:
        metric_averages = {
            "fluency": 0.0, "pronunciation": 0.0, "grammar": 0.0,
            "vocabulary": 0.0, "confidence": 0.0, "words_per_minute": 0.0, "average_fillers": 0.0
        }

    return schemas.AdminStudentDetailResponse(
        student=schemas.UserResponse.from_orm(student),
        sessions_count=sessions_count,
        average_score=average_score,
        highest_score=highest_score,
        lowest_score=lowest_score,
        metric_averages=metric_averages,
        history=sessions
    )

@router.get("/students/{student_id}/history", response_model=List[schemas.PracticeSessionSchema])
def get_student_history_for_admin(
    student_id: int,
    admin: models.User = Depends(auth.get_current_admin),
    db: Session = Depends(get_db)
):
    """Retrieves full practice history for a specific student for administrative audit."""
    sessions = (
        db.query(models.PracticeSession)
        .filter(models.PracticeSession.student_id == student_id)
        .order_by(desc(models.PracticeSession.created_at))
        .all()
    )
    return sessions
