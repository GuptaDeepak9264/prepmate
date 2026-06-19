"""Auth Router - User profile management"""
from fastapi import APIRouter, Depends
from app.core.dependencies import get_current_user, AuthenticatedUser
from app.models.schemas import UserProfile, UpdateProfileRequest
from app.services import auth_service

router = APIRouter()


@router.get("/me", response_model=UserProfile, summary="Get current user profile")
async def get_me(user: AuthenticatedUser = Depends(get_current_user)):
    """
    Returns the authenticated user's profile.
    Creates the profile automatically on first call.
    """
    return await auth_service.get_or_create_profile(
        uid=user.uid, email=user.email, name=user.name
    )


@router.put("/me", response_model=UserProfile, summary="Update user profile")
async def update_me(
    body: UpdateProfileRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Update name, study goal hours, and tracked subjects."""
    return await auth_service.update_profile(user.uid, body)
