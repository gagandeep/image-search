#!/usr/bin/env python3
"""
Export all photo documents from local Postgres to a JSONL file suitable for
Typesense bulk import.

Usage:
    python scripts/export_jsonl.py                        # writes unsplash_photos.jsonl
    python scripts/export_jsonl.py --output /tmp/out.jsonl
    python scripts/export_jsonl.py --batch-size 5000

The script reads POSTGRES_URL from .env (or the environment). It does NOT
touch Typesense at all — it just produces the JSONL dump.
"""
import argparse
import asyncio
import json
import os
import sys

# Load environment variables from .env file
from dotenv import load_dotenv
load_dotenv()

from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

BATCH_SIZE = 2000

QUERY = """
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
        array_agg(DISTINCT k.keyword) FILTER (WHERE k.keyword IS NOT NULL) AS keywords,
        array_agg(DISTINCT c.hex)     FILTER (WHERE c.hex IS NOT NULL)     AS colors
    FROM unsplash_photos p
    LEFT JOIN unsplash_keywords k ON p.photo_id = k.photo_id
    LEFT JOIN unsplash_colors   c ON p.photo_id = c.photo_id
    GROUP BY p.photo_id
"""


def row_to_doc(row) -> dict:
    doc: dict = {
        "photo_id":             row.photo_id,
        "photographer_username": row.photographer_username or "Unknown",
        "photo_width":          row.photo_width  or 0,
        "photo_height":         row.photo_height or 0,
        "photo_image_url":      row.photo_image_url or "",
    }
    for field in (
        "photo_description", "ai_description", "photo_url",
        "stats_views", "stats_downloads", "keywords", "colors",
    ):
        val = getattr(row, field, None)
        if val is not None:
            doc[field] = val
    return doc


async def export(output_path: str, batch_size: int) -> int:
    postgres_url = os.environ.get("POSTGRES_URL")
    if not postgres_url:
        raise ValueError("POSTGRES_URL environment variable is required")

    engine = create_async_engine(postgres_url, echo=False)
    total = 0

    print(f"Connecting to Postgres: {postgres_url[:40]}…")
    async with engine.connect() as conn:
        print("Running query (this may take a while for large datasets)…")
        result = await conn.execute(text(QUERY))

        with open(output_path, "w", encoding="utf-8") as f:
            batch = result.fetchmany(batch_size)
            while batch:
                for row in batch:
                    f.write(json.dumps(row_to_doc(row)) + "\n")
                total += len(batch)
                print(f"  exported {total:,} rows…", end="\r")
                batch = result.fetchmany(batch_size)

    print(f"\nDone — {total:,} documents written to {output_path}")
    return total


def main():
    parser = argparse.ArgumentParser(description="Export Postgres → Typesense JSONL")
    parser.add_argument("--output",     default="unsplash_photos.jsonl", help="Output JSONL file path")
    parser.add_argument("--batch-size", type=int, default=BATCH_SIZE,    help="Rows per fetch batch")
    args = parser.parse_args()

    asyncio.run(export(args.output, args.batch_size))


if __name__ == "__main__":
    main()
