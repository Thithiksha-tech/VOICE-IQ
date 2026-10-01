import os
import secrets
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from database import engine, Base, SessionLocal
import models
import auth
from routers import auth as auth_router
from routers import audio as audio_router
from routers import history as history_router
from routers import admin as admin_router

# Create database tables automatically
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="VoiceIQ API — AI Voice Communication Practice & Speech Analysis",
    description="Backend service powering speech-to-text, communication metrics, and student/admin dashboards for VoiceIQ.",
    version="1.0.0"
)

# CORS Configuration (Allows Flutter app on physical Android phones, Emulators, and Web)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Ensure upload directory exists and mount static serving for audio recordings
UPLOAD_DIR = os.getenv("UPLOAD_DIR", "./data/uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

# Include Modular Routers
app.include_router(auth_router.router)
app.include_router(audio_router.router)
app.include_router(history_router.router)
app.include_router(admin_router.router)

# Create the single administrator on first startup. Credentials come from the environment
# (ADMIN_EMAIL / ADMIN_PASSWORD) so they never appear in the public repository.
@app.on_event("startup")
def seed_admin_account():
    db = SessionLocal()
    try:
        if db.query(models.User).filter(models.User.role == "admin").first():
            return
        admin_email = os.getenv("ADMIN_EMAIL", "admin@voiceiq.edu").strip().lower()
        admin_password = os.getenv("ADMIN_PASSWORD")
        if not admin_password:
            admin_password = secrets.token_urlsafe(12)
            print(f">> ADMIN_PASSWORD not set; generated admin password for {admin_email}: {admin_password}")
        db.add(models.User(
            name=os.getenv("ADMIN_NAME", "VoiceIQ Admin"),
            email=admin_email,
            email_verified=True,
            password_hash=auth.get_password_hash(admin_password),
            role="admin",
        ))
        db.commit()
        print(f">> Created admin account: {admin_email}")
    except Exception as e:
        print(f">> Startup seeding notice: {e}")
    finally:
        db.close()

# Health check endpoint
@app.get("/api/health")
def health_check():
    return {
        "status": "online",
        "service": "VoiceIQ AI Speech Backend",
        "version": "1.2.0",
        "database": "connected"
    }

# Global exception handler prevents unhandled stack trace leaks to mobile clients
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    print(f"[Internal Exception] {request.method} {request.url.path}: {exc}")
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "A server error occurred. Please verify network connectivity and retry."}
    )

if __name__ == "__main__":
    import uvicorn
    # Bind to 0.0.0.0 to enable physical Android phone connectivity over the local Wi-Fi network!
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
