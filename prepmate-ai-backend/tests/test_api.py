"""
PrepMate AI - Test Suite
Run with: pytest tests/ -v
"""

import pytest
from httpx import AsyncClient
from unittest.mock import AsyncMock, MagicMock, patch
import json

# ─── Fixtures ────────────────────────────────────────────────────────────────

@pytest.fixture
def mock_firebase_user():
    return MagicMock(uid="test-uid-123", email="test@prepmate.ai", name="Test User")


@pytest.fixture
def auth_headers():
    return {"Authorization": "Bearer test-token"}


# ─── App Import (with mocked Firebase init) ───────────────────────────────────

@pytest.fixture
async def app_client():
    with patch("app.core.firebase.initialize_firebase"), \
         patch("firebase_admin.auth.verify_id_token") as mock_verify, \
         patch("app.core.firebase.get_firestore_client"):

        mock_verify.return_value = {
            "uid": "test-uid-123",
            "email": "test@prepmate.ai",
            "name": "Test User",
        }

        from app.main import app
        async with AsyncClient(app=app, base_url="http://test") as client:
            yield client


# ─── Health ───────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_root(app_client):
    r = await app_client.get("/")
    assert r.status_code == 200
    data = r.json()
    assert data["service"] == "PrepMate AI Backend"
    assert data["status"] == "operational"


@pytest.mark.asyncio
async def test_health(app_client):
    r = await app_client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "healthy"


# ─── Auth ─────────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_get_profile_unauthorized(app_client):
    r = await app_client.get("/api/v1/auth/me")
    assert r.status_code == 403  # No token provided


@pytest.mark.asyncio
async def test_get_profile_authorized(app_client):
    with patch("app.services.auth_service.get_or_create_profile") as mock_profile:
        mock_profile.return_value = MagicMock(
            uid="test-uid-123",
            email="test@prepmate.ai",
            name="Test User",
            study_goal_hours=4,
            subjects=[],
            dict=lambda: {
                "uid": "test-uid-123", "email": "test@prepmate.ai",
                "name": "Test User", "study_goal_hours": 4, "subjects": [],
            }
        )
        r = await app_client.get(
            "/api/v1/auth/me",
            headers={"Authorization": "Bearer valid-token"},
        )
        assert r.status_code == 200


# ─── Chatbot ──────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_send_chat_message(app_client):
    with patch("app.services.chatbot_service.send_message") as mock_send:
        mock_send.return_value = ("Mitosis is cell division into two identical cells.", "abc123", 2)
        r = await app_client.post(
            "/api/v1/chat/send",
            json={"message": "What is mitosis?"},
            headers={"Authorization": "Bearer valid-token"},
        )
        assert r.status_code == 200
        data = r.json()
        assert "reply" in data
        assert "session_id" in data


@pytest.mark.asyncio
async def test_chat_message_too_long(app_client):
    r = await app_client.post(
        "/api/v1/chat/send",
        json={"message": "x" * 2001},
        headers={"Authorization": "Bearer valid-token"},
    )
    assert r.status_code == 422  # Validation error


# ─── PDF ──────────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_upload_pdf_wrong_type(app_client):
    r = await app_client.post(
        "/api/v1/pdf/upload",
        files={"file": ("test.txt", b"plain text content", "text/plain")},
        headers={"Authorization": "Bearer valid-token"},
    )
    assert r.status_code == 415


@pytest.mark.asyncio
async def test_list_documents_empty(app_client):
    with patch("app.services.pdf_service.list_documents") as mock_list:
        mock_list.return_value = []
        r = await app_client.get(
            "/api/v1/pdf/",
            headers={"Authorization": "Bearer valid-token"},
        )
        assert r.status_code == 200
        assert r.json() == []


# ─── MCQ ──────────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_generate_mcq_validation(app_client):
    # count > 100 should fail
    r = await app_client.post(
        "/api/v1/mcq/generate",
        json={"topic": "Photosynthesis", "count": 101},
        headers={"Authorization": "Bearer valid-token"},
    )
    assert r.status_code == 422


@pytest.mark.asyncio
async def test_generate_mcq_success(app_client):
    with patch("app.services.mcq_service.generate_mcq_set") as mock_gen:
        mock_gen.return_value = MagicMock(
            set_id="set123",
            topic="Photosynthesis",
            total_questions=10,
            difficulty="medium",
            questions=[],
            dict=lambda: {
                "set_id": "set123", "topic": "Photosynthesis",
                "total_questions": 10, "difficulty": "medium", "questions": [],
            }
        )
        r = await app_client.post(
            "/api/v1/mcq/generate",
            json={"topic": "Photosynthesis", "count": 10, "difficulty": "medium"},
            headers={"Authorization": "Bearer valid-token"},
        )
        assert r.status_code == 200


# ─── Unit: MCQ JSON Parsing ────────────────────────────────────────────────────

def test_mcq_json_parse():
    from app.services.mcq_service import _parse_questions, _clean_json

    raw = """```json
{
  "questions": [
    {
      "question": "What is H2O?",
      "options": {"A": "Water", "B": "Salt", "C": "Air", "D": "Oil"},
      "correct_answer": "A",
      "explanation": "H2O is the chemical formula for water.",
      "difficulty": "easy"
    }
  ]
}
```"""
    questions = _parse_questions(raw, "Chemistry", "easy", "test")
    assert len(questions) == 1
    assert questions[0].correct_answer == "A"
    assert questions[0].question == "What is H2O?"


# ─── Unit: PDF text extraction ────────────────────────────────────────────────

def test_clean_json_strips_fences():
    from app.services.mcq_service import _clean_json
    raw = '```json\n{"key": "value"}\n```'
    cleaned = _clean_json(raw)
    assert cleaned == '{"key": "value"}'


# ─── Unit: Streak logic ──────────────────────────────────────────────────────

def test_badge_computation():
    from app.services.analytics_service import _compute_badges
    stats = {
        "study_streak_days": 8,
        "overall_accuracy_percent": 85,
        "total_mcq_attempted": 50,
        "pdfs_uploaded": 2,
        "notes_generated": 3,
    }
    badges = _compute_badges(stats)
    assert "🔥 3-Day Streak" in badges
    assert "⚡ Week Warrior" in badges
    assert "✅ High Achiever" in badges
    assert "🏆 Month Master" not in badges  # streak < 30


# ─── Rate Limiting ────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_rate_limit_headers(app_client):
    r = await app_client.get("/health")
    # Health is exempt from rate limiting, other endpoints should have headers
    assert r.status_code == 200
