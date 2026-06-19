"""PDF Processing Router - Upload, extract, OCR"""
import os
import uuid
import aiofiles
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from app.core.dependencies import get_current_user, AuthenticatedUser
from app.core.config import settings
from app.models.schemas import PDFUploadResponse, PDFListItem, PDFDocument, BaseResponse
from app.services import pdf_service

router = APIRouter()

ALLOWED_TYPES = {"application/pdf", "image/png", "image/jpeg", "image/tiff"}
MAX_SIZE = settings.MAX_UPLOAD_SIZE_MB * 1024 * 1024


@router.post(
    "/upload",
    response_model=PDFUploadResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Upload a PDF or image for text extraction",
)
async def upload_pdf(
    file: UploadFile = File(..., description="PDF or image file (max 50MB)"),
    user: AuthenticatedUser = Depends(get_current_user),
):
    """
    Upload a PDF or scanned image. The system will:
    1. Try native text extraction first
    2. Fall back to **OCR** for scanned pages or image files
    3. Apply **handwriting recognition** for handwritten notes

    Extracted text is stored and can be used with the Notes and MCQ generators.
    """
    # Validate content type
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(
            status_code=415,
            detail=f"Unsupported file type: {file.content_type}. Allowed: PDF, PNG, JPEG, TIFF.",
        )

    # Read file and check size
    contents = await file.read()
    if len(contents) > MAX_SIZE:
        raise HTTPException(
            status_code=413,
            detail=f"File too large. Max size: {settings.MAX_UPLOAD_SIZE_MB}MB.",
        )

    # Save to temp path
    tmp_filename = f"{uuid.uuid4()}_{file.filename}"
    tmp_path = os.path.join(settings.UPLOAD_DIR, tmp_filename)
    async with aiofiles.open(tmp_path, "wb") as f:
        await f.write(contents)

    # Process
    doc = await pdf_service.process_and_store_pdf(
        user_id=user.uid,
        file_path=tmp_path,
        original_filename=file.filename or "document.pdf",
    )

    return PDFUploadResponse(
        document_id=doc.document_id,
        filename=doc.original_name,
        page_count=doc.page_count,
        word_count=doc.word_count,
        extraction_method=doc.extraction_method,
        storage_path=doc.storage_path,
        preview_text=doc.full_text[:300] + "..." if len(doc.full_text) > 300 else doc.full_text,
    )


@router.get(
    "/",
    response_model=list[PDFListItem],
    summary="List all uploaded documents",
)
async def list_documents(user: AuthenticatedUser = Depends(get_current_user)):
    """Returns all uploaded PDFs for the user."""
    return await pdf_service.list_documents(user.uid)


@router.get(
    "/{document_id}",
    response_model=PDFDocument,
    summary="Get document details and extracted text",
)
async def get_document(
    document_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Returns full document metadata including extracted text content."""
    doc = await pdf_service.get_document(user.uid, document_id)
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found.")
    return doc


@router.delete(
    "/{document_id}",
    response_model=BaseResponse,
    summary="Delete a document",
)
async def delete_document(
    document_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Permanently deletes a document and its extracted content."""
    deleted = await pdf_service.delete_document(user.uid, document_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Document not found.")
    return BaseResponse(message="Document deleted.")
