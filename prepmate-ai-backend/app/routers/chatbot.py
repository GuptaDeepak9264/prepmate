"""Chatbot Router - AI conversation with history"""
from fastapi import APIRouter, Depends, HTTPException, status
from app.core.dependencies import get_current_user, AuthenticatedUser
from app.models.schemas import (
    ChatRequest, ChatResponse, ChatSessionListItem, ChatMessage, BaseResponse
)
from app.services import chatbot_service

router = APIRouter()


@router.post("/send", response_model=ChatResponse, summary="Send a chat message")
async def send_message(
    body: ChatRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """
    Send a message to the AI chatbot.

    - **message**: Your question or message (max 2000 chars)
    - **session_id**: Omit to start a new session; provide to continue existing chat
    - **subject_context**: Optional subject focus (e.g., "Physics", "World War II")

    The AI gives concise 2-3 line answers by default.
    Full conversation history is maintained per session.
    """
    reply, session_id, history_count = await chatbot_service.send_message(
        user_id=user.uid,
        message=body.message,
        session_id=body.session_id,
        subject_context=body.subject_context,
    )
    return ChatResponse(reply=reply, session_id=session_id, history_count=history_count)


@router.get(
    "/sessions",
    response_model=list[ChatSessionListItem],
    summary="List all chat sessions",
)
async def list_sessions(user: AuthenticatedUser = Depends(get_current_user)):
    """Returns all chat sessions for the user, newest first."""
    return await chatbot_service.list_sessions(user.uid)


@router.get(
    "/sessions/{session_id}",
    response_model=list[ChatMessage],
    summary="Get session message history",
)
async def get_session(
    session_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Returns full message history for a chat session."""
    messages = await chatbot_service.get_session_history(user.uid, session_id)
    if not messages:
        raise HTTPException(status_code=404, detail="Session not found.")
    return messages


@router.delete(
    "/sessions/{session_id}",
    response_model=BaseResponse,
    summary="Delete a chat session",
)
async def delete_session(
    session_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Permanently deletes a chat session and its history."""
    deleted = await chatbot_service.delete_session(user.uid, session_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Session not found.")
    return BaseResponse(message="Session deleted.")
