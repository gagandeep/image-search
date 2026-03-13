from typing import List, Optional
from app.providers.base_provider import BaseProvider
from app.models.image_models import ImageResult
from app.config import settings

class PixabayProvider(BaseProvider):
    @property
    def provider_name(self) -> str:
        return "pixabay"

    @property
    def limit_per_hour(self) -> int:
        return 5000 # Pixabay offers 5000 requests per hour

    @property
    def is_enabled(self) -> bool:
        return bool(settings.PIXABAY_API_KEY)

    async def search(
        self,
        query: str,
        page: int,
        per_page: int,
        orientation: Optional[str] = None,
        color: Optional[str] = None
    ) -> List[ImageResult]:
        if not settings.PIXABAY_API_KEY:
            return []

        url = "https://pixabay.com/api/"
        params = {
            "key": settings.PIXABAY_API_KEY,
            "q": query,
            "page": page,
            "per_page": min(per_page, 200), # Pixabay max per_page is 200
            "image_type": "photo"
        }

        # Pixabay maps orientation slightly differently: "all", "horizontal", "vertical"
        if orientation:
            if orientation == "landscape":
                params["orientation"] = "horizontal"
            elif orientation == "portrait":
                params["orientation"] = "vertical"
        if color:
            params["colors"] = color

        try:
            response = await self.client.get(url, params=params)
            response.raise_for_status()
            data = response.json()

            results = []
            for item in data.get("hits", []):
                # Pixabay hits are free
                premium = False

                # Tags come as comma separated string
                tags = [t.strip() for t in item.get("tags", "").split(",") if t.strip()]

                result = ImageResult(
                    id=f"pixabay_{item['id']}",
                    title=f"Pixabay photo {item['id']}",
                    description=f"Pixabay photo by {item['user']}",
                    image_url=item.get("largeImageURL", item.get("webformatURL", "")),
                    thumbnail_url=item.get("previewURL", ""),
                    width=item["imageWidth"],
                    height=item["imageHeight"],
                    photographer=item["user"],
                    source=self.provider_name,
                    premium=premium,
                    tags=tags
                )
                results.append(result)
            return results
        except Exception as e:
            # Re-raise so the router can catch and try another provider
            raise
