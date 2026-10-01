import datetime
import secrets
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session
from database import get_db
import models
import schemas
import auth
from services.email_service import send_email

router = APIRouter(prefix="/api", tags=["Authentication"])

CODE_MINUTES = 15
CODE_MAX_ATTEMPTS = 5
CODE_RESEND_SECONDS = 60
PURPOSE_RESET = "reset_password"
PURPOSE_VERIFY = "verify_email"


def find_user(db: Session, username: str) -> Optional[models.User]:
    """Looks a user up by email (contains '@') or by register number (case-insensitive)."""
    username = username.strip()
    if "@" in username:
        return db.query(models.User).filter(func.lower(models.User.email) == username.lower()).first()
    return db.query(models.User).filter(func.upper(models.User.register_number) == username.upper()).first()


def token_response(user: models.User) -> schemas.TokenResponse:
    token = auth.create_access_token(data={"sub": str(user.id), "role": user.role})
    return schemas.TokenResponse(
        access_token=token,
        user_id=user.id,
        name=user.name,
        register_number=user.register_number,
        email=user.email,
        email_verified=user.email_verified,
        must_change_password=user.must_change_password,
        role=user.role,
    )


def mask_email(email: str) -> str:
    local, _, domain = email.partition("@")
    return f"{local[:2]}{'*' * max(len(local) - 2, 1)}@{domain}"


def issue_code(db: Session, user: models.User, purpose: str, email: str, subject: str, intro: str) -> bool:
    """Creates and emails a 6-digit code. Returns False if one was sent too recently."""
    now = datetime.datetime.utcnow()
    latest = (
        db.query(models.VerificationCode)
        .filter(models.VerificationCode.user_id == user.id, models.VerificationCode.purpose == purpose)
        .order_by(models.VerificationCode.created_at.desc())
        .first()
    )
    if latest and latest.email == email and (now - latest.created_at).total_seconds() < CODE_RESEND_SECONDS:
        return False

    code = f"{secrets.randbelow(1_000_000):06d}"
    db.query(models.VerificationCode).filter(
        models.VerificationCode.user_id == user.id, models.VerificationCode.purpose == purpose
    ).delete()
    db.add(models.VerificationCode(
        user_id=user.id,
        purpose=purpose,
        email=email,
        code_hash=auth.get_password_hash(code),
        expires_at=now + datetime.timedelta(minutes=CODE_MINUTES),
    ))
    db.commit()

    try:
        send_email(
            email,
            subject,
            f"<p>Hi {user.name},</p><p>{intro}</p>"
            f"<h2 style='letter-spacing:6px'>{code}</h2>"
            f"<p>It expires in {CODE_MINUTES} minutes. If you didn't ask for this, you can ignore this email.</p>",
        )
    except Exception as e:
        print(f"[Email Error] {e}")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Could not send the email right now. Please try again in a few minutes."
        )
    return True


def check_code(db: Session, user: models.User, purpose: str, code: str) -> models.VerificationCode:
    """Validates a code, counting failed attempts. Returns the matching record."""
    record = (
        db.query(models.VerificationCode)
        .filter(models.VerificationCode.user_id == user.id, models.VerificationCode.purpose == purpose)
        .first()
    )
    if not record or record.expires_at < datetime.datetime.utcnow() or record.attempts >= CODE_MAX_ATTEMPTS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired code. Please request a new one."
        )
    if not auth.verify_password(code, record.code_hash):
        record.attempts += 1
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Incorrect code. {max(CODE_MAX_ATTEMPTS - record.attempts, 0)} attempt(s) left."
        )
    return record


@router.post("/auth/login", response_model=schemas.TokenResponse)
def login(login_data: schemas.UserLogin, db: Session = Depends(get_db)):
    """Students sign in with their register number, the admin with email. The app routes by role."""
    user = find_user(db, login_data.username)
    if not user or not auth.verify_password(login_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid register number or password."
        )
    return token_response(user)


@router.get("/auth/me", response_model=schemas.UserResponse)
def get_me(current_user: models.User = Depends(auth.get_current_user)):
    """Returns the signed-in user, including first-login setup status."""
    return current_user


# --- First-login setup: verify email, then choose a password ---

@router.post("/auth/email/send-code", response_model=schemas.MessageResponse)
def send_email_code(
    data: schemas.SendEmailCodeRequest,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    """Emails a code to the address the student wants to link (first setup or changing email)."""
    email = data.email.lower()
    if current_user.email_verified and (current_user.email or "").lower() == email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This is already your email."
        )
    taken = (
        db.query(models.User)
        .filter(func.lower(models.User.email) == email, models.User.id != current_user.id)
        .first()
    )
    if taken:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This email is already linked to another account."
        )
    sent = issue_code(
        db, current_user, PURPOSE_VERIFY, email,
        "Verify your email for VoiceIQ",
        "Use this code to verify your email address in VoiceIQ:",
    )
    if not sent:
        return schemas.MessageResponse(message="A code was just sent. Please wait a minute before asking again.")
    return schemas.MessageResponse(message=f"We sent a 6-digit code to {email}.")


@router.post("/auth/email/verify", response_model=schemas.UserResponse)
def verify_email(
    data: schemas.VerifyEmailRequest,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    """Confirms the code and links the email to the account."""
    record = check_code(db, current_user, PURPOSE_VERIFY, data.code)
    taken = (
        db.query(models.User)
        .filter(func.lower(models.User.email) == record.email, models.User.id != current_user.id)
        .first()
    )
    if taken:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This email is already linked to another account."
        )
    current_user.email = record.email
    current_user.email_verified = True
    db.delete(record)
    db.commit()
    db.refresh(current_user)
    return current_user


@router.post("/auth/set-password", response_model=schemas.UserResponse)
def set_password(
    data: schemas.SetPasswordRequest,
    current_user: models.User = Depends(auth.get_current_user),
    db: Session = Depends(get_db),
):
    """First-login only: replaces the default password once the email is verified."""
    if not current_user.must_change_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Use 'Forgot password' to change your password."
        )
    if not current_user.email_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Please verify your email first."
        )
    if auth.verify_password(data.new_password, current_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Choose a password different from your default one."
        )
    current_user.password_hash = auth.get_password_hash(data.new_password)
    current_user.must_change_password = False
    db.commit()
    db.refresh(current_user)
    return current_user


# --- Forgot / change password by email code ---

@router.post("/auth/forgot-password", response_model=schemas.MessageResponse)
def forgot_password(data: schemas.ForgotPasswordRequest, db: Session = Depends(get_db)):
    """Emails a reset code to the account's verified email."""
    user = find_user(db, data.username)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No account found with that register number or email."
        )
    if not user.email or not user.email_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This account has no verified email yet. Please ask your staff to reset your password."
        )
    issue_code(
        db, user, PURPOSE_RESET, user.email,
        "Your VoiceIQ password reset code",
        "Use this code to reset your VoiceIQ password:",
    )
    return schemas.MessageResponse(
        message=f"We sent a 6-digit code to {mask_email(user.email)}. It expires in {CODE_MINUTES} minutes."
    )


@router.post("/auth/reset-password", response_model=schemas.MessageResponse)
def reset_password(data: schemas.ResetPasswordRequest, db: Session = Depends(get_db)):
    """Verifies the emailed code and sets a new password."""
    user = find_user(db, data.username)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired code. Please request a new one."
        )
    record = check_code(db, user, PURPOSE_RESET, data.code)
    user.password_hash = auth.get_password_hash(data.new_password)
    user.must_change_password = False
    db.delete(record)
    db.commit()
    return schemas.MessageResponse(message="Password updated. You can now sign in with your new password.")
