"""
Firebase Admin SDK initialization.
Supports both file-path and inline JSON credentials (for cloud deployment).
"""

import firebase_admin
from firebase_admin import credentials, firestore, auth, storage
from app.core.config import settings
import json
import logging

logger = logging.getLogger(__name__)

_firebase_app = None


def initialize_firebase():
    global _firebase_app
    if firebase_admin._apps:
        logger.info("Firebase already initialized.")
        return

    try:
        # Prefer inline JSON (Railway/Render env var) over file path
        if settings.FIREBASE_CREDENTIALS_JSON:
            cred_dict = json.loads(settings.FIREBASE_CREDENTIALS_JSON)
            cred = credentials.Certificate(cred_dict)
        elif settings.FIREBASE_CREDENTIALS_PATH:
            cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
        else:
            # Use Application Default Credentials (GCP / Cloud Run)
            cred = credentials.ApplicationDefault()

        _firebase_app = firebase_admin.initialize_app(
            cred,
            {
                "projectId": settings.FIREBASE_PROJECT_ID,
                "storageBucket": settings.FIREBASE_STORAGE_BUCKET,
            },
        )
        logger.info("✅ Firebase Admin SDK initialized successfully.")
    except Exception as e:
        logger.error(f"❌ Firebase initialization failed: {e}")
        raise


def get_firestore_client():
    """Return a Firestore client instance."""
    return firestore.client()


def get_auth_client():
    """Return Firebase Auth client."""
    return auth


def get_storage_bucket():
    """Return Firebase Storage bucket."""
    return storage.bucket()
