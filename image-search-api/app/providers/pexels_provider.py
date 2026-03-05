from typing import List, Optional
from app.providers.base_provider import BaseProvider
from app.models.image_models import ImageResult
from app.config import settings

class PexelsProvider(BaseProvider):
    @property
    def provider_name(self) -> str:
        return "pexels"

    @property
    def limit_per_hour(self) -> int:
        return 200 # Standard Pexels tier

    async def search(
        self,
        query: str,
        page: int,
        per_page: int,
        orientation: Optional[str] = None,
        color: Optional[str] = None
    ) -> List[ImageResult]:
        if not settings.PEXELS_API_KEY:
            return []

        url = "https://api.pexels.com/v1/search"
        headers = {
            "Authorization": settings.PEXELS_API_KEY
        }
        params = {
            "query": query,
            "page": page,
            "per_page": per_page,
        }

        # Pexels supports orientation and color parameters directly
        if orientation:
            if orientation in ["landscape", "portrait", "square"]:
                params["orientation"] = orientation
        if color:
            params["color"] = color

        try:
            response = await self.client.get(url, headers=headers, params=params)
            response.raise_for_status()
            data = response.json()

            results = []
            for item in data.get("photos", []):
                # Pexels photos are generally all free
                premium = False

                result = ImageResult(
                    id=f"pexels_{item['id']}",
                    title=item.get("alt", ""),
                    description=item.get("alt", ""),
                    image_url=item["src"]["original"], # or large
                    thumbnail_url=item["src"]["medium"],
                    width=item["width"],
                    height=item["height"],
                    photographer=item["photographer"],
                    source=self.provider_name,
                    premium=premium,
                    tags=[] # Pexels API does not expose tags directly on search results
                )
                results.append(result)
            return results
        except Exception as e:
            # Re-raise so the router can catch and try another provider
            raise
