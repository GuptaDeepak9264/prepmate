"""
Chatbot Service
- Maintains per-user chat sessions in Firestore
- Builds Gemini history format from stored messages
- Keeps answers concise (2-3 lines) via system prompt
"""

from app.core.firebase import get_firestore_client
from app.core.gemini import generate_chat_response
from app.models.schemas import ChatMessage, ChatSession, ChatSessionListItem
from datetime import datetime, timezone
import uuid
import logging

logger = logging.getLogger(__name__)

SESSIONS_COLLECTION = "chat_sessions"


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _session_ref(db, user_id: str, session_id: str):
    return db.collection(SESSIONS_COLLECTION).document(f"{user_id}_{session_id}")


async def get_or_create_session(
    user_id: str,
    session_id: str | None,
    subject_context: str | None,
) -> tuple[str, list[dict]]:
    """
    Returns (session_id, gemini_history).
    gemini_history is a list of {"role": "user"|"model", "parts": [text]}
    """
    db = get_firestore_client()

    if session_id:
        doc = _session_ref(db, user_id, session_id).get()
        if doc.exists:
            data = doc.to_dict()
            messages = data.get("messages", [])
            history = [
                {"role": m["role"], "parts": [m["content"]]}
                for m in messages
            ]
            return session_id, history

    # Create new session
    session_id = str(uuid.uuid4())[:8]
    _session_ref(db, user_id, session_id).set({
        "session_id": session_id,
        "user_id": user_id,
        "title": "New Chat",
        "messages": [],
        "subject_context": subject_context or "",
        "created_at": _now(),
        "updated_at": _now(),
    })
    return session_id, []


async def send_message(
    user_id: str,
    message: str,
    session_id: str | None = None,
    subject_context: str | None = None,
) -> tuple[str, str, int]:
    """
    Process a chat message and store in Firestore.
    Returns: (reply_text, session_id, history_count)
    """
    db = get_firestore_client()
    session_id, history = await get_or_create_session(user_id, session_id, subject_context)

    system_prompt = (
        f"You are PrepMate, a friendly and concise study assistant. "
        f"{'Topic focus: ' + subject_context + '. ' if subject_context else ''}"
        "Always answer in 2-3 sentences unless the user explicitly asks for more detail. "
        "Use simple language. Be encouraging."
    )

    reply = await generate_chat_response(
        message=message,
        history=history,
        system_instruction=system_prompt,
    )

    # Persist both turns
    doc_ref = _session_ref(db, user_id, session_id)
    doc = doc_ref.get()
    existing = doc.to_dict().get("messages", []) if doc.exists else []

    user_msg = {"role": "user",  "content": message, "timestamp": _now().isoformat()}
    model_msg = {"role": "model", "content": reply,  "timestamp": _now().isoformat()}

    updated_messages = existing + [user_msg, model_msg]

    # Auto-generate title from first user message (first 50 chars)
    title = existing[0]["content"][:50] + "..." if existing else message[:50]

    doc_ref.update({
        "messages": updated_messages,
        "title": title,
        "updated_at": _now(),
    })

    return reply, session_id, len(updated_messages)


async def list_sessions(user_id: str) -> list[ChatSessionListItem]:
    """Return all chat sessions for a user, sorted by last update."""
    db = get_firestore_client()
    docs = (
        db.collection(SESSIONS_COLLECTION)
        .where("user_id", "==", user_id)
        .order_by("updated_at", direction="DESCENDING")
        .limit(50)
        .stream()
    )

    sessions = []
    for doc in docs:
        d = doc.to_dict()
        msgs = d.get("messages", [])
        last = msgs[-1]["content"][:80] if msgs else ""
        sessions.append(ChatSessionListItem(
            session_id=d["session_id"],
            title=d.get("title", "Chat"),
            message_count=len(msgs),
            last_message=last,
            created_at=d.get("created_at"),
        ))
    return sessions


async def get_session_history(user_id: str, session_id: str) -> list[ChatMessage]:
    """Return full message history for a session."""
    db = get_firestore_client()
    doc = _session_ref(db, user_id, session_id).get()
    if not doc.exists:
        return []
    messages = doc.to_dict().get("messages", [])
    return [
        ChatMessage(
            role=m["role"],
            content=m["content"],
            timestamp=m.get("timestamp"),
        )
        for m in messages
    ]


async def delete_session(user_id: str, session_id: str) -> bool:
    db = get_firestore_client()
    ref = _session_ref(db, user_id, session_id)
    if not ref.get().exists:
        return False
    ref.delete()
    return True
