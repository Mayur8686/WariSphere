from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.firebase import db, firebase_ready
from app.routes.sos import router as sos_router
from app.routes.lost_person import router as lost_person_router
from app.services.photo_storage import uploads_root


app = FastAPI(
    title="WariSphere API",
    description="Backend API for WariSphere",
    version="0.1.0",
)

# Dev CORS: the Flutter WEB build (flutter run -d chrome) is served from a
# different origin (localhost:xxxx) and the browser would otherwise block
# its calls to this API. Permissive on purpose for the hackathon;
# lock allow_origins down before any public deployment.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
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

# Photos uploaded while Firebase is not configured (dev mode) are served from
# `backend/uploads/` — see app/services/photo_storage.py.
app.mount(
    "/uploads",
    StaticFiles(directory=uploads_root()),
    name="uploads",
)


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
    if not firebase_ready or db is None:
        return {
            "status": "error",
            "firebase": "not-configured",
            "hint": "Add firebase-service-account.json (see backend/README.md)",
        }

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
