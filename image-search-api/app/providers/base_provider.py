from abc import ABC, abstractmethod
from typing import List, Optional
import httpx
from app.models.image_models import ImageResult
from app.config import settings

class BaseProvider(ABC):
    def __init__(self):
        self.client = httpx.AsyncClient(timeout=10.0)

    @property
    @abstractmethod
    def provider_name(self) -> str:
        pass

    @property
    @abstractmethod
    def limit_per_hour(self) -> int:
        pass

    @abstractmethod
    async def search(
        self,
        query: str,
        page: int,
        per_page: int,
        orientation: Optional[str] = None,
        color: Optional[str] = None
    ) -> List[ImageResult]:
        pass

    async def close(self):
        await self.client.aclose()
