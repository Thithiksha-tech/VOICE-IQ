import os
import time
import shutil
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, UploadFile, File, Form, status
from sqlalchemy.orm import Session
from database import get_db, SessionLocal
import models
import schemas
import auth
from services.analysis_service import analysis_service

router = APIRouter(prefix="/api/audio", tags=["Audio & Speech Analysis"])

UPLOAD_DIR = os.getenv("UPLOAD_DIR", "./data/uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

ALLOWED_EXTS = [".wav", ".m4a", ".mp3", ".aac", ".webm", ".ogg", ".mp4", ".3gp"]
AI_BUSY_MESSAGE = "The AI service is busy right now. Please try again in a minute."


async def save_upload(audio: UploadFile, user_id: int) -> str:
    """Stores the uploaded recording and returns its path."""
    file_ext = os.path.splitext(audio.filename)[1].lower() if audio.filename else ".wav"
    if file_ext not in ALLOWED_EXTS:
        file_ext = ".wav"
    file_path = os.path.join(UPLOAD_DIR, f"user_{user_id}_{int(time.time() * 1000)}{file_ext}")
    try:
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(audio.file, buffer)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to write audio recording to disk: {str(e)}"
        )
    finally:
        await audio.close()
    return file_path


def remove_file(path: str) -> None:
    try:
        os.remove(path)
    except OSError:
        pass


def save_session(db: Session, student_id: int, prompt: str, file_path: str, data: dict) -> models.PracticeSession:
    """Persists a finished analysis as a practice session."""
    session = models.PracticeSession(
        student_id=student_id,
        prompt=prompt.strip(),
        audio_path=file_path,
        transcript=data["transcript"],
        overall_score=data["overall_score"],
    )
    db.add(session)
    db.flush()
    db.add(models.SpeechAnalysis(
        practice_session_id=session.id,
        fluency_score=data["fluency_score"],
        pronunciation_score=data["pronunciation_score"],
        grammar_score=data["grammar_score"],
        vocabulary_score=data["vocabulary_score"],
        confidence_score=data["confidence_score"],
        words_per_minute=data["words_per_minute"],
        filler_word_count=data["filler_word_count"],
        feedback=data["feedback"],
    ))
    db.commit()
    db.refresh(session)
    return session


def require_prompt(prompt: str) -> None:
    if not prompt or not prompt.strip():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Speaking prompt is required.")


@router.post("/analyze", response_model=schemas.AudioAnalyzeResponse)
async def analyze_audio_session(
    prompt: str = Form(...),
    duration: float = Form(30.0),
    audio: UploadFile = File(...),
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(get_db)
):
    """Analyzes a recording and waits for the result (used by older app versions)."""
    require_prompt(prompt)
    file_path = await save_upload(audio, current_user.id)
    try:
        data = await analysis_service.analyze_recording(file_path, prompt, duration)
    except ValueError as e:
        remove_file(file_path)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        print(f"[Analysis Error] {e}")
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=AI_BUSY_MESSAGE)

    session = save_session(db, current_user.id, prompt, file_path, data)
    return schemas.AudioAnalyzeResponse(
        session_id=session.id,
        prompt=session.prompt,
        transcript=session.transcript,
        overall_score=session.overall_score,
        analysis=schemas.SpeechAnalysisSchema.from_orm(session.analysis),
    )


async def run_analysis_job(job_id: int, student_id: int, prompt: str, file_path: str, duration: float) -> None:
    """Background worker: analyzes the recording and records the outcome on the job."""
    db = SessionLocal()
    try:
        job = db.query(models.AnalysisJob).filter(models.AnalysisJob.id == job_id).first()
        try:
            data = await analysis_service.analyze_recording(file_path, prompt, duration)
            session = save_session(db, student_id, prompt, file_path, data)
            job.status, job.session_id = "done", session.id
        except ValueError as e:
            remove_file(file_path)
            job.status, job.error = "failed", str(e)
        except Exception as e:
            print(f"[Analysis Error] job {job_id}: {e}")
            db.rollback()
            job = db.query(models.AnalysisJob).filter(models.AnalysisJob.id == job_id).first()
            job.status, job.error = "failed", AI_BUSY_MESSAGE
        db.commit()
    finally:
        db.close()


@router.post("/analyze-async", response_model=schemas.AnalysisJobResponse)
async def start_analysis(
    background_tasks: BackgroundTasks,
    prompt: str = Form(...),
    duration: float = Form(30.0),
    audio: UploadFile = File(...),
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(get_db)
):
    """Accepts a recording and returns at once; the app polls /jobs/{id} and notifies when done."""
    require_prompt(prompt)
    file_path = await save_upload(audio, current_user.id)
    job = models.AnalysisJob(student_id=current_user.id, prompt=prompt.strip(), status="processing")
    db.add(job)
    db.commit()
    db.refresh(job)
    background_tasks.add_task(run_analysis_job, job.id, current_user.id, prompt, file_path, duration)
    return schemas.AnalysisJobResponse(job_id=job.id, status=job.status)


@router.get("/jobs/{job_id}", response_model=schemas.AnalysisJobResponse)
def get_analysis_job(
    job_id: int,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(get_db)
):
    job = db.query(models.AnalysisJob).filter(
        models.AnalysisJob.id == job_id, models.AnalysisJob.student_id == current_user.id
    ).first()
    if not job:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Analysis not found.")
    return schemas.AnalysisJobResponse(job_id=job.id, status=job.status, error=job.error, session_id=job.session_id)
