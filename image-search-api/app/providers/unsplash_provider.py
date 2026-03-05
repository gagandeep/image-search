from typing import List, Optional
from app.providers.base_provider import BaseProvider
from app.models.image_models import ImageResult
from app.config import settings
import uuid

class UnsplashProvider(BaseProvider):
    @property
    def provider_name(self) -> str:
        return "unsplash"

    @property
    def limit_per_hour(self) -> int:
        return 50 # 50 requests per hour for demo applications

    async def search(
        self,
        query: str,
        page: int,
        per_page: int,
        orientation: Optional[str] = None,
        color: Optional[str] = None
    ) -> List[ImageResult]:
        if not settings.UNSPLASH_API_KEY:
            return []

        url = "https://api.unsplash.com/search/photos"
        headers = {
            "Authorization": f"Client-ID {settings.UNSPLASH_API_KEY}"
        }
        params = {
            "query": query,
            "page": page,
            "per_page": per_page,
        }
        if orientation:
            params["orientation"] = orientation
        if color:
            params["color"] = color

        try:
            response = await self.client.get(url, headers=headers, params=params)
            response.raise_for_status()
            data = response.json()

            results = []
            for item in data.get("results", []):
                # Unsplash results are generally free/premium mix in some datasets, Unsplash+ is premium
                premium = item.get("premium", False)

                tags = [tag.get("title") for tag in item.get("tags", [])]

                result = ImageResult(
                    id=f"unsplash_{item['id']}",
                    title=item.get("alt_description"),
                    description=item.get("description"),
                    image_url=item["urls"]["regular"],
                    thumbnail_url=item["urls"]["thumb"],
                    width=item["width"],
                    height=item["height"],
                    photographer=item["user"]["name"],
                    source=self.provider_name,
                    premium=premium,
                    tags=tags
                )
                results.append(result)
            return results

        except Exception as e:
            # Handle logging in production
            return []
