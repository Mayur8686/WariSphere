import numpy as np
from fastapi import FastAPI

# OpenCV powers the Live Crowd CCTV stream. Like ultralytics, it degrades
# gracefully: the GUI `opencv-python` build (pulled in by some environments)
# crashes without libGL, and the API must still boot for SOS / lost-person /
# volunteer APIs when cv2 is unavailable.
try:
    import cv2
except Exception as exc:  # pragma: no cover - depends on local env
    print(f"[cctv] opencv unavailable, crowd stream disabled: {exc}")
    cv2 = None

# ultralytics (YOLOv8) powers the Live Crowd CCTV stream. It is a heavy
# optional dependency — the API must still boot (SOS / lost-person /
# volunteer system) when it isn't installed; the stream then serves raw
# frames. Install it via requirements.txt to enable detection.
try:
    from ultralytics import YOLO
except Exception as exc:  # pragma: no cover - depends on local env
    print(f"[cctv] ultralytics unavailable, detections disabled: {exc}")
    YOLO = None
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import StreamingResponse

from app.firebase import db, firebase_ready
from app.routes.sos import router as sos_router
from app.routes.lost_person import router as lost_person_router
from app.routes.auth import router as auth_router
from app.routes.volunteers import router as volunteers_router
from app.routes.tasks import router as tasks_router
from app.services.photo_storage import uploads_root

app = FastAPI(
    title="WariSphere API",
    description="Backend API for WariSphere",
    version="0.1.0",
)

# Cleaned up CORS: Merged into a single, permissive block for the hackathon
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(sos_router)
app.include_router(lost_person_router)
app.include_router(auth_router)
app.include_router(volunteers_router)
app.include_router(tasks_router)

# Photos uploaded while Firebase is not configured (dev mode)
app.mount(
    "/uploads",
    StaticFiles(directory=uploads_root()),
    name="uploads",
)

# ---------------------------------------------------------
# AI MODEL INITIALIZATION
# ---------------------------------------------------------
yolo_model = None
if YOLO is not None:
    try:
        yolo_model = YOLO("yolov8n.pt")
    except Exception as e:
        print(f"Warning: YOLO model failed to load. {e}")
        yolo_model = None


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

# ---------------------------------------------------------
# LIVE AI CCTV STREAMING ROUTE (Unthrottled for GPU)
# ---------------------------------------------------------
def generate_crowd_feed(video_path: str = "crowd_sample.mp4"):
    cap = cv2.VideoCapture(video_path)
    
    while True:
        success, frame = cap.read()
        
        # Loop video when it ends or handle missing file
        if not success:
            cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
            success, frame = cap.read()
            if not success:
                err_frame = np.zeros((480, 640, 3), dtype=np.uint8)
                cv2.putText(err_frame, "VIDEO NOT FOUND", (50, 240), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)
                ret, buffer = cv2.imencode('.jpg', err_frame)
                yield (b'--frame\r\nContent-Type: image/jpeg\r\n\r\n' + buffer.tobytes() + b'\r\n')
                break

        if yolo_model:
            # Run YOLOv8 detection on class 0 (Person) processing every frame
            results = yolo_model(frame, classes=[0], verbose=False, conf=0.4)
            
            annotated_frame = results[0].plot()
            person_count = len(results[0].boxes)
            
            cv2.putText(
                annotated_frame, 
                f"Live AI Count: {person_count}", 
                (20, 40), 
                cv2.FONT_HERSHEY_SIMPLEX, 
                1, 
                (0, 255, 0), 
                2
            )
        else:
            annotated_frame = frame

        ret, buffer = cv2.imencode('.jpg', annotated_frame)
        
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + buffer.tobytes() + b'\r\n')

@app.get("/api/cctv/stream/{cam_id}")
def stream_feed(cam_id: str):
    if cv2 is None:
        from fastapi import HTTPException

        raise HTTPException(
            status_code=503,
            detail="Crowd stream unavailable — opencv is not installed on this server.",
        )
    return StreamingResponse(
        generate_crowd_feed(),
        media_type="multipart/x-mixed-replace; boundary=frame"
    )