# AI-assisted Lost Person Face Matching

Probable matching only. A similarity score is **not** identity. An authority
must confirm or reject every proposed match before any missing-person status
changes.

## A. Files changed

### New

- `backend/app/config.py` — thresholds, model name, optional authority token
- `backend/app/services/face_match.py` — InsightFace detect / embed / cosine rank
- `backend/app/services/face_matches.py` — `face_matches` store (Firestore or local JSON)
- `backend/app/services/matching.py` — scan / confirm / reject orchestration
- `backend/tests/test_face_match.py` — ranking, scan, confirm, reject, error cases
- `backend/tests/conftest.py` — isolated stores, skip model warmup in tests
- `backend/scripts/seed_demo_missing.py` — seed Sujal Bergal + two other missing persons
- `docs/AI_FACE_MATCHING.md` — this file

### Modified

- `backend/app/main.py` — background InsightFace warmup on startup
- `backend/app/routes/lost_person.py` — scan-match + confirm + reject + status
- `backend/app/schemas/lost_person.py` — `MatchDecisionRequest`
- `backend/app/services/lost_person.py` — embeddings on create, public strip, get/update helpers
- `backend/requirements.txt` — insightface, onnxruntime, opencv-python-headless, numpy, Pillow
- `backend/tests/test_lost_person.py` — disable auto face-process in tests
- `backend/README.md` — new endpoints
- `dashboard/src/lib/api.js` — `scanFaceMatch`, confirm/reject, same-origin default
- `dashboard/src/components/modules/LostPersons.jsx` — AI Lost-Person Scanner UI
- `dashboard/vite.config.js` — `0.0.0.0`, proxy to FastAPI
- `.gitignore` — model cache, local data/uploads

Existing SOS, QR, medical camps, routes, lost-person create/list/status, and
the Flutter client are unchanged. Face embeddings are stripped from every
public lost-person API response.

## B. New dependencies

Backend (`backend/requirements.txt`):

- `insightface>=0.7.3`
- `onnxruntime>=1.16.0`
- `opencv-python-headless>=4.8.0` (provides `cv2`; server build of OpenCV)
- `numpy>=1.23.0,<2.0.0`
- `Pillow>=10.0.0`

Dashboard: no new npm packages.

The InsightFace `buffalo_l` weights download once into `backend/.insightface/`
on first warmup or first scan (git-ignored).

## C. New API endpoints

Existing router prefix is `/lost-person` (not `/api/lost-persons`).

| Method | Path | Purpose |
| ------ | ---- | ------- |
| POST | `/lost-person/scan-match` | Multipart found-person photo → ranked probable matches |
| POST | `/lost-person/matches/{match_id}/confirm` | Authority confirms; marks both reports `reunited` |
| POST | `/lost-person/matches/{match_id}/reject` | Authority rejects; person statuses unchanged |
| GET | `/lost-person/face-match/status` | Model readiness + configured thresholds |

`POST /lost-person/scan-match` (multipart `file`, optional `reporter_name`, `client_report_id`):

```json
{
  "success": true,
  "faces_detected": 1,
  "records_scanned": 3,
  "found_person_id": "...",
  "found_photo_url": "/uploads/lost_persons/...",
  "matches": [
    {
      "match_id": "...",
      "person_id": "...",
      "name": "Sujal Bergal",
      "photo_url": "...",
      "similarity": 0.87,
      "match_score": 87,
      "confidence": "High confidence",
      "status": "missing",
      "location": "Near MMCOE",
      "missing_for": "8 hours"
    }
  ],
  "message": null,
  "disclaimer": "These are probable matches only. ..."
}
```

Confirm / reject body:

```json
{ "verified_by": "control-room" }
```

## D. Firestore / local schema

Still uses collection `lost_persons` (or `backend/data/lost_persons.json`).

Added fields on a lost-person document (server-side only for the vector):

| Field | Meaning |
| ----- | ------- |
| `face_embedding` | L2-normalised float vector (stripped from API responses) |
| `face_embedding_version` | e.g. `insightface-buffalo_l-v1` |
| `face_processed` | `true` when an embedding was stored |
| `face_processing_error` | error / `"pending"` / `null` |

New collection `face_matches` (or `backend/data/face_matches.json`):

```json
{
  "id": "...",
  "found_person_id": "...",
  "missing_person_id": "...",
  "similarity": 0.87,
  "match_score": 87,
  "status": "pending",
  "created_at": "...",
  "verified_by": null,
  "verified_at": null
}
```

`status` is `pending` | `confirmed` | `rejected`. Confirm also sets
`verified_by`, `verified_at`, and marks both person reports `reunited`.

## E. Environment / configuration

| Variable | Default | Purpose |
| -------- | ------- | ------- |
| `WARISPHERE_FACE_MODEL` | `buffalo_l` | InsightFace pack (`buffalo_s` is faster on CPU) |
| `WARISPHERE_FACE_EMBEDDING_VERSION` | `insightface-{model}-v1` | Stored with each vector |
| `WARISPHERE_FACE_MATCH_TOP_K` | `5` | Max matches returned |
| `WARISPHERE_FACE_SIM_HIGH` | `0.75` | “High confidence” |
| `WARISPHERE_FACE_SIM_POSSIBLE` | `0.55` | “Possible match” |
| `WARISPHERE_FACE_SIM_MIN` | `0.35` | Below this, drop the candidate |
| `WARISPHERE_FACE_DET_SIZE` | `640` | Detector input size |
| `WARISPHERE_FACE_WARMUP` | `1` | Load model on API boot |
| `WARISPHERE_AUTO_FACE_PROCESS` | `1` | Embed photos in the background on create |
| `WARISPHERE_AUTHORITY_TOKEN` | _(empty)_ | If set, matching endpoints require `X-Authority-Token` |
| `INSIGHTFACE_HOME` | `backend/.insightface` | Model cache |
| `VITE_API_BASE` | _(empty, same origin)_ | Dashboard API origin |
| `VITE_AUTHORITY_TOKEN` | _(empty)_ | Sent as `X-Authority-Token` when the backend token is set |

## F. Run the backend

```bash
cd backend
python -m venv .venv
source .venv/bin/activate          # Windows: .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Optional Firebase: place `backend/firebase-service-account.json` (see
`backend/README.md`). Without it, lost-person + match records go to
`backend/data/*.json` and photos to `backend/uploads/`.

First InsightFace load downloads weights and can take a few minutes.

## G. Run the React dashboard

```bash
cd dashboard
npm install
npm run dev -- --host 0.0.0.0 --port 5173
```

Vite proxies `/lost-person` and `/uploads` to `http://127.0.0.1:8000`. Sign in
with any credentials (demo mode).

## H. Test the AI face matching feature

1. Start FastAPI and the dashboard (F, G).
2. Seed three missing persons, including Sujal Bergal (uses demo photos if present):

   ```bash
   cd backend
   python scripts/seed_demo_missing.py
   ```

   Or create them from the API / pilgrim app with a clear front-facing photo.
3. Open **Lost Persons**. Confirm **Sujal Bergal** is listed under Missing,
   location Near MMCOE.
4. In **AI LOST-PERSON SCANNER**, browse `backend/demo_assets/sujal_bergal.jpg`
   (or any photo of the same person) and click **Scan**.
5. Progress: Analyzing face → Detecting face → Scanning records → Calculating.
6. Result: **AI Analysis Complete**, records scanned, potential match with
   photo, name, similarity, location, missing status.
7. **Confirm Match** → Sujal’s card becomes **Reunited**.
8. Repeat a scan and **Reject** a non-primary match → that person stays Missing.
9. Error cases: non-image → format error; group photo → “Multiple faces…”;
   blank wall → “No face detected…”.

Unit tests (no model download):

```bash
cd backend
python -m pytest tests/ -v
```

## I. Limitations

- Prototype sequential scan, not a vector DB. `rank_by_cosine` is the FAISS seam.
- One face per photo. No face / several faces are rejected.
- First InsightFace load needs disk + network for `buffalo_l` weights
  (`backend/.insightface/models/buffalo_l/`). If GitHub/Hugging Face cannot
  be reached, the API falls back to OpenCV Haar detection + HOG embeddings
  so the demo still runs. Place the ONNX files (or set
  `WARISPHERE_FACE_DOWNLOAD=1`) to switch to InsightFace. Same-photo scans
  still rank the correct person first on the fallback.
- CPU-only (`CPUExecutionProvider`). Accuracy depends on pose, lighting, blur.
- High cosine similarity is **not** identity. Manual confirm is mandatory.
- Embeddings never leave the server on list/create/status responses.
- Dashboard login is demo-mode. Set `WARISPHERE_AUTHORITY_TOKEN` to lock matching.
- Background embed on create is skipped until the model is ready; a later scan
  backfills from the stored photo.
- Matching compares `status=missing` records that have (or can generate) embeddings.
