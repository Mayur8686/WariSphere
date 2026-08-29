#!/usr/bin/env python3
"""Seed the demo cast for the volunteer workflow:

* 3 volunteers (Rahul Patil, Om Shinde, Sugal More) with logins
* the built-in dev authority (dev mode only — real authorities come from
  scripts/create_authority.py)
* 3 unassigned SOS alerts incl. the "Medical emergency near MMCOE" used
  in the hackathon demo script

Works in BOTH modes: Firebase configured → writes go to Firebase Auth +
Firestore; otherwise to the local dev store. Safe to re-run (idempotent).

    cd backend
    python scripts/seed_demo_volunteers.py
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app import firebase  # noqa: E402
from app.schemas.volunteer import VolunteerCreate  # noqa: E402
from app.services import auth as auth_service  # noqa: E402
from app.services import sos as sos_service  # noqa: E402
from app.services import users as users_service  # noqa: E402
from app.services import volunteers as volunteers_service  # noqa: E402

MODE = "Firebase" if firebase.firebase_ready else "local dev store"

VOLUNTEERS = [
    {
        "name": "Rahul Patil",
        "email": "rahul.patil@warisphere.dev",
        "password": "Volunteer@123",
        "phone": "+91 98220 11223",
        "emergency_contact": "+91 98220 44556",
        "zone": "Sector A - MMCOE / Karvenagar",
        "skills": ["first_aid", "emergency_response"],
    },
    {
        "name": "Om Shinde",
        "email": "om.shinde@warisphere.dev",
        "password": "Volunteer@123",
        "phone": "+91 98220 22334",
        "emergency_contact": "+91 98220 55667",
        "zone": "Sector B - Alandi",
        "skills": ["crowd_management", "route_assistance"],
    },
    {
        "name": "Sugal More",
        "email": "sugal.more@warisphere.dev",
        "password": "Volunteer@123",
        "phone": "+91 98220 33445",
        "emergency_contact": "+91 98220 66778",
        "zone": "Sector C - Pune Station",
        "skills": ["lost_person_assistance", "medical_assistance"],
    },
]

DEMO_SOS = [
    {
        "user_id": "WRI-SUJAL01",
        "sos_type": "medical",
        "message": "Warkari collapsed near the college gate, needs urgent medical help.",
        "user_name": "Sujal Bergal",
        "user_phone": "9876543210",
        "latitude": 18.5183,
        "longitude": 73.9276,
        "accuracy_meters": 8.0,
    },
    {
        "user_id": "WRI-ANJALI07",
        "sos_type": "safety",
        "message": "Separated from the dindi, feeling unsafe near the flyover.",
        "user_name": "Anjali More",
        "user_phone": "9876500001",
        "latitude": 18.5231,
        "longitude": 73.8510,
        "accuracy_meters": 15.0,
    },
    {
        "user_id": "WRI-RAMESH21",
        "sos_type": "general",
        "message": "Elderly warkari dehydrated, requesting water and rest support.",
        "user_name": "Ramesh Patil",
        "user_phone": "9876500002",
        "latitude": 18.6784,
        "longitude": 73.8966,
        "accuracy_meters": 20.0,
    },
]


def seed_volunteers() -> None:
    print(f"Seeding volunteers into {MODE}…")
    for item in VOLUNTEERS:
        if users_service.get_user_by_email(item["email"]):
            print(f"  exists: {item['name']} ({item['email']})")
            continue
        record = volunteers_service.create_volunteer(
            VolunteerCreate(**item),
            created_by="seed",
            created_by_name="Demo seed",
        )
        print(f"  created: {record['name']}  uid={record['uid']}  email={item['email']}")


def seed_sos() -> None:
    print(f"Seeding demo SOS alerts into {MODE}…")
    existing = {
        alert.get("user_id")
        for alert in sos_service.list_sos(limit=500)
        if alert.get("status") == "active"
    }
    from app.schemas.sos import SOSCreate

    for item in DEMO_SOS:
        if item["user_id"] in existing:
            print(f"  active alert already present for {item['user_name']} — skipping")
            continue
        record = sos_service.create_sos(SOSCreate(**item))
        print(f"  SOS: {record['sos_type']:>8}  {record.get('user_name')}  id={record['sos_id']}")


def main() -> int:
    if not firebase.firebase_ready:
        auth_service.ensure_dev_authority()
        print("Dev authority ready: authority@warisphere.dev / Authority@123")
    seed_volunteers()
    seed_sos()
    print("\nVolunteer logins (dev): <email> / Volunteer@123")
    print("Next: open the Authority Dashboard → Active SOS → Assign Volunteer")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
