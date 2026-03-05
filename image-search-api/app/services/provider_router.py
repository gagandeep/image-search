from typing import List, Optional
import random
from app.providers.base_provider import BaseProvider
from app.providers.unsplash_provider import UnsplashProvider
from app.providers.pexels_provider import PexelsProvider
from app.providers.pixabay_provider import PixabayProvider
from app.providers.freepik_provider import FreepikProvider
from app.services.rate_limit_manager import rate_limit_manager

class ProviderRouter:
    def __init__(self):
        self.providers: List[BaseProvider] = [
            UnsplashProvider(),
            PexelsProvider(),
            PixabayProvider(),
            FreepikProvider()
        ]

    async def get_available_providers(self) -> List[BaseProvider]:
        available = []
        for provider in self.providers:
            if await rate_limit_manager.has_capacity(provider):
                available.append(provider)
        return available

    async def get_random_provider(self, exclude: List[str] = None) -> Optional[BaseProvider]:
        if exclude is None:
            exclude = []

        available = await self.get_available_providers()

        # Filter out excluded
        available = [p for p in available if p.provider_name not in exclude]

        if not available:
            return None

        # Select randomly
        return random.choice(available)

    async def close_all(self):
        for p in self.providers:
            await p.close()

provider_router = ProviderRouter()
