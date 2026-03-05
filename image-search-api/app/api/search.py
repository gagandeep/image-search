from fastapi import APIRouter, Query, Depends
from typing import Optional
from app.models.image_models import SearchResponse
from app.services.search_service import SearchService
from app.dependencies import get_search_service

router = APIRouter()

@router.get("/search", response_model=SearchResponse)
async def search_images(
    q: str = Query(..., description="Search query string"),
    page: int = Query(1, ge=1, description="Page number"),
    per_page: int = Query(10, ge=1, le=100, description="Items per page"),
    orientation: Optional[str] = Query(None, description="Orientation filter (landscape, portrait, square)"),
    color: Optional[str] = Query(None, description="Color filter"),
    search_service: SearchService = Depends(get_search_service)
):
    return await search_service.search(
        query=q,
        page=page,
        per_page=per_page,
        orientation=orientation,
        color=color
    )
