"""MCQ Generator Router - Generate, attempt, and score quizzes"""
from fastapi import APIRouter, Depends, HTTPException
from app.core.dependencies import get_current_user, AuthenticatedUser
from app.models.schemas import (
    GenerateMCQRequest, GenerateMCQResponse,
    SubmitMCQRequest, SubmitMCQResponse, MCQSet,
)
from app.services import mcq_service, pdf_service

router = APIRouter()


@router.post(
    "/generate",
    response_model=GenerateMCQResponse,
    summary="Generate a new MCQ set",
)
async def generate_mcq(
    body: GenerateMCQRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """
    Generate multiple choice questions on any topic.

    - **topic**: Subject topic (e.g., "Photosynthesis", "French Revolution")
    - **subject**: Broader subject area (e.g., "Biology", "History")
    - **count**: Number of questions (5–100)
    - **difficulty**: easy / medium / hard / mixed
    - **document_id**: Optional — generate questions from your uploaded PDF

    Questions are generated in parallel batches of 25 for speed.
    All answers are stored server-side for tamper-proof scoring.
    """
    # If PDF context requested, fetch it
    pdf_context = ""
    if body.document_id:
        doc = await pdf_service.get_document(user.uid, body.document_id)
        if not doc:
            raise HTTPException(status_code=404, detail="Document not found.")
        pdf_context = doc.full_text[:8000]

    return await mcq_service.generate_mcq_set(user.uid, body, pdf_context)


@router.post(
    "/submit",
    response_model=SubmitMCQResponse,
    summary="Submit answers and get score",
)
async def submit_answers(
    body: SubmitMCQRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """
    Submit answers for a generated MCQ set.

    Returns:
    - Overall score and percentage
    - Per-question result with correct answers and explanations
    - Attempt is saved to analytics for progress tracking
    """
    try:
        return await mcq_service.submit_answers(user.uid, body)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get(
    "/sets",
    response_model=list[dict],
    summary="List all MCQ sets",
)
async def list_sets(user: AuthenticatedUser = Depends(get_current_user)):
    """Returns all generated MCQ sets for the user."""
    return await mcq_service.list_sets(user.uid)


@router.get(
    "/sets/{set_id}",
    response_model=MCQSet,
    summary="Get a specific MCQ set",
)
async def get_set(
    set_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Returns the full MCQ set including all questions and answers."""
    mcq_set = await mcq_service.get_set(user.uid, set_id)
    if not mcq_set:
        raise HTTPException(status_code=404, detail="MCQ set not found.")
    return mcq_set
