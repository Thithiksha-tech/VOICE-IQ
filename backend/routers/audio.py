import os
import time
import shutil
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status
from sqlalchemy.orm import Session
from database import get_db
import models
import schemas
import auth
from services.whisper_service import transcription_service
from services.analysis_service import analysis_service

router = APIRouter(prefix="/api/audio", tags=["Audio & Speech Analysis"])

UPLOAD_DIR = os.getenv("UPLOAD_DIR", "./data/uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

@router.post("/analyze", response_model=schemas.AudioAnalyzeResponse)
async def analyze_audio_session(
    prompt: str = Form(...),
    duration: float = Form(30.0),
    audio: UploadFile = File(...),
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(get_db)
):
    """
    Receives real microphone audio from the student, saves it safely,
    calls AI transcription, evaluates speech metrics, and stores the session.
    """
    if not prompt or not prompt.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Speaking prompt is required."
        )

    # Validate file extension
    allowed_exts = [".wav", ".m4a", ".mp3", ".aac", ".webm", ".ogg", ".mp4", ".3gp"]
    file_ext = os.path.splitext(audio.filename)[1].lower() if audio.filename else ".wav"
    if not file_ext or file_ext not in allowed_exts:
        file_ext = ".wav"

    timestamp = int(time.time())
    safe_filename = f"user_{current_user.id}_{timestamp}{file_ext}"
    file_path = os.path.join(UPLOAD_DIR, safe_filename)

    # Save audio stream safely to disk
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

    # Step 1: AI Speech-to-Text Transcription
    try:
        transcript = await transcription_service.transcribe_audio(file_path)
    except ValueError as e:
        # Expected user validation error (e.g. empty audio, silence)
        # Clean up temporary file to avoid clutter
        if os.path.exists(file_path):
            try: os.remove(file_path)
            except: pass
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        # Service or network failure
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"AI Transcription service encountered an issue: {str(e)}"
        )

    if not transcript or len(transcript.strip()) < 2:
        if os.path.exists(file_path):
            try: os.remove(file_path)
            except: pass
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No intelligible speech was recognized in your recording. Please try speaking closer to the microphone."
        )

    # Step 2: AI Speech & Communication Analysis
    try:
        analysis_data = await analysis_service.analyze_speech(
            prompt=prompt,
            transcript=transcript,
            audio_duration_sec=duration
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Speech analysis model failed: {str(e)}"
        )

    # Step 3: Persist Practice Session & Analysis to SQLite Database
    try:
        new_session = models.PracticeSession(
            student_id=current_user.id,
            prompt=prompt.strip(),
            audio_path=file_path,
            transcript=transcript,
            overall_score=analysis_data["overall_score"]
        )
        db.add(new_session)
        db.commit()
        db.refresh(new_session)

        new_analysis = models.SpeechAnalysis(
            practice_session_id=new_session.id,
            fluency_score=analysis_data["fluency_score"],
            pronunciation_score=analysis_data["pronunciation_score"],
            grammar_score=analysis_data["grammar_score"],
            vocabulary_score=analysis_data["vocabulary_score"],
            confidence_score=analysis_data["confidence_score"],
            words_per_minute=analysis_data["words_per_minute"],
            filler_word_count=analysis_data["filler_word_count"],
            feedback=analysis_data["feedback"]
        )
        db.add(new_analysis)
        db.commit()
        db.refresh(new_analysis)

        return schemas.AudioAnalyzeResponse(
            session_id=new_session.id,
            prompt=new_session.prompt,
            transcript=new_session.transcript,
            overall_score=new_session.overall_score,
            analysis=schemas.SpeechAnalysisSchema.from_orm(new_analysis)
        )

    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database error while saving practice analysis: {str(e)}"
        )
