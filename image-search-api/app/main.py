from fastapi import FastAPI
from contextlib import asynccontextmanager
from app.api.search import router as search_router
from app.services.provider_router import provider_router
from app.services.rate_limit_manager import rate_limit_manager

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup:
    yield
    # Shutdown: clean up connections
    from app.services.search_service import search_service
    await provider_router.close_all()
    await rate_limit_manager.close()
    await search_service.close()

app = FastAPI(
    title="Royalty-Free Image Search API",
    description="A production-grade FastAPI application that provides a unified royalty-free image search API.",
    version="1.0.0",
    lifespan=lifespan
)

app.include_router(search_router, tags=["search"])

@app.get("/health")
async def health_check():
    return {"status": "ok"}
