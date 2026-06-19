"""
Notes Generator Service
- Generates summaries, flashcards, and important questions
- Works from uploaded PDFs or raw text input
- Uses Gemini Pro for structured output parsing
"""

import json
import uuid
import logging
import re
from datetime import datetime, timezone

from app.core.firebase import get_firestore_client
from app.core.gemini import generate_text
from app.models.schemas import (
    NotesType, NotesResponse, Flashcard, GenerateNotesRequest
)
from app.services.pdf_service import get_document

logger = logging.getLogger(__name__)
NOTES_COLLECTION = "generated_notes"


def _now():
    return datetime.now(timezone.utc)


def _clean_json(raw: str) -> str:
    """Strip markdown code fences and whitespace from Gemini JSON output."""
    raw = re.sub(r"```json\s*", "", raw)
    raw = re.sub(r"```\s*", "", raw)
    return raw.strip()


# ─── Prompts ──────────────────────────────────────────────────────────────────

SUMMARY_PROMPT = """
You are an expert study assistant. Read the following content and create a comprehensive study summary.

Content:
{content}

Requirements:
- Write a clear, well-structured summary (400-600 words)
- Use headings for major topics
- Highlight key concepts, dates, formulas, or names
- End with a "Key Takeaways" bullet list (5-7 points)
- Use plain text with markdown formatting

Return ONLY the summary text.
"""

FLASHCARDS_PROMPT = """
You are an expert study assistant. Create flashcards from the following content.

Content:
{content}

Requirements:
- Generate exactly {count} flashcards
- Each flashcard has a "front" (question/term) and "back" (answer/definition)
- Assign difficulty: "easy", "medium", or "hard"
- Cover key concepts, definitions, formulas, dates, and facts
- Keep answers concise (1-3 sentences)

Return ONLY valid JSON in this exact format:
{{
  "flashcards": [
    {{"front": "What is ...?", "back": "It is ...", "difficulty": "medium"}},
    ...
  ]
}}
"""

QUESTIONS_PROMPT = """
You are an expert exam question creator. Generate important study questions from this content.

Content:
{content}

Requirements:
- Generate exactly {count} important questions
- Mix question types: conceptual, analytical, application-based
- Include HOTs (Higher Order Thinking) questions
- Number each question

Return ONLY valid JSON in this exact format:
{{
  "questions": [
    "What is the significance of ...?",
    "Explain the process of ...",
    ...
  ]
}}
"""


# ─── Generators ───────────────────────────────────────────────────────────────

async def _generate_summary(content: str) -> str:
    prompt = SUMMARY_PROMPT.format(content=content[:15000])
    return await generate_text(prompt, use_pro=True)


async def _generate_flashcards(content: str, count: int = 15) -> list[Flashcard]:
    prompt = FLASHCARDS_PROMPT.format(content=content[:15000], count=count)
    raw = await generate_text(prompt, use_pro=True)
    try:
        data = json.loads(_clean_json(raw))
        return [Flashcard(**fc) for fc in data.get("flashcards", [])]
    except (json.JSONDecodeError, Exception) as e:
        logger.error(f"Flashcard parse error: {e}\nRaw: {raw[:200]}")
        return []


async def _generate_questions(content: str, count: int = 20) -> list[str]:
    prompt = QUESTIONS_PROMPT.format(content=content[:15000], count=count)
    raw = await generate_text(prompt, use_pro=True)
    try:
        data = json.loads(_clean_json(raw))
        return data.get("questions", [])
    except (json.JSONDecodeError, Exception) as e:
        logger.error(f"Questions parse error: {e}\nRaw: {raw[:200]}")
        return []


# ─── Main Service Function ────────────────────────────────────────────────────

async def generate_notes(
    user_id: str,
    request: GenerateNotesRequest,
) -> NotesResponse:
    """
    Generate notes from a PDF document, raw text, or topic.
    """
    notes_id = str(uuid.uuid4())

    # Resolve content source
    source_doc_id = None
    if request.document_id:
        doc = await get_document(user_id, request.document_id)
        if not doc:
            raise ValueError(f"Document {request.document_id} not found.")
        content = doc.full_text
        source_doc_id = request.document_id
    elif request.raw_text:
        content = request.raw_text
    elif request.topic:
        content = (
            f"Generate study notes for the topic: {request.topic}. "
            "Provide detailed content covering all major aspects of this topic."
        )
    else:
        raise ValueError("No content source provided.")

    # Generate requested note types
    summary = None
    flashcards = None
    questions = None

    if request.notes_type in (NotesType.SUMMARY, NotesType.ALL):
        logger.info(f"Generating summary for user {user_id}")
        summary = await _generate_summary(content)

    if request.notes_type in (NotesType.FLASHCARDS, NotesType.ALL):
        logger.info(f"Generating flashcards for user {user_id}")
        flashcards = await _generate_flashcards(content, count=15)

    if request.notes_type in (NotesType.IMPORTANT_QUESTIONS, NotesType.ALL):
        logger.info(f"Generating questions for user {user_id}")
        questions = await _generate_questions(content, count=20)

    # Persist to Firestore
    db = get_firestore_client()
    notes_data = {
        "notes_id": notes_id,
        "user_id": user_id,
        "notes_type": request.notes_type.value,
        "summary": summary,
        "flashcards": [fc.dict() for fc in flashcards] if flashcards else None,
        "important_questions": questions,
        "source_document_id": source_doc_id,
        "topic": request.topic,
        "created_at": _now(),
    }
    db.collection(NOTES_COLLECTION).document(notes_id).set(notes_data)

    # Update analytics counter
    _increment_analytics(db, user_id, flashcards_count=len(flashcards) if flashcards else 0)

    return NotesResponse(
        notes_id=notes_id,
        notes_type=request.notes_type.value,
        summary=summary,
        flashcards=flashcards,
        important_questions=questions,
        source_document_id=source_doc_id,
        topic=request.topic,
        created_at=_now(),
    )


async def get_notes(user_id: str, notes_id: str) -> NotesResponse | None:
    db = get_firestore_client()
    doc = db.collection(NOTES_COLLECTION).document(notes_id).get()
    if not doc.exists:
        return None
    data = doc.to_dict()
    if data["user_id"] != user_id:
        return None

    flashcards = None
    if data.get("flashcards"):
        flashcards = [Flashcard(**fc) for fc in data["flashcards"]]

    return NotesResponse(
        notes_id=data["notes_id"],
        notes_type=data["notes_type"],
        summary=data.get("summary"),
        flashcards=flashcards,
        important_questions=data.get("important_questions"),
        source_document_id=data.get("source_document_id"),
        topic=data.get("topic"),
        created_at=data.get("created_at"),
    )


def _increment_analytics(db, user_id: str, flashcards_count: int = 0):
    """Bump notes_generated and flashcards_created counters."""
    ref = db.collection("user_analytics").document(user_id)
    try:
        from google.cloud.firestore_v1 import Increment
        ref.set(
            {
                "notes_generated": Increment(1),
                "flashcards_created": Increment(flashcards_count),
            },
            merge=True,
        )
    except Exception as e:
        logger.warning(f"Analytics increment failed: {e}")
