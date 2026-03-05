from typing import List, Optional, Tuple, Dict
import asyncio
import json
import hashlib
from redis.asyncio import Redis
from app.config import settings
from app.models.image_models import ImageResult, SearchResponse
from app.typesense.typesense_client import typesense_client
from app.services.provider_router import provider_router
from app.services.rate_limit_manager import rate_limit_manager
from app.utils.response_normalizer import normalize_typesense_result

class SearchService:
    def __init__(self):
        self.redis = Redis.from_url(settings.REDIS_URL, decode_responses=True)

    async def close(self):
        await self.redis.close()

    def _get_cache_key(self, query: str, page: int, per_page: int, orientation: Optional[str], color: Optional[str]) -> str:
        key_str = f"{query}:{page}:{per_page}:{orientation}:{color}"
        return f"search_cache:{hashlib.md5(key_str.encode()).hexdigest()}"

    async def _search_typesense(self, query: str, page: int, per_page: int) -> Tuple[List[ImageResult], List[Dict]]:
        try:
            results = await typesense_client.search(query, page, per_page)
            normalized = [normalize_typesense_result(res) for res in results]
            return normalized, results
        except Exception as e:
            # Handle Typesense error, return empty list
            return [], []

    def deduplicate_results(self, results: List[ImageResult]) -> List[ImageResult]:
        seen = set()
        deduplicated = []
        for result in results:
            if result.image_url not in seen:
                seen.add(result.image_url)
                deduplicated.append(result)
        return deduplicated

    def sort_results(self, results: List[ImageResult], typesense_raw: List[Dict]) -> List[ImageResult]:
        # Sort based on stats if it's from typesense, otherwise keep order

        # Create a mapping for fast lookup
        stats_map = {}
        for raw in typesense_raw:
            doc = raw.get('document', {})
            ts_id = f"typesense_{doc.get('photo_id')}"
            stats_downloads = doc.get("stats_downloads") or 0
            stats_views = doc.get("stats_views") or 0
            stats_map[ts_id] = (stats_downloads, stats_views)

        def get_sort_key(item: ImageResult):
            # Sort primary by downloads, secondary by views for Typesense
            # External APIs results are kept at end or interwoven based on requirements.
            # We'll prioritize Typesense items that have stats.
            if item.source == "typesense" and item.id in stats_map:
                downloads, views = stats_map[item.id]
                return (downloads, views)
            return (-1, -1) # Send to bottom or keep relative if not having stats

        return sorted(results, key=get_sort_key, reverse=True)


    async def search(
        self,
        query: str,
        page: int,
        per_page: int,
        orientation: Optional[str] = None,
        color: Optional[str] = None
    ) -> SearchResponse:

        # Check cache
        cache_key = self._get_cache_key(query, page, per_page, orientation, color)
        try:
            cached_data = await self.redis.get(cache_key)
            if cached_data:
                return SearchResponse.model_validate_json(cached_data)
        except Exception:
            pass # Ignore cache read errors

        # 1. Default Search (Typesense)
        typesense_results, typesense_raw = await self._search_typesense(query, page, per_page)

        # 2. External Provider
        external_results = []
        provider_name = None

        excluded_providers = []

        while True:
            provider = await provider_router.get_random_provider(exclude=excluded_providers)
            if not provider:
                break

            try:
                # Track request
                await rate_limit_manager.increment_usage(provider)

                # Fetch
                external_results = await provider.search(
                    query=query,
                    page=page,
                    per_page=per_page,
                    orientation=orientation,
                    color=color
                )
                provider_name = provider.provider_name
                break # Success
            except Exception as e:
                # Add to excluded and try next
                excluded_providers.append(provider.provider_name)

        # 3. Merge Results
        merged = typesense_results + external_results

        # 4. Deduplicate
        deduplicated = self.deduplicate_results(merged)

        # 5. Sort
        sorted_results = self.sort_results(deduplicated, typesense_raw)

        # Build Sources counts
        sources = {"typesense": len([r for r in deduplicated if r.source == "typesense"])}
        if provider_name:
            sources[provider_name] = len([r for r in deduplicated if r.source == provider_name])

        response = SearchResponse(
            query=query,
            results=sorted_results,
            sources=sources
        )

        # Save to cache
        try:
            await self.redis.setex(cache_key, 3600, response.model_dump_json())
        except Exception:
            pass # Ignore cache write errors

        return response

search_service = SearchService()
