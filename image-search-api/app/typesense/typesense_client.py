import typesense
from typing import Dict, Any, List
from app.config import settings

class TypesenseClient:
    def __init__(self):
        self.client = typesense.Client({
            'nodes': [{
                'host': settings.TYPESENSE_HOST,
                'port': str(settings.TYPESENSE_PORT),
                'protocol': settings.TYPESENSE_PROTOCOL
            }],
            'api_key': settings.TYPESENSE_API_KEY,
            'connection_timeout_seconds': 2
        })
        self.collection_name = 'unsplash_photos'

    def init_schema(self):
        schema = {
            'name': self.collection_name,
            'fields': [
                {'name': 'photo_id', 'type': 'string'},
                {'name': 'photo_description', 'type': 'string', 'optional': True},
                {'name': 'ai_description', 'type': 'string', 'optional': True},
                {'name': 'photographer_username', 'type': 'string'},
                {'name': 'photo_width', 'type': 'int32'},
                {'name': 'photo_height', 'type': 'int32'},
                {'name': 'photo_image_url', 'type': 'string'},
                {'name': 'photo_url', 'type': 'string', 'optional': True},
                {'name': 'stats_views', 'type': 'int64', 'optional': True},
                {'name': 'stats_downloads', 'type': 'int64', 'optional': True},
                {'name': 'keywords', 'type': 'string[]', 'optional': True},
                {'name': 'colors', 'type': 'string[]', 'optional': True},
                {'name': 'location_city', 'type': 'string', 'optional': True},
                {'name': 'location_country', 'type': 'string', 'optional': True}
            ]
        }

        try:
            self.client.collections[self.collection_name].retrieve()
        except typesense.exceptions.ObjectNotFound:
            self.client.collections.create(schema)

    async def search(self, query: str, page: int, per_page: int) -> List[Dict[str, Any]]:
        try:
            search_parameters = {
                'q': query,
                'query_by': 'photo_description,ai_description,keywords,location_city,location_country',
                'page': page,
                'per_page': per_page
            }
            import asyncio
            response = await asyncio.to_thread(self.client.collections[self.collection_name].documents.search, search_parameters)
            return response.get('hits', [])
        except Exception as e:
            # Add logging here in a real application
            return []

typesense_client = TypesenseClient()
