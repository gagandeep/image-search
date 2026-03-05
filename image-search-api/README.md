# Royalty-Free Image Search API

A production-grade FastAPI application providing a unified image search API aggregating results from a local Typesense index (Unsplash Lite dataset) and multiple third-party image providers (Unsplash, Pexels, Pixabay, Freepik).

## Features
- Aggregates search results from multiple sources
- Defaults to a local Typesense index
- Rate limits aware provider routing (using Redis)
- Deduplication and Sorting
- Async non-blocking architecture

## Setup

1. Configure `.env` based on `env.example`.
2. Run `docker-compose up -d`.
3. The API will be available at `http://localhost:8000/docs`.

### Database and Typesense population
1. Load your Unsplash Lite dataset into the PostgreSQL container.
2. Run the ingestion script:
```bash
docker-compose exec api python scripts/populate_typesense.py
```
