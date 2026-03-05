from typing import List, Dict, Any
from app.models.image_models import ImageResult

def normalize_typesense_result(result: Dict[str, Any]) -> ImageResult:
    doc = result.get('document', {})

    # Typesense returns everything as document, sometimes within highlights
    tags = doc.get("keywords", [])

    return ImageResult(
        id=f"typesense_{doc.get('photo_id')}",
        title=doc.get("photo_description", ""),
        description=doc.get("ai_description", doc.get("photo_description", "")),
        image_url=doc.get("photo_image_url", ""),
        thumbnail_url=doc.get("photo_url", doc.get("photo_image_url", "")), # fallback
        width=doc.get("photo_width", 0),
        height=doc.get("photo_height", 0),
        photographer=doc.get("photographer_username", "Unknown"),
        source="typesense",
        premium=False,
        tags=tags
    )
