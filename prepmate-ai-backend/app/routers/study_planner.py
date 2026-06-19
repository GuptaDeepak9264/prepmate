"""Study Planner Router - Personalized daily study plans"""
from fastapi import APIRouter, Depends, HTTPException
from app.core.dependencies import get_current_user, AuthenticatedUser
from app.models.schemas import (
    GeneratePlannerRequest, StudyPlanResponse, UpdateTaskRequest, BaseResponse
)
from app.services import planner_service

router = APIRouter()


@router.post(
    "/generate",
    response_model=StudyPlanResponse,
    summary="Generate a personalized study plan",
)
async def generate_plan(
    body: GeneratePlannerRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """
    Generate a multi-day personalized study plan.

    The AI considers:
    - **subjects**: List of subjects to cover
    - **exam_date**: Auto-calculates days until exam (max 30 days)
    - **daily_hours**: Your available study hours per day
    - **weak_topics**: Topics needing more attention (allocated more time)
    - **strong_topics**: Already mastered topics (less revision)
    - **study_style**: intensive / balanced / light

    Includes scheduled breaks, revision sessions, and practice tests.
    """
    return await planner_service.generate_plan(user.uid, body)


@router.get(
    "/",
    response_model=list[dict],
    summary="List all study plans",
)
async def list_plans(user: AuthenticatedUser = Depends(get_current_user)):
    """Returns all generated study plans, newest first."""
    return await planner_service.list_plans(user.uid)


@router.get(
    "/{plan_id}",
    response_model=StudyPlanResponse,
    summary="Get a specific study plan",
)
async def get_plan(
    plan_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Returns full plan with all days and tasks."""
    plan = await planner_service.get_plan(user.uid, plan_id)
    if not plan:
        raise HTTPException(status_code=404, detail="Study plan not found.")
    return plan


@router.patch(
    "/task/complete",
    response_model=BaseResponse,
    summary="Mark a task as complete/incomplete",
)
async def mark_task(
    body: UpdateTaskRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """
    Toggle task completion status.
    Completing tasks on consecutive days builds your study streak!
    """
    updated = await planner_service.mark_task_complete(user.uid, body)
    if not updated:
        raise HTTPException(status_code=404, detail="Task or plan not found.")
    return BaseResponse(message="Task updated successfully.")
