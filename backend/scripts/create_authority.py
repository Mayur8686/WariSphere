#!/usr/bin/env python3
"""Create a WariSphere *authority* account.

Firebase configured (firebase-service-account.json present):
    Creates a Firebase Authentication user + a users/{uid} Firestore
    document with role="authority". Sign in to the Authority Dashboard
    with the email/password you pass here.

Dev mode (no key):
    Writes a local dev account usable via POST /auth/dev-session.

    cd backend
    python scripts/create_authority.py --email ops@warisphere.in --password 'Secret@123' --name "Control Room"
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.services import users  # noqa: E402
from app import firebase  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--email", required=True)
    parser.add_argument("--password", required=True)
    parser.add_argument("--name", default="Control Room Authority")
    args = parser.parse_args()

    email = args.email.strip().lower()
    existing = users.get_user_by_email(email)
    if existing:
        print(f"Account for {email} already exists (uid={existing['uid']}, role={existing.get('role')})")
        return 0

    uid = users.create_auth_account(email, args.password, args.name.strip())
    users.create_user_record(
        uid,
        name=args.name.strip(),
        email=email,
        role="authority",
        status="active",
        created_by="bootstrap",
        dev_password=None if firebase.firebase_ready else args.password,
    )
    mode = "Firebase Auth + Firestore" if firebase.firebase_ready else "LOCAL dev store"
    print(f"Authority created via {mode}")
    print(f"  uid:   {uid}")
    print(f"  email: {email}")
    print(f"  role:  authority")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
