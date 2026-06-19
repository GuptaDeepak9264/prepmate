"""
Auth / User Profile Service
- Creates/updates user profiles in Firestore on first login
- Profile synced with Firebase Auth user data
"""

import logging
from datetime import datetime, timezone

from firebase_admin import auth as firebase_auth
from app.core.firebase import get_firestore_client
from app.models.schemas import UserProfile, UpdateProfileRequest

logger = logging.getLogger(__name__)
USERS_COLLECTION = "users"


def _now():
    return datetime.now(timezone.utc)


async def get_or_create_profile(uid: str, email: str, name: str) -> UserProfile:
    """
    Return existing profile or create one on first login.
    """
    db = get_firestore_client()
    ref = db.collection(USERS_COLLECTION).document(uid)
    doc = ref.get()

    if doc.exists:
        data = doc.to_dict()
        return UserProfile(**data)

    # First-time login — create profile
    profile_data = {
        "uid": uid,
        "email": email,
        "name": name or email.split("@")[0],
        "avatar_url": None,
        "study_goal_hours": 4,
        "subjects": [],
        "created_at": _now(),
        "updated_at": _now(),
    }
    ref.set(profile_data)
    logger.info(f"New user profile created: {uid}")
    return UserProfile(**profile_data)


async def update_profile(uid: str, updates: UpdateProfileRequest) -> UserProfile:
    db = get_firestore_client()
    ref = db.collection(USERS_COLLECTION).document(uid)

    update_data = updates.dict(exclude_none=True)
    update_data["updated_at"] = _now()
    ref.update(update_data)

    doc = ref.get()
    return UserProfile(**doc.to_dict())
