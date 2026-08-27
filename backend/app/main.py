from fastapi import FastAPI

from app.firebase import db
from app.routes.sos import router as sos_router


app = FastAPI(
    title="WariSphere API",
    description="Backend API for WariSphere",
    version="0.1.0",
)


app.include_router(sos_router)


@app.get("/")
def root():
    return {
        "message": "WariSphere API is running",
        "status": "ok",
    }


@app.get("/health")
def health():
    return {
        "status": "healthy",
    }


@app.get("/firebase-health")
def firebase_health():
    try:
        db.collection("system").document("health").set({
            "status": "connected"
        })

        return {
            "status": "healthy",
            "firebase": "connected",
        }

    except Exception as e:
        return {
            "status": "error",
            "firebase": "disconnected",
            "error": str(e),
        }