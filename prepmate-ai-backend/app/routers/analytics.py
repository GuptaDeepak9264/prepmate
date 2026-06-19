"""Analytics Router - User progress and insights"""
from fastapi import APIRouter, Depends
from app.core.dependencies import get_current_user, AuthenticatedUser
from app.models.schemas import AnalyticsDashboard
from app.services import analytics_service

router = APIRouter()


@router.get(
    "/dashboard",
    response_model=AnalyticsDashboard,
    summary="Get full analytics dashboard",
)
async def get_dashboard(user: AuthenticatedUser = Depends(get_current_user)):
    """
    Returns a comprehensive analytics dashboard including:

    - 📊 **Overall accuracy** across all MCQ attempts
    - 🔥 **Study streak** (consecutive days)
    - 📚 **PDFs uploaded** and notes generated
    - 🎯 **Per-subject accuracy** breakdown
    - 📈 **Weekly progress** (last 4 weeks)
    - 🏆 **Badges earned** based on milestones
    - ⏱️ **Total study hours** tracked
    """
    return await analytics_service.get_dashboard(user.uid)
