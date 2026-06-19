"""
Daily Study Planner Service
- Generates AI-personalized study plans
- Considers exam date, weak/strong topics, study style
- Tracks task completion
"""

import json
import uuid
import re
import logging
from datetime import datetime, timezone, date, timedelta

from app.core.firebase import get_firestore_client
from app.core.gemini import generate_text
from app.models.schemas import (
    GeneratePlannerRequest, StudyPlanResponse, DailyPlan, StudyTask, UpdateTaskRequest
)

logger = logging.getLogger(__name__)
PLANS_COLLECTION = "study_plans"


def _now():
    return datetime.now(timezone.utc)


def _clean_json(raw: str) -> str:
    raw = re.sub(r"```json\s*", "", raw)
    raw = re.sub(r"```\s*", "", raw)
    return raw.strip()


PLANNER_PROMPT = """
You are an expert academic study planner. Create a personalized daily study plan.

Student Profile:
- Subjects: {subjects}
- Daily study hours: {daily_hours}
- Study style: {study_style}
- Weak topics: {weak_topics}
- Strong topics: {strong_topics}
- Exam date: {exam_date}
- Planning start date: {start_date}

Generate a {num_days}-day study plan.

Rules:
- Allocate more time to weak topics
- Include revision sessions and practice tests
- Add short breaks (15 min) after every 90 min study block
- Include a motivational tip at the end
- Mix subjects daily to prevent burnout
- Tasks should sum to roughly {daily_hours} hours per day

Return ONLY valid JSON in this EXACT format:
{{
  "title": "Plan title",
  "motivational_tip": "One encouraging sentence for the student",
  "days": [
    {{
      "date": "YYYY-MM-DD",
      "day_label": "Day 1 - Monday",
      "tasks": [
        {{
          "title": "Study Thermodynamics",
          "subject": "Physics",
          "duration_minutes": 60,
          "priority": "high",
          "task_type": "study",
          "notes": "Focus on first and second laws"
        }},
        {{
          "title": "Short Break",
          "subject": "Break",
          "duration_minutes": 15,
          "priority": "low",
          "task_type": "break",
          "notes": "Stretch and hydrate"
        }}
      ]
    }}
  ]
}}
"""


def _calculate_days(exam_date_str: str | None, daily_hours: int) -> int:
    """Calculate number of planning days."""
    if exam_date_str:
        try:
            exam = date.fromisoformat(exam_date_str)
            days_left = (exam - date.today()).days
            return max(1, min(days_left, 30))
        except ValueError:
            pass
    # Default to 7 days
    return 7


def _parse_plan(
    raw: str,
    user_id: str,
    plan_id: str,
    request: GeneratePlannerRequest,
) -> StudyPlanResponse:
    data = json.loads(_clean_json(raw))

    days = []
    for day_data in data.get("days", []):
        tasks = []
        for i, t in enumerate(day_data.get("tasks", [])):
            tasks.append(StudyTask(
                task_id=f"{plan_id}_{day_data['date']}_{i}",
                title=t["title"],
                subject=t["subject"],
                duration_minutes=t["duration_minutes"],
                priority=t.get("priority", "medium"),
                task_type=t.get("task_type", "study"),
                notes=t.get("notes"),
                completed=False,
            ))

        total_study_minutes = sum(
            t.duration_minutes for t in tasks if t.task_type != "break"
        )

        days.append(DailyPlan(
            date=day_data["date"],
            day_label=day_data["day_label"],
            total_hours=round(total_study_minutes / 60, 1),
            tasks=tasks,
        ))

    return StudyPlanResponse(
        plan_id=plan_id,
        user_id=user_id,
        title=data.get("title", "My Study Plan"),
        subjects=request.subjects,
        exam_date=request.exam_date,
        daily_hours=request.daily_hours,
        days=days,
        motivational_tip=data.get("motivational_tip", "You can do this! Stay consistent."),
        created_at=_now(),
    )


async def generate_plan(
    user_id: str,
    request: GeneratePlannerRequest,
) -> StudyPlanResponse:
    """Generate a personalized multi-day study plan."""
    plan_id = str(uuid.uuid4())[:12]
    num_days = _calculate_days(request.exam_date, request.daily_hours)
    start_date = date.today().isoformat()

    prompt = PLANNER_PROMPT.format(
        subjects=", ".join(request.subjects),
        daily_hours=request.daily_hours,
        study_style=request.study_style,
        weak_topics=", ".join(request.weak_topics) if request.weak_topics else "None specified",
        strong_topics=", ".join(request.strong_topics) if request.strong_topics else "None specified",
        exam_date=request.exam_date or "Not specified",
        start_date=start_date,
        num_days=num_days,
    )

    logger.info(f"Generating {num_days}-day plan for user {user_id}")
    raw = await generate_text(prompt, use_pro=True)

    plan = _parse_plan(raw, user_id, plan_id, request)

    # Persist to Firestore
    db = get_firestore_client()
    db.collection(PLANS_COLLECTION).document(plan_id).set(plan.dict())

    return plan


async def get_plan(user_id: str, plan_id: str) -> StudyPlanResponse | None:
    db = get_firestore_client()
    doc = db.collection(PLANS_COLLECTION).document(plan_id).get()
    if not doc.exists:
        return None
    data = doc.to_dict()
    if data["user_id"] != user_id:
        return None
    return StudyPlanResponse(**data)


async def list_plans(user_id: str) -> list[dict]:
    db = get_firestore_client()
    docs = (
        db.collection(PLANS_COLLECTION)
        .where("user_id", "==", user_id)
        .order_by("created_at", direction="DESCENDING")
        .limit(20)
        .stream()
    )
    return [
        {
            "plan_id": d.to_dict()["plan_id"],
            "title": d.to_dict()["title"],
            "subjects": d.to_dict()["subjects"],
            "exam_date": d.to_dict().get("exam_date"),
            "total_days": len(d.to_dict().get("days", [])),
            "created_at": d.to_dict().get("created_at"),
        }
        for d in docs
    ]


async def mark_task_complete(
    user_id: str,
    req: UpdateTaskRequest,
) -> bool:
    """Toggle task completion and update streak analytics."""
    db = get_firestore_client()
    doc_ref = db.collection(PLANS_COLLECTION).document(req.plan_id)
    doc = doc_ref.get()
    if not doc.exists:
        return False

    data = doc.to_dict()
    if data["user_id"] != user_id:
        return False

    # Find and update the specific task
    updated = False
    for day in data.get("days", []):
        if day["date"] == req.date:
            for task in day.get("tasks", []):
                if task["task_id"] == req.task_id:
                    task["completed"] = req.completed
                    updated = True
                    break

    if updated:
        doc_ref.update({"days": data["days"]})
        # Update study streak if completing a task
        if req.completed:
            _update_streak(db, user_id)

    return updated


def _update_streak(db, user_id: str):
    """Update study streak in analytics."""
    try:
        from google.cloud.firestore_v1 import Increment
        ref = db.collection("user_analytics").document(user_id)
        today = date.today().isoformat()
        doc = ref.get()
        if doc.exists:
            last_active = doc.to_dict().get("last_active_date", "")
            yesterday = (date.today() - timedelta(days=1)).isoformat()
            if last_active == yesterday:
                # Consecutive day - increment streak
                ref.update({
                    "study_streak_days": Increment(1),
                    "last_active_date": today,
                    "last_active": _now(),
                })
            elif last_active != today:
                # Streak broken - reset to 1
                ref.update({
                    "study_streak_days": 1,
                    "last_active_date": today,
                    "last_active": _now(),
                })
        else:
            ref.set({
                "study_streak_days": 1,
                "last_active_date": today,
                "last_active": _now(),
            }, merge=True)
    except Exception as e:
        logger.warning(f"Streak update failed: {e}")
