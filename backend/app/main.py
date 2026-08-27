from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.firebase import db
from app.routes.sos import router as sos_router
from app.routes.lost_person import router as lost_person_router


app = FastAPI(
    title="WariSphere API",
    description="Backend API for WariSphere",
    version="0.1.0",
)


# Allow the Flutter Web frontend to communicate with FastAPI.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


app.include_router(sos_router)
app.include_router(lost_person_router)


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