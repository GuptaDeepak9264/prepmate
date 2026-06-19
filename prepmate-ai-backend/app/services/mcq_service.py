"""
MCQ Generator Service
- Generates up to 100 MCQs via Gemini in batches
- Stores questions and correct answers in Firestore
- Scores submissions and tracks per-user accuracy
"""

import json
import uuid
import re
import asyncio
import logging
from datetime import datetime, timezone

from app.core.firebase import get_firestore_client
from app.core.gemini import generate_text
from app.models.schemas import (
    GenerateMCQRequest, GenerateMCQResponse,
    MCQSet, MCQQuestion, MCQOption,
    SubmitMCQRequest, SubmitMCQResponse, MCQResultItem,
    DifficultyLevel,
)

logger = logging.getLogger(__name__)

MCQ_SETS_COLLECTION = "mcq_sets"
MCQ_ATTEMPTS_COLLECTION = "mcq_attempts"
BATCH_SIZE = 25  # Generate in batches to avoid token limits


def _now():
    return datetime.now(timezone.utc)


def _clean_json(raw: str) -> str:
    raw = re.sub(r"```json\s*", "", raw)
    raw = re.sub(r"```\s*", "", raw)
    return raw.strip()


MCQ_PROMPT = """
You are an expert exam question setter. Generate exactly {count} multiple choice questions on:
Topic: {topic}
Subject: {subject}
Difficulty: {difficulty}
{context}

Rules:
- Each question has exactly 4 options: A, B, C, D
- Only ONE correct answer per question
- Include a short explanation for the correct answer
- Questions must be clear, unambiguous, and educationally valuable
- Vary question types: factual, conceptual, application-based

Return ONLY valid JSON in this EXACT format (no extra text):
{{
  "questions": [
    {{
      "question": "Question text here?",
      "options": {{
        "A": "First option",
        "B": "Second option",
        "C": "Third option",
        "D": "Fourth option"
      }},
      "correct_answer": "A",
      "explanation": "Brief explanation of why A is correct.",
      "difficulty": "{difficulty_label}"
    }}
  ]
}}
"""


def _difficulty_label(difficulty: DifficultyLevel, batch_index: int) -> str:
    if difficulty == DifficultyLevel.MIXED:
        return ["easy", "medium", "hard"][batch_index % 3]
    return difficulty.value


def _parse_questions(raw: str, topic: str, difficulty: str, id_prefix: str) -> list[MCQQuestion]:
    try:
        data = json.loads(_clean_json(raw))
        questions = []
        for i, q in enumerate(data.get("questions", [])):
            opts_raw = q.get("options", {})
            options = [
                MCQOption(key=k, text=v)
                for k, v in opts_raw.items()
                if k in ("A", "B", "C", "D")
            ]
            questions.append(MCQQuestion(
                question_id=f"{id_prefix}_{i+1}",
                question=q["question"],
                options=options,
                correct_answer=q["correct_answer"],
                explanation=q.get("explanation", ""),
                difficulty=q.get("difficulty", difficulty),
                topic=topic,
            ))
        return questions
    except Exception as e:
        logger.error(f"MCQ parse error: {e}\nRaw snippet: {raw[:300]}")
        return []


async def _generate_batch(
    topic: str,
    subject: str,
    count: int,
    difficulty: DifficultyLevel,
    context: str,
    batch_index: int,
    set_id: str,
) -> list[MCQQuestion]:
    diff_label = _difficulty_label(difficulty, batch_index)
    prompt = MCQ_PROMPT.format(
        count=count,
        topic=topic,
        subject=subject or topic,
        difficulty=diff_label,
        context=f"\nAdditional context:\n{context[:3000]}" if context else "",
        difficulty_label=diff_label,
    )
    raw = await generate_text(prompt, use_pro=True)
    return _parse_questions(raw, topic, diff_label, f"{set_id}_b{batch_index}")


async def generate_mcq_set(
    user_id: str,
    request: GenerateMCQRequest,
    pdf_context: str = "",
) -> GenerateMCQResponse:
    """
    Generate a complete MCQ set, using batches for large counts.
    """
    set_id = str(uuid.uuid4())[:12]
    total = min(request.count, 100)

    # Split into batches
    batch_sizes = []
    remaining = total
    while remaining > 0:
        b = min(remaining, BATCH_SIZE)
        batch_sizes.append(b)
        remaining -= b

    logger.info(f"Generating {total} MCQs in {len(batch_sizes)} batches for {user_id}")

    # Generate concurrently
    tasks = [
        _generate_batch(
            topic=request.topic,
            subject=request.subject or request.topic,
            count=size,
            difficulty=request.difficulty,
            context=pdf_context,
            batch_index=i,
            set_id=set_id,
        )
        for i, size in enumerate(batch_sizes)
    ]
    batch_results = await asyncio.gather(*tasks, return_exceptions=True)

    all_questions: list[MCQQuestion] = []
    for result in batch_results:
        if isinstance(result, Exception):
            logger.error(f"Batch generation failed: {result}")
        else:
            all_questions.extend(result)

    # Re-number question IDs sequentially
    for idx, q in enumerate(all_questions):
        q.question_id = f"{set_id}_{idx+1}"

    # Persist to Firestore
    db = get_firestore_client()
    mcq_data = {
        "set_id": set_id,
        "user_id": user_id,
        "topic": request.topic,
        "subject": request.subject,
        "difficulty": request.difficulty.value,
        "questions": [q.dict() for q in all_questions],
        "total_questions": len(all_questions),
        "created_at": _now(),
    }
    db.collection(MCQ_SETS_COLLECTION).document(set_id).set(mcq_data)

    return GenerateMCQResponse(
        set_id=set_id,
        topic=request.topic,
        total_questions=len(all_questions),
        difficulty=request.difficulty.value,
        questions=all_questions,
    )


async def submit_answers(
    user_id: str,
    request: SubmitMCQRequest,
) -> SubmitMCQResponse:
    """
    Score a submitted MCQ attempt and store results.
    """
    db = get_firestore_client()

    # Fetch the MCQ set
    set_doc = db.collection(MCQ_SETS_COLLECTION).document(request.set_id).get()
    if not set_doc.exists:
        raise ValueError(f"MCQ set {request.set_id} not found.")

    mcq_set = MCQSet(**set_doc.to_dict())

    # Build answer key
    answer_key: dict[str, MCQQuestion] = {q.question_id: q for q in mcq_set.questions}

    attempt_id = str(uuid.uuid4())[:12]
    results = []
    correct_count = 0

    for answer in request.answers:
        question = answer_key.get(answer.question_id)
        if not question:
            continue

        is_correct = question.correct_answer == answer.selected_answer
        if is_correct:
            correct_count += 1

        results.append(MCQResultItem(
            question_id=answer.question_id,
            question=question.question,
            selected_answer=answer.selected_answer,
            correct_answer=question.correct_answer,
            is_correct=is_correct,
            explanation=question.explanation,
        ))

    total_answered = len(results)
    percentage = round((correct_count / total_answered * 100) if total_answered else 0, 1)

    # Store attempt
    attempt_data = {
        "attempt_id": attempt_id,
        "set_id": request.set_id,
        "user_id": user_id,
        "topic": mcq_set.topic,
        "subject": mcq_set.subject,
        "score": correct_count,
        "total": total_answered,
        "percentage": percentage,
        "results": [r.dict() for r in results],
        "created_at": _now(),
    }
    db.collection(MCQ_ATTEMPTS_COLLECTION).document(attempt_id).set(attempt_data)

    # Update analytics
    _update_analytics(db, user_id, mcq_set.subject or mcq_set.topic, correct_count, total_answered)

    return SubmitMCQResponse(
        attempt_id=attempt_id,
        set_id=request.set_id,
        score=correct_count,
        total=total_answered,
        percentage=percentage,
        correct_count=correct_count,
        incorrect_count=total_answered - correct_count,
        results=results,
    )


async def get_set(user_id: str, set_id: str) -> MCQSet | None:
    db = get_firestore_client()
    doc = db.collection(MCQ_SETS_COLLECTION).document(set_id).get()
    if not doc.exists:
        return None
    data = doc.to_dict()
    if data["user_id"] != user_id:
        return None
    return MCQSet(**data)


async def list_sets(user_id: str) -> list[dict]:
    db = get_firestore_client()
    docs = (
        db.collection(MCQ_SETS_COLLECTION)
        .where("user_id", "==", user_id)
        .order_by("created_at", direction="DESCENDING")
        .limit(50)
        .stream()
    )
    return [
        {
            "set_id": d.to_dict()["set_id"],
            "topic": d.to_dict()["topic"],
            "total_questions": d.to_dict()["total_questions"],
            "difficulty": d.to_dict()["difficulty"],
            "created_at": d.to_dict().get("created_at"),
        }
        for d in docs
    ]


def _update_analytics(
    db, user_id: str, subject: str, correct: int, total: int
):
    """Update per-subject accuracy and overall MCQ stats."""
    try:
        from google.cloud.firestore_v1 import Increment
        ref = db.collection("user_analytics").document(user_id)
        ref.set(
            {
                "total_mcq_attempted": Increment(total),
                f"subject_stats.{subject}.correct": Increment(correct),
                f"subject_stats.{subject}.total": Increment(total),
            },
            merge=True,
        )
    except Exception as e:
        logger.warning(f"Analytics update failed: {e}")
