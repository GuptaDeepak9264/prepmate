"""
PDF Processing Service
- Extracts text from PDFs (native text + OCR fallback)
- Handles scanned PDFs and handwritten notes via Tesseract
- Stores extracted content in Firestore
- Optionally uploads to Firebase Storage
"""

import fitz              # PyMuPDF
import pytesseract
from PIL import Image
import io
import os
import uuid
import logging
from pathlib import Path
from datetime import datetime, timezone

from app.core.firebase import get_firestore_client
from app.core.config import settings
from app.models.schemas import PDFDocument, PDFListItem

logger = logging.getLogger(__name__)

PDF_COLLECTION = "pdf_documents"
MIN_TEXT_CHARS_PER_PAGE = 50  # Below this, trigger OCR for that page


def _now():
    return datetime.now(timezone.utc)


def _extract_text_from_page(page: fitz.Page) -> tuple[str, str]:
    """
    Extract text from a single PDF page.
    Returns (text, method) where method is 'text' or 'ocr'.
    """
    text = page.get_text("text").strip()

    if len(text) >= MIN_TEXT_CHARS_PER_PAGE:
        return text, "text"

    # OCR fallback for scanned/image pages
    try:
        mat = fitz.Matrix(2.0, 2.0)   # 2x zoom for better OCR quality
        pix = page.get_pixmap(matrix=mat, alpha=False)
        img_bytes = pix.tobytes("png")
        img = Image.open(io.BytesIO(img_bytes))

        ocr_text = pytesseract.image_to_string(
            img,
            config="--oem 3 --psm 6",   # LSTM engine, assume uniform block of text
        ).strip()
        return ocr_text, "ocr"
    except Exception as e:
        logger.warning(f"OCR failed for page: {e}")
        return text, "text"  # Return whatever native text we had


def extract_pdf_text(file_path: str) -> dict:
    """
    Full PDF text extraction.
    Returns: {pages: [...], full_text, page_count, word_count, method}
    """
    doc = fitz.open(file_path)
    pages_data = []
    methods_used = set()

    for page_num in range(len(doc)):
        page = doc[page_num]
        text, method = _extract_text_from_page(page)
        pages_data.append({"page": page_num + 1, "text": text, "method": method})
        methods_used.add(method)

    doc.close()

    full_text = "\n\n".join(p["text"] for p in pages_data if p["text"])
    word_count = len(full_text.split())

    if "ocr" in methods_used and "text" in methods_used:
        final_method = "hybrid"
    elif "ocr" in methods_used:
        final_method = "ocr"
    else:
        final_method = "text"

    return {
        "pages": pages_data,
        "full_text": full_text,
        "page_count": len(pages_data),
        "word_count": word_count,
        "extraction_method": final_method,
    }


async def process_and_store_pdf(
    user_id: str,
    file_path: str,
    original_filename: str,
) -> PDFDocument:
    """
    Process a PDF file and store metadata + text in Firestore.
    """
    document_id = str(uuid.uuid4())

    logger.info(f"Processing PDF: {original_filename} for user {user_id}")

    # Extract text
    extraction = extract_pdf_text(file_path)

    # Store in Firestore
    db = get_firestore_client()
    safe_filename = f"{document_id}_{original_filename}"

    doc_data = {
        "document_id": document_id,
        "user_id": user_id,
        "filename": safe_filename,
        "original_name": original_filename,
        "page_count": extraction["page_count"],
        "word_count": extraction["word_count"],
        "extraction_method": extraction["extraction_method"],
        "storage_path": file_path,
        "full_text": extraction["full_text"],
        "created_at": _now(),
    }

    db.collection(PDF_COLLECTION).document(document_id).set(doc_data)

    # Clean up temp file
    try:
        os.remove(file_path)
    except Exception:
        pass

    return PDFDocument(**doc_data)


async def get_document(user_id: str, document_id: str) -> PDFDocument | None:
    db = get_firestore_client()
    doc = db.collection(PDF_COLLECTION).document(document_id).get()
    if not doc.exists:
        return None
    data = doc.to_dict()
    # Ownership check
    if data["user_id"] != user_id:
        return None
    return PDFDocument(**data)


async def list_documents(user_id: str) -> list[PDFListItem]:
    db = get_firestore_client()
    docs = (
        db.collection(PDF_COLLECTION)
        .where("user_id", "==", user_id)
        .order_by("created_at", direction="DESCENDING")
        .limit(100)
        .stream()
    )
    return [
        PDFListItem(
            document_id=d.to_dict()["document_id"],
            filename=d.to_dict()["original_name"],
            page_count=d.to_dict()["page_count"],
            word_count=d.to_dict()["word_count"],
            created_at=d.to_dict().get("created_at"),
        )
        for d in docs
    ]


async def delete_document(user_id: str, document_id: str) -> bool:
    db = get_firestore_client()
    doc_ref = db.collection(PDF_COLLECTION).document(document_id)
    doc = doc_ref.get()
    if not doc.exists or doc.to_dict()["user_id"] != user_id:
        return False
    doc_ref.delete()
    return True
