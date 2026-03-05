import time
from typing import Optional
from redis.asyncio import Redis
from app.config import settings
from app.providers.base_provider import BaseProvider

class RateLimitManager:
    def __init__(self):
        self.redis = Redis.from_url(settings.REDIS_URL, decode_responses=True)

    async def _get_key(self, provider_name: str) -> str:
        current_hour = int(time.time() // 3600)
        return f"ratelimit:{provider_name}:{current_hour}"

    async def has_capacity(self, provider: BaseProvider) -> bool:
        key = await self._get_key(provider.provider_name)
        count = await self.redis.get(key)

        if count is None:
            return True

        return int(count) < provider.limit_per_hour

    async def increment_usage(self, provider: BaseProvider):
        key = await self._get_key(provider.provider_name)

        # Using pipeline for atomicity
        async with self.redis.pipeline(transaction=True) as pipe:
            await pipe.incr(key)
            await pipe.expire(key, 3600) # Expire in 1 hour
            await pipe.execute()

    async def get_remaining_quota(self, provider: BaseProvider) -> int:
        key = await self._get_key(provider.provider_name)
        count = await self.redis.get(key)

        if count is None:
            return provider.limit_per_hour

        remaining = provider.limit_per_hour - int(count)
        return max(0, remaining)

    async def close(self):
        await self.redis.close()

rate_limit_manager = RateLimitManager()
