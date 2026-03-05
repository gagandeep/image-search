from typing import List, Optional
from pydantic import BaseModel, ConfigDict

class ImageResult(BaseModel):
    id: str
    title: Optional[str] = None
    description: Optional[str] = None
    image_url: str
    thumbnail_url: str
    width: int
    height: int
    photographer: str
    source: str
    premium: bool = False
    tags: List[str] = []

    model_config = ConfigDict(from_attributes=True)

class SearchResponse(BaseModel):
    query: str
    results: List[ImageResult]
    sources: dict[str, int]
