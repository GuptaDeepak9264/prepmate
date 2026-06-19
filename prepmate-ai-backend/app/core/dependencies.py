"""
FastAPI dependency for Firebase Authentication.
Validates Bearer tokens on protected routes.
"""

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from firebase_admin import auth
from app.core.firebase import get_firestore_client
import logging

logger = logging.getLogger(__name__)

bearer_scheme = HTTPBearer(auto_error=True)


class AuthenticatedUser:
    def __init__(self, uid: str, email: str, name: str = ""):
        self.uid = uid
        self.email = email
        self.name = name

    def __repr__(self):
        return f"<User uid={self.uid} email={self.email}>"


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
) -> AuthenticatedUser:
    """
    Verify Firebase ID token and return authenticated user.
    Raises 401 if token is invalid or expired.
    """
    token = credentials.credentials
    try:
        decoded = auth.verify_id_token(token)
        return AuthenticatedUser(
            uid=decoded["uid"],
            email=decoded.get("email", ""),
            name=decoded.get("name", ""),
        )
    except auth.ExpiredIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired. Please re-authenticate.",
        )
    except auth.InvalidIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token.",
        )
    except Exception as e:
        logger.error(f"Auth error: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication failed.",
        )


async def get_optional_user(
    credentials: HTTPAuthorizationCredentials = Depends(
        HTTPBearer(auto_error=False)
    ),
) -> AuthenticatedUser | None:
    """Optional auth - returns None if no token provided."""
    if not credentials:
        return None
    return await get_current_user(credentials)
