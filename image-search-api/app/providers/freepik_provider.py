from typing import List, Optional
from app.providers.base_provider import BaseProvider
from app.models.image_models import ImageResult
from app.config import settings

class FreepikProvider(BaseProvider):
    @property
    def provider_name(self) -> str:
        return "freepik"

    @property
    def limit_per_hour(self) -> int:
        return 50 # Example limit

    async def search(
        self,
        query: str,
        page: int,
        per_page: int,
        orientation: Optional[str] = None,
        color: Optional[str] = None
    ) -> List[ImageResult]:
        if not settings.FREEPIK_API_KEY:
            return []

        url = "https://api.freepik.com/v1/resources"
        headers = {
            "x-freepik-api-key": settings.FREEPIK_API_KEY,
            "Accept-Language": "en-US",
            "Accept": "application/json"
        }
        params = {
            "locale": "en-US",
            "page": page,
            "limit": min(per_page, 100),
            "term": query,
            "filters[content_type][photo]": 1
        }

        # Mapping orientation for Freepik: horizontal, vertical, square, panoramic
        if orientation:
            if orientation == "landscape":
                params["filters[orientation][horizontal]"] = 1
            elif orientation == "portrait":
                params["filters[orientation][vertical]"] = 1
            elif orientation == "square":
                params["filters[orientation][square]"] = 1
        if color:
            params["filters[color]"] = color

        try:
            response = await self.client.get(url, headers=headers, params=params)
            response.raise_for_status()
            data = response.json()

            results = []
            for item in data.get("data", []):
                # Freepik indicates premium flag
                premium = item.get("premium", False)

                tags = [t for t in item.get("tags", [])]

                # Use large image if available, else standard image
                image = item.get("image", {})
                image_url = image.get("source", {}).get("url", "")

                # Thumbnail might not be directly available or is standard image
                thumbnail_url = image.get("source", {}).get("url", "")

                result = ImageResult(
                    id=f"freepik_{item['id']}",
                    title=item.get("title", ""),
                    description=item.get("title", ""),
                    image_url=image_url,
                    thumbnail_url=thumbnail_url,
                    width=image.get("meta", {}).get("width", 0),
                    height=image.get("meta", {}).get("height", 0),
                    photographer=item.get("author", {}).get("name", "Unknown"),
                    source=self.provider_name,
                    premium=premium,
                    tags=tags
                )
                results.append(result)
            return results
        except Exception as e:
            # Handle logging in production
            return []
