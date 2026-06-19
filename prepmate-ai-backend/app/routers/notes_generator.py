"""Notes Generator Router - Summaries, Flashcards, Important Questions"""
from fastapi import APIRouter, Depends, HTTPException
from app.core.dependencies import get_current_user, AuthenticatedUser
from app.models.schemas import GenerateNotesRequest, NotesResponse
from app.services import notes_service

router = APIRouter()


@router.post(
    "/generate",
    response_model=NotesResponse,
    summary="Generate AI study notes",
)
async def generate_notes(
    body: GenerateNotesRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """
    Generate AI-powered study notes from multiple sources:

    **Sources (provide one):**
    - `document_id`: From a previously uploaded PDF
    - `raw_text`: Direct text input (max 50,000 chars)
    - `topic`: Topic name for AI-generated content

    **Notes Types:**
    - `summary` - Structured study summary with key takeaways
    - `flashcards` - Question/answer flashcard pairs with difficulty ratings
    - `important_questions` - HOT exam questions covering all angles
    - `all` - Generate all three types at once
    """
    try:
        return await notes_service.generate_notes(user.uid, body)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get(
    "/{notes_id}",
    response_model=NotesResponse,
    summary="Retrieve generated notes",
)
async def get_notes(
    notes_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Returns previously generated notes by ID."""
    notes = await notes_service.get_notes(user.uid, notes_id)
    if not notes:
        raise HTTPException(status_code=404, detail="Notes not found.")
    return notes
