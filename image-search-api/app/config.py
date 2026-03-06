from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Provider API Keys
    UNSPLASH_API_KEY: str = ""
    PEXELS_API_KEY: str = ""
    PIXABAY_API_KEY: str = ""
    FREEPIK_API_KEY: str = ""

    # Database
    POSTGRES_URL: str = "postgresql+asyncpg://user:password@postgres:5432/unsplash"

    # Typesense
    TYPESENSE_HOST: str = "typesense"
    TYPESENSE_PORT: int = 8108
    TYPESENSE_API_KEY: str = "xyz"
    TYPESENSE_PROTOCOL: str = "http"

    # Redis
    REDIS_URL: str = "redis://redis:6379/0"

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")


settings = Settings()
