"""
Pydantic models for request/response validation across all modules.
"""

from pydantic import BaseModel, Field, validator
from typing import Optional, List, Literal
from datetime import datetime
from enum import Enum


# ─── Common ───────────────────────────────────────────────────────────────────

class BaseResponse(BaseModel):
    success: bool = True
    message: str = "OK"


class ErrorResponse(BaseModel):
    success: bool = False
    detail: str


# ─── Auth ─────────────────────────────────────────────────────────────────────

class UserProfile(BaseModel):
    uid: str
    email: str
    name: str
    avatar_url: Optional[str] = None
    study_goal_hours: int = 4
    subjects: List[str] = []
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class UpdateProfileRequest(BaseModel):
    name: Optional[str] = None
    study_goal_hours: Optional[int] = Field(None, ge=1, le=16)
    subjects: Optional[List[str]] = None


# ─── Chatbot ──────────────────────────────────────────────────────────────────

class ChatMessage(BaseModel):
    role: Literal["user", "model"]
    content: str
    timestamp: Optional[datetime] = None


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=2000)
    session_id: Optional[str] = None   # continue existing session
    subject_context: Optional[str] = None  # e.g., "Physics", "History"


class ChatResponse(BaseResponse):
    reply: str
    session_id: str
    history_count: int


class ChatSession(BaseModel):
    session_id: str
    user_id: str
    title: str = "New Chat"
    messages: List[ChatMessage] = []
    subject_context: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class ChatSessionListItem(BaseModel):
    session_id: str
    title: str
    message_count: int
    last_message: Optional[str] = None
    created_at: Optional[datetime] = None


# ─── PDF Processing ───────────────────────────────────────────────────────────

class PDFUploadResponse(BaseResponse):
    document_id: str
    filename: str
    page_count: int
    word_count: int
    extraction_method: str  # "text" | "ocr" | "hybrid"
    storage_path: str
    preview_text: str   # First 300 chars


class PDFDocument(BaseModel):
    document_id: str
    user_id: str
    filename: str
    original_name: str
    page_count: int
    word_count: int
    extraction_method: str
    storage_path: str
    full_text: str
    created_at: Optional[datetime] = None


class PDFListItem(BaseModel):
    document_id: str
    filename: str
    page_count: int
    word_count: int
    created_at: Optional[datetime] = None


# ─── Notes Generator ──────────────────────────────────────────────────────────

class NotesType(str, Enum):
    SUMMARY = "summary"
    FLASHCARDS = "flashcards"
    IMPORTANT_QUESTIONS = "important_questions"
    ALL = "all"


class GenerateNotesRequest(BaseModel):
    document_id: Optional[str] = None      # From uploaded PDF
    raw_text: Optional[str] = Field(None, max_length=50000)  # Direct text
    topic: Optional[str] = None             # For topic-based generation
    notes_type: NotesType = NotesType.ALL

    @validator("raw_text", always=True)
    def validate_source(cls, v, values):
        if not v and not values.get("document_id") and not values.get("topic"):
            raise ValueError("Provide document_id, raw_text, or topic.")
        return v


class Flashcard(BaseModel):
    front: str      # Question/term
    back: str       # Answer/definition
    difficulty: Literal["easy", "medium", "hard"] = "medium"


class NotesResponse(BaseResponse):
    notes_id: str
    notes_type: str
    summary: Optional[str] = None
    flashcards: Optional[List[Flashcard]] = None
    important_questions: Optional[List[str]] = None
    source_document_id: Optional[str] = None
    topic: Optional[str] = None
    created_at: Optional[datetime] = None


# ─── MCQ Generator ────────────────────────────────────────────────────────────

class DifficultyLevel(str, Enum):
    EASY = "easy"
    MEDIUM = "medium"
    HARD = "hard"
    MIXED = "mixed"


class GenerateMCQRequest(BaseModel):
    topic: str = Field(..., min_length=3, max_length=200)
    subject: Optional[str] = None
    count: int = Field(default=10, ge=5, le=100)
    difficulty: DifficultyLevel = DifficultyLevel.MIXED
    document_id: Optional[str] = None  # Generate from uploaded PDF


class MCQOption(BaseModel):
    key: Literal["A", "B", "C", "D"]
    text: str


class MCQQuestion(BaseModel):
    question_id: str
    question: str
    options: List[MCQOption]
    correct_answer: Literal["A", "B", "C", "D"]
    explanation: str
    difficulty: str
    topic: str


class MCQSet(BaseModel):
    set_id: str
    user_id: str
    topic: str
    subject: Optional[str] = None
    difficulty: str
    questions: List[MCQQuestion]
    total_questions: int
    created_at: Optional[datetime] = None


class GenerateMCQResponse(BaseResponse):
    set_id: str
    topic: str
    total_questions: int
    difficulty: str
    questions: List[MCQQuestion]


class SubmitAnswerItem(BaseModel):
    question_id: str
    selected_answer: Literal["A", "B", "C", "D"]


class SubmitMCQRequest(BaseModel):
    set_id: str
    answers: List[SubmitAnswerItem]


class MCQResultItem(BaseModel):
    question_id: str
    question: str
    selected_answer: str
    correct_answer: str
    is_correct: bool
    explanation: str


class SubmitMCQResponse(BaseResponse):
    attempt_id: str
    set_id: str
    score: int
    total: int
    percentage: float
    correct_count: int
    incorrect_count: int
    time_taken_seconds: Optional[int] = None
    results: List[MCQResultItem]


# ─── Study Planner ────────────────────────────────────────────────────────────

class GeneratePlannerRequest(BaseModel):
    subjects: List[str] = Field(..., min_items=1)
    exam_date: Optional[str] = None     # ISO date string "2025-06-15"
    daily_hours: int = Field(default=4, ge=1, le=12)
    weak_topics: Optional[List[str]] = []
    strong_topics: Optional[List[str]] = []
    study_style: Literal["intensive", "balanced", "light"] = "balanced"


class StudyTask(BaseModel):
    task_id: str
    title: str
    subject: str
    duration_minutes: int
    priority: Literal["high", "medium", "low"]
    task_type: Literal["study", "practice", "revision", "break"]
    notes: Optional[str] = None
    completed: bool = False


class DailyPlan(BaseModel):
    date: str
    day_label: str      # e.g., "Day 1 - Monday"
    total_hours: float
    tasks: List[StudyTask]


class StudyPlanResponse(BaseResponse):
    plan_id: str
    user_id: str
    title: str
    subjects: List[str]
    exam_date: Optional[str] = None
    daily_hours: int
    days: List[DailyPlan]
    motivational_tip: str
    created_at: Optional[datetime] = None


class UpdateTaskRequest(BaseModel):
    task_id: str
    plan_id: str
    date: str
    completed: bool


# ─── Analytics ────────────────────────────────────────────────────────────────

class SubjectAccuracy(BaseModel):
    subject: str
    correct: int
    total: int
    accuracy_percent: float


class WeeklyProgress(BaseModel):
    week_label: str
    study_hours: float
    mcq_attempted: int
    mcq_score_avg: float


class AnalyticsDashboard(BaseModel):
    user_id: str
    study_streak_days: int
    total_study_hours: float
    total_mcq_attempted: int
    overall_accuracy_percent: float
    pdfs_uploaded: int
    notes_generated: int
    flashcards_created: int
    subject_accuracy: List[SubjectAccuracy]
    weekly_progress: List[WeeklyProgress]
    last_active: Optional[datetime] = None
    badges: List[str] = []
