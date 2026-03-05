import sys
import os

# Add the project root to the python path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
from app.config import settings
from app.typesense.typesense_client import typesense_client

BATCH_SIZE = 1000

async def populate():
    # Setup Typesense
    typesense_client.init_schema()

    # Connect to PostgreSQL
    engine = create_async_engine(settings.POSTGRES_URL, echo=False)

    print("Fetching data from PostgreSQL...")
    async with engine.connect() as conn:
        query = """
            SELECT
                p.photo_id,
                p.photo_description,
                p.ai_description,
                p.photographer_username,
                p.photo_width,
                p.photo_height,
                p.photo_image_url,
                p.photo_url,
                p.stats_views,
                p.stats_downloads,
                array_agg(DISTINCT k.keyword) filter (where k.keyword is not null) as keywords,
                array_agg(DISTINCT c.hex) filter (where c.hex is not null) as colors
            FROM unsplash_photos p
            LEFT JOIN unsplash_keywords k ON p.photo_id = k.photo_id
            LEFT JOIN unsplash_colors c ON p.photo_id = c.photo_id
            GROUP BY p.photo_id
        """
        result = await conn.execute(text(query))
        rows = result.fetchall()

    print(f"Found {len(rows)} records. Importing to Typesense...")

    documents = []
    for row in rows:
        # Construct the document
        doc = {
            "photo_id": row.photo_id,
            "photographer_username": row.photographer_username or "Unknown",
            "photo_width": row.photo_width or 0,
            "photo_height": row.photo_height or 0,
            "photo_image_url": row.photo_image_url or "",
        }

        # Handle optional fields safely
        if row.photo_description:
            doc["photo_description"] = row.photo_description
        if row.ai_description:
            doc["ai_description"] = row.ai_description
        if row.photo_url:
            doc["photo_url"] = row.photo_url
        if row.stats_views is not None:
            doc["stats_views"] = row.stats_views
        if row.stats_downloads is not None:
            doc["stats_downloads"] = row.stats_downloads
        if row.keywords:
            doc["keywords"] = row.keywords
        if row.colors:
            doc["colors"] = row.colors

        documents.append(doc)

        if len(documents) >= BATCH_SIZE:
            typesense_client.client.collections[typesense_client.collection_name].documents.import_(
                documents, {'action': 'upsert'}
            )
            print(f"Imported {len(documents)} documents...")
            documents = []

    # Import remaining
    if documents:
        typesense_client.client.collections[typesense_client.collection_name].documents.import_(
            documents, {'action': 'upsert'}
        )
        print(f"Imported remaining {len(documents)} documents.")

    print("Done populating Typesense.")

if __name__ == "__main__":
    asyncio.run(populate())
