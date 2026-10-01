import os
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import desc, func
from database import get_db
import models
import schemas
import auth

router = APIRouter(prefix="/api/admin", tags=["Administrator Dashboard"])

# Default password for imported students: prefix + last N digits of the register number
# (e.g. 714024104189 -> cse@189). Set DEFAULT_PASSWORD_DIGITS=0 to use the full number.
DEFAULT_PASSWORD_PREFIX = os.getenv("DEFAULT_PASSWORD_PREFIX", "cse@")
DEFAULT_PASSWORD_DIGITS = int(os.getenv("DEFAULT_PASSWORD_DIGITS", "3"))


def default_password(register_number: str) -> str:
    suffix = register_number[-DEFAULT_PASSWORD_DIGITS:] if DEFAULT_PASSWORD_DIGITS > 0 else register_number
    return f"{DEFAULT_PASSWORD_PREFIX}{suffix}"


def skill_averages(sessions) -> dict:
    analyses = [s.analysis for s in sessions if s.analysis is not None]
    if not analyses:
        return {"fluency": 0.0, "pronunciation": 0.0, "grammar": 0.0, "vocabulary": 0.0, "confidence": 0.0}
    n = len(analyses)
    return {
        "fluency": round(sum(a.fluency_score for a in analyses) / n, 1),
        "pronunciation": round(sum(a.pronunciation_score for a in analyses) / n, 1),
        "grammar": round(sum(a.grammar_score for a in analyses) / n, 1),
        "vocabulary": round(sum(a.vocabulary_score for a in analyses) / n, 1),
        "confidence": round(sum(a.confidence_score for a in analyses) / n, 1),
    }


@router.post("/students/import", response_model=schemas.StudentImportResponse)
def import_students(
    data: schemas.StudentImportRequest,
    admin: models.User = Depends(auth.get_current_admin),
    db: Session = Depends(get_db)
):
    """Creates student accounts from register numbers and names. Existing register numbers are skipped."""
    created, skipped = 0, []
    seen = set()  # also catches the same register number repeated within one list
    for item in data.students:
        reg_no = item.register_number.strip().upper()
        exists = db.query(models.User).filter(func.upper(models.User.register_number) == reg_no).first()
        if exists or reg_no in seen:
            skipped.append(reg_no)
            continue
        seen.add(reg_no)
        db.add(models.User(
            name=item.name.strip(),
            register_number=reg_no,
            password_hash=auth.get_password_hash(default_password(reg_no)),
            must_change_password=True,
            role="student",
        ))
        created += 1
    db.commit()
    return schemas.StudentImportResponse(created=created, skipped_existing=skipped)


@router.post("/students/{student_id}/reset-password", response_model=schemas.MessageResponse)
def reset_student_password(
    student_id: int,
    admin: models.User = Depends(auth.get_current_admin),
    db: Session = Depends(get_db)
):
    """Resets a student to the default password; they set a new one at next sign-in."""
    student = db.query(models.User).filter(models.User.id == student_id, models.User.role == "student").first()
    if not student or not student.register_number:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student account not found.")
    student.password_hash = auth.get_password_hash(default_password(student.register_number))
    student.must_change_password = True
    db.commit()
    return schemas.MessageResponse(
        message=f"{student.name}'s password was reset to the default: {default_password(student.register_number)}"
    )

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
        activated_students=sum(1 for st in students if st.email_verified and not st.must_change_password),
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
    students = (
        db.query(models.User)
        .filter(models.User.role == "student")
        .order_by(models.User.register_number, models.User.name)
        .all()
    )

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
                register_number=st.register_number,
                email=st.email,
                activated=st.email_verified and not st.must_change_password,
                created_at=st.created_at,
                sessions_count=sess_count,
                average_score=avg_score,
                last_practice_at=max((s.created_at for s in st_sessions), default=None),
                skill_averages=skill_averages(st_sessions),
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
