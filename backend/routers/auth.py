import datetime
import secrets
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from database import get_db
import models
import schemas
import auth
from services.email_service import send_email

router = APIRouter(prefix="/api", tags=["Authentication"])

RESET_CODE_MINUTES = 15
RESET_MAX_ATTEMPTS = 5
RESET_RESEND_SECONDS = 60

@router.post("/auth/register", response_model=schemas.TokenResponse)
def register(user_data: schemas.UserRegister, db: Session = Depends(get_db)):
    """Registers a new student account, hashes the password, and returns access token."""
    existing = db.query(models.User).filter(models.User.email == user_data.email.lower()).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="An account with this email address already exists."
        )

    hashed_pw = auth.get_password_hash(user_data.password)
    new_user = models.User(
        name=user_data.name.strip(),
        email=user_data.email.lower(),
        password_hash=hashed_pw,
        role="student"
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    token = auth.create_access_token(data={"sub": str(new_user.id), "role": new_user.role})
    return schemas.TokenResponse(
        access_token=token,
        token_type="bearer",
        user_id=new_user.id,
        name=new_user.name,
        email=new_user.email,
        role=new_user.role
    )

@router.post("/auth/login", response_model=schemas.TokenResponse)
def login(login_data: schemas.UserLogin, db: Session = Depends(get_db)):
    """Authenticates any user (student or admin) and issues a JWT; the app routes by role."""
    user = db.query(models.User).filter(models.User.email == login_data.email.lower()).first()
    if not user or not auth.verify_password(login_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password."
        )

    token = auth.create_access_token(data={"sub": str(user.id), "role": user.role})
    return schemas.TokenResponse(
        access_token=token,
        token_type="bearer",
        user_id=user.id,
        name=user.name,
        email=user.email,
        role=user.role
    )

@router.post("/admin/login", response_model=schemas.TokenResponse)
def admin_login(login_data: schemas.AdminLogin, db: Session = Depends(get_db)):
    """Authenticates an administrator. Rejects normal student credentials."""
    user = db.query(models.User).filter(models.User.email == login_data.email.lower()).first()
    if not user or not auth.verify_password(login_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid admin credentials."
        )

    if user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access forbidden: Account does not have administrator privileges."
        )

    token = auth.create_access_token(data={"sub": str(user.id), "role": user.role})
    return schemas.TokenResponse(
        access_token=token,
        token_type="bearer",
        user_id=user.id,
        name=user.name,
        email=user.email,
        role=user.role
    )

@router.post("/auth/forgot-password", response_model=schemas.MessageResponse)
def forgot_password(data: schemas.ForgotPasswordRequest, db: Session = Depends(get_db)):
    """Emails a 6-digit reset code. The reply is the same whether or not the account exists."""
    generic = schemas.MessageResponse(
        message="If an account exists for this email, a 6-digit code has been sent. It expires in 15 minutes."
    )
    user = db.query(models.User).filter(models.User.email == data.email.lower()).first()
    if not user:
        return generic

    now = datetime.datetime.utcnow()
    latest = (
        db.query(models.PasswordReset)
        .filter(models.PasswordReset.user_id == user.id)
        .order_by(models.PasswordReset.created_at.desc())
        .first()
    )
    if latest and (now - latest.created_at).total_seconds() < RESET_RESEND_SECONDS:
        return generic

    code = f"{secrets.randbelow(1_000_000):06d}"
    db.query(models.PasswordReset).filter(models.PasswordReset.user_id == user.id).delete()
    db.add(models.PasswordReset(
        user_id=user.id,
        code_hash=auth.get_password_hash(code),
        expires_at=now + datetime.timedelta(minutes=RESET_CODE_MINUTES),
    ))
    db.commit()

    try:
        send_email(
            user.email,
            "Your VoiceIQ password reset code",
            f"<p>Hi {user.name},</p>"
            f"<p>Your VoiceIQ password reset code is:</p>"
            f"<h2 style='letter-spacing:6px'>{code}</h2>"
            f"<p>It expires in {RESET_CODE_MINUTES} minutes. If you didn't ask for this, you can ignore this email.</p>",
        )
    except Exception as e:
        print(f"[Email Error] {e}")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Could not send the reset email right now. Please try again in a few minutes."
        )
    return generic

@router.post("/auth/reset-password", response_model=schemas.MessageResponse)
def reset_password(data: schemas.ResetPasswordRequest, db: Session = Depends(get_db)):
    """Verifies the emailed code and sets a new password."""
    invalid = HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="Invalid or expired code. Please request a new one."
    )
    user = db.query(models.User).filter(models.User.email == data.email.lower()).first()
    if not user:
        raise invalid

    reset = db.query(models.PasswordReset).filter(models.PasswordReset.user_id == user.id).first()
    if not reset or reset.expires_at < datetime.datetime.utcnow() or reset.attempts >= RESET_MAX_ATTEMPTS:
        raise invalid

    if not auth.verify_password(data.code, reset.code_hash):
        reset.attempts += 1
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Incorrect code. {max(RESET_MAX_ATTEMPTS - reset.attempts, 0)} attempt(s) left."
        )

    user.password_hash = auth.get_password_hash(data.new_password)
    db.delete(reset)
    db.commit()
    return schemas.MessageResponse(message="Password updated. You can now sign in with your new password.")

@router.get("/auth/me", response_model=schemas.UserResponse)
def get_me(current_user: models.User = Depends(auth.get_current_user)):
    """Returns currently authenticated user information."""
    return current_user
