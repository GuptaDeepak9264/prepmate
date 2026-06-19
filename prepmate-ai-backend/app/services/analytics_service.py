"""
Analytics Service
- Tracks study streaks, accuracy, progress, badges
- Aggregates per-subject performance
- Returns weekly progress charts data
"""

import logging
from datetime import datetime, timezone, date, timedelta

from app.core.firebase import get_firestore_client
from app.models.schemas import AnalyticsDashboard, SubjectAccuracy, WeeklyProgress

logger = logging.getLogger(__name__)
ANALYTICS_COLLECTION = "user_analytics"
MCQ_ATTEMPTS_COLLECTION = "mcq_attempts"
PDF_COLLECTION = "pdf_documents"
NOTES_COLLECTION = "generated_notes"


def _now():
    return datetime.now(timezone.utc)


BADGES = {
    "first_mcq":        ("🎯 First MCQ",           "Completed your first MCQ"),
    "streak_3":         ("🔥 3-Day Streak",         "Studied 3 days in a row"),
    "streak_7":         ("⚡ Week Warrior",          "Studied 7 days in a row"),
    "streak_30":        ("🏆 Month Master",          "Studied 30 days in a row"),
    "accuracy_80":      ("✅ High Achiever",         "Achieved 80%+ accuracy"),
    "accuracy_95":      ("🌟 Excellence Award",      "Achieved 95%+ accuracy"),
    "pdf_5":            ("📚 Avid Reader",           "Uploaded 5+ PDFs"),
    "notes_10":         ("📝 Note Taker",            "Generated 10+ notes sets"),
    "mcq_100":          ("❓ Quiz Master",           "Attempted 100+ MCQ questions"),
}


def _compute_badges(stats: dict) -> list[str]:
    """Determine earned badges based on analytics stats."""
    earned = []
    streak = stats.get("study_streak_days", 0)
    accuracy = stats.get("overall_accuracy_percent", 0)
    total_mcq = stats.get("total_mcq_attempted", 0)
    pdfs = stats.get("pdfs_uploaded", 0)
    notes = stats.get("notes_generated", 0)

    if total_mcq >= 1:    earned.append(BADGES["first_mcq"][0])
    if streak >= 3:        earned.append(BADGES["streak_3"][0])
    if streak >= 7:        earned.append(BADGES["streak_7"][0])
    if streak >= 30:       earned.append(BADGES["streak_30"][0])
    if accuracy >= 80:     earned.append(BADGES["accuracy_80"][0])
    if accuracy >= 95:     earned.append(BADGES["accuracy_95"][0])
    if pdfs >= 5:          earned.append(BADGES["pdf_5"][0])
    if notes >= 10:        earned.append(BADGES["notes_10"][0])
    if total_mcq >= 100:   earned.append(BADGES["mcq_100"][0])

    return earned


async def get_dashboard(user_id: str) -> AnalyticsDashboard:
    """
    Build a complete analytics dashboard for the user.
    """
    db = get_firestore_client()

    # ── Base analytics doc ────────────────────────────────────────────────────
    analytics_ref = db.collection(ANALYTICS_COLLECTION).document(user_id)
    analytics_doc = analytics_ref.get()
    base_stats = analytics_doc.to_dict() if analytics_doc.exists else {}

    # ── PDFs uploaded ─────────────────────────────────────────────────────────
    pdf_count = len(list(
        db.collection(PDF_COLLECTION)
        .where("user_id", "==", user_id)
        .limit(500)
        .stream()
    ))

    # ── Notes generated ────────────────────────────────────────────────────────
    notes_count = base_stats.get("notes_generated", 0)
    flashcards_count = base_stats.get("flashcards_created", 0)

    # ── MCQ attempts (last 50) ─────────────────────────────────────────────────
    attempt_docs = list(
        db.collection(MCQ_ATTEMPTS_COLLECTION)
        .where("user_id", "==", user_id)
        .order_by("created_at", direction="DESCENDING")
        .limit(50)
        .stream()
    )
    attempts = [d.to_dict() for d in attempt_docs]

    total_mcq = sum(a["total"] for a in attempts)
    total_correct = sum(a["score"] for a in attempts)
    overall_accuracy = round(
        (total_correct / total_mcq * 100) if total_mcq > 0 else 0, 1
    )

    # ── Per-subject accuracy ───────────────────────────────────────────────────
    subject_map: dict[str, dict] = {}
    for attempt in attempts:
        subj = attempt.get("subject") or attempt.get("topic", "General")
        if subj not in subject_map:
            subject_map[subj] = {"correct": 0, "total": 0}
        subject_map[subj]["correct"] += attempt["score"]
        subject_map[subj]["total"] += attempt["total"]

    subject_accuracy = [
        SubjectAccuracy(
            subject=subj,
            correct=vals["correct"],
            total=vals["total"],
            accuracy_percent=round(vals["correct"] / vals["total"] * 100, 1),
        )
        for subj, vals in subject_map.items()
        if vals["total"] > 0
    ]

    # ── Weekly progress (last 4 weeks) ────────────────────────────────────────
    weekly_progress = _compute_weekly_progress(attempts)

    # ── Study hours (from planner completions) ────────────────────────────────
    total_study_hours = base_stats.get("total_study_hours", 0.0)

    # ── Streak ────────────────────────────────────────────────────────────────
    streak = base_stats.get("study_streak_days", 0)

    # ── Badges ────────────────────────────────────────────────────────────────
    stats_for_badges = {
        "study_streak_days": streak,
        "overall_accuracy_percent": overall_accuracy,
        "total_mcq_attempted": total_mcq,
        "pdfs_uploaded": pdf_count,
        "notes_generated": notes_count,
    }
    badges = _compute_badges(stats_for_badges)

    # Persist updated summary
    analytics_ref.set(
        {
            "user_id": user_id,
            "total_mcq_attempted": total_mcq,
            "overall_accuracy_percent": overall_accuracy,
            "pdfs_uploaded": pdf_count,
            "notes_generated": notes_count,
            "last_active": _now(),
        },
        merge=True,
    )

    return AnalyticsDashboard(
        user_id=user_id,
        study_streak_days=streak,
        total_study_hours=total_study_hours,
        total_mcq_attempted=total_mcq,
        overall_accuracy_percent=overall_accuracy,
        pdfs_uploaded=pdf_count,
        notes_generated=notes_count,
        flashcards_created=flashcards_count,
        subject_accuracy=subject_accuracy,
        weekly_progress=weekly_progress,
        last_active=base_stats.get("last_active"),
        badges=badges,
    )


def _compute_weekly_progress(attempts: list[dict]) -> list[WeeklyProgress]:
    """Build last-4-weeks progress summary from MCQ attempts."""
    today = date.today()
    weeks: list[WeeklyProgress] = []

    for week_offset in range(3, -1, -1):
        week_start = today - timedelta(days=today.weekday() + 7 * week_offset)
        week_end = week_start + timedelta(days=6)
        label = f"Week of {week_start.strftime('%b %d')}"

        week_attempts = [
            a for a in attempts
            if a.get("created_at")
            and _to_date(a["created_at"]) >= week_start
            and _to_date(a["created_at"]) <= week_end
        ]

        mcq_attempted = sum(a["total"] for a in week_attempts)
        total_score = sum(a["score"] for a in week_attempts)
        avg_score = round(
            (total_score / mcq_attempted * 100) if mcq_attempted > 0 else 0, 1
        )

        weeks.append(WeeklyProgress(
            week_label=label,
            study_hours=0.0,    # Would be populated from planner completions
            mcq_attempted=mcq_attempted,
            mcq_score_avg=avg_score,
        ))

    return weeks


def _to_date(ts) -> date:
    """Convert Firestore timestamp or datetime to date."""
    if hasattr(ts, "date"):
        return ts.date()
    if isinstance(ts, str):
        try:
            return datetime.fromisoformat(ts).date()
        except Exception:
            return date.today()
    return date.today()
