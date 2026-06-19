"""
Gemini AI client wrapper.
Handles model instantiation, retry logic, and prompt formatting.
"""

import google.generativeai as genai
from app.core.config import settings
import logging
import asyncio
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type
import google.api_core.exceptions as google_exceptions

logger = logging.getLogger(__name__)

# Configure Gemini
genai.configure(api_key=settings.GEMINI_API_KEY)

GENERATION_CONFIG = genai.types.GenerationConfig(
    max_output_tokens=settings.GEMINI_MAX_TOKENS,
    temperature=settings.GEMINI_TEMPERATURE,
)

SAFETY_SETTINGS = [
    {"category": "HARM_CATEGORY_HARASSMENT",       "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
    {"category": "HARM_CATEGORY_HATE_SPEECH",       "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
    {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
    {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
]


def get_flash_model() -> genai.GenerativeModel:
    """Fast model for chatbot and quick tasks."""
    return genai.GenerativeModel(
        model_name=settings.GEMINI_MODEL,
        generation_config=GENERATION_CONFIG,
        safety_settings=SAFETY_SETTINGS,
    )


def get_pro_model() -> genai.GenerativeModel:
    """Pro model for complex tasks: MCQ, notes, planner."""
    return genai.GenerativeModel(
        model_name=settings.GEMINI_PRO_MODEL,
        generation_config=genai.types.GenerationConfig(
            max_output_tokens=settings.GEMINI_MAX_TOKENS,
            temperature=0.4,  # Lower temp for structured outputs
        ),
        safety_settings=SAFETY_SETTINGS,
    )


@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=2, max=10),
    retry=retry_if_exception_type((
        google_exceptions.ResourceExhausted,
        google_exceptions.ServiceUnavailable,
    )),
)
async def generate_text(prompt: str, use_pro: bool = False) -> str:
    """
    Generate text from Gemini asynchronously with retry.
    Args:
        prompt: The prompt to send.
        use_pro: Use Pro model for better quality (slower).
    Returns:
        Generated text string.
    """
    model = get_pro_model() if use_pro else get_flash_model()
    try:
        loop = asyncio.get_event_loop()
        response = await loop.run_in_executor(
            None, lambda: model.generate_content(prompt)
        )
        return response.text
    except google_exceptions.InvalidArgument as e:
        logger.error(f"Gemini invalid argument: {e}")
        raise ValueError(f"Invalid prompt or content: {e}")
    except Exception as e:
        logger.error(f"Gemini generation error: {e}")
        raise


@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=2, max=10),
)
async def generate_chat_response(
    message: str,
    history: list[dict],
    system_instruction: str = "",
) -> str:
    """
    Generate a chat response maintaining conversation history.
    Args:
        message: Current user message.
        history: List of {"role": "user"|"model", "parts": [text]} dicts.
        system_instruction: Optional system context.
    """
    model = genai.GenerativeModel(
        model_name=settings.GEMINI_MODEL,
        generation_config=genai.types.GenerationConfig(
            max_output_tokens=512,   # Keep chatbot answers concise
            temperature=0.7,
        ),
        safety_settings=SAFETY_SETTINGS,
        system_instruction=system_instruction or (
            "You are PrepMate, a concise and helpful study assistant. "
            "Always answer in 2-3 lines unless asked for more detail. "
            "Be encouraging and student-friendly."
        ),
    )

    chat = model.start_chat(history=history)
    loop = asyncio.get_event_loop()
    response = await loop.run_in_executor(None, lambda: chat.send_message(message))
    return response.text
