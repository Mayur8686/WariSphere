#!/usr/bin/env python3
"""Seed three active missing-person reports for the hackathon demo.

Creates (or refreshes) Sujal Bergal, Anjali More and Ramesh Patil. When
demo photos exist under backend/demo_assets/, they are uploaded so the
InsightFace pipeline can build embeddings.

    cd backend
    python scripts/seed_demo_missing.py
    python scripts/seed_demo_missing.py --api http://127.0.0.1:8000
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import urllib.error
import urllib.request


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "demo_assets"

PEOPLE = [
    {
        "client_report_id": "LP-SUJAL-DEMO",
        "name": "Sujal Bergal",
        "age": 22,
        "gender": "Male",
        "description": "Yellow shirt, short black hair. Last seen near the college gate.",
        "last_seen_location": "Near MMCOE",
        "hours_ago": 8,
        "photo": "sujal_bergal.jpg",
        "reporter_name": "Demo Warkari",
        "reporter_phone": "9876543210",
    },
    {
        "client_report_id": "LP-ANJALI-DEMO",
        "name": "Anjali More",
        "age": 34,
        "gender": "Female",
        "description": "Orange saree, carrying a water bottle, walking with the dindi.",
        "last_seen_location": "Pune station help desk",
        "hours_ago": 5,
        "photo": "anjali_more.jpg",
        "reporter_name": "Volunteer Desk",
        "reporter_phone": "9876500001",
    },
    {
        "client_report_id": "LP-RAMESH-DEMO",
        "name": "Ramesh Patil",
        "age": 61,
        "gender": "Male",
        "description": "White kurta, orange topi, walks with a stick.",
        "last_seen_location": "Alandi ghat",
        "hours_ago": 14,
        "photo": "ramesh_patil.jpg",
        "reporter_name": "Fellow Warkari",
        "reporter_phone": "9876500002",
    },
]


def _post_json(url: str, payload: dict) -> dict:
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read().decode("utf-8"))


def _post_file(url: str, path: Path, client_report_id: str) -> dict:
    boundary = "----WarisphereSeedBoundary"
    filename = path.name
    content_type = "image/jpeg" if path.suffix.lower() in {".jpg", ".jpeg"} else "image/png"
    file_bytes = path.read_bytes()
    body = (
        (
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="client_report_id"\r\n\r\n'
            f"{client_report_id}\r\n"
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="file"; filename="{filename}"\r\n'
            f"Content-Type: {content_type}\r\n\r\n"
        ).encode("utf-8")
        + file_bytes
        + f"\r\n--{boundary}--\r\n".encode("utf-8")
    )
    req = urllib.request.Request(
        url,
        data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read().decode("utf-8"))


def seed(api: str) -> None:
    api = api.rstrip("/")
    created = []
    for person in PEOPLE:
        photo_url = None
        photo_path = ASSETS / person["photo"]
        if photo_path.is_file():
            try:
                uploaded = _post_file(
                    f"{api}/lost-person/photo",
                    photo_path,
                    person["client_report_id"],
                )
                photo_url = uploaded.get("photo_url")
                print(f"  photo {person['name']}: {photo_url}")
            except urllib.error.HTTPError as exc:
                print(f"  photo upload failed for {person['name']}: {exc.read().decode('utf-8', 'ignore')}")
        else:
            print(f"  no photo at {photo_path} — seeding {person['name']} without a face image")

        seen = datetime.now(timezone.utc) - timedelta(hours=person["hours_ago"])
        payload = {
            "client_report_id": person["client_report_id"],
            "report_type": "lost",
            "name": person["name"],
            "age": person["age"],
            "gender": person["gender"],
            "description": person["description"],
            "last_seen_location": person["last_seen_location"],
            "last_seen_time": seen.isoformat(),
            "photo_url": photo_url,
            "reporter_name": person["reporter_name"],
            "reporter_phone": person["reporter_phone"],
        }
        try:
            record = _post_json(f"{api}/lost-person", payload)
        except urllib.error.HTTPError as exc:
            print(f"FAILED {person['name']}: {exc.read().decode('utf-8', 'ignore')}")
            continue
        flag = " (already existed)" if record.get("duplicate") else ""
        print(f"  {record.get('status')}  {record.get('name')}  {record.get('lost_person_id')}{flag}")
        created.append(record)

    print(f"\nSeeded {len(created)} missing-person records via {api}")
    print("Open the dashboard → Lost Persons → Missing, then scan sujal_bergal.jpg")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--api", default="http://127.0.0.1:8000")
    args = parser.parse_args()
    try:
        seed(args.api)
    except urllib.error.URLError as exc:
        print(f"Cannot reach {args.api}: {exc}", file=sys.stderr)
        print("Start the API first: uvicorn app.main:app --host 0.0.0.0 --port 8000", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
