"""Application configuration for different environments."""
import os
from functools import lru_cache
from typing import Optional
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""
    
    # Environment
    environment: str = "development"
    debug: bool = True
    
    # API Settings
    api_title: str = "Famba Rider API"
    api_version: str = "1.0.0"
    api_prefix: str = ""
    
    # Security
    secret_key: str = "your-secret-key-change-in-production"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 7
    
    # Basic Auth (legacy, for backward compatibility)
    basic_user: str = "demo"
    basic_pass: str = "demo123"
    
    # Database
    database_url: str = "sqlite:///./famba.db"
    database_echo: bool = False
    
    # PostgreSQL specific (used when database_url starts with postgresql)
    postgres_host: str = "localhost"
    postgres_port: int = 5432
    postgres_user: str = "famba"
    postgres_password: str = "famba_secret"
    postgres_db: str = "famba"
    
    # Redis (for caching/sessions)
    redis_url: Optional[str] = None
    
    # External Services
    sms_provider: Optional[str] = None  # twilio, africas_talking
    sms_api_key: Optional[str] = None
    sms_api_secret: Optional[str] = None
    
    # Payment
    stripe_secret_key: Optional[str] = None
    stripe_webhook_secret: Optional[str] = None
    
    # Maps
    map_tile_key: Optional[str] = None
    osrm_base_url: str = "https://router.project-osrm.org"
    
    # CORS
    cors_origins: str = "*"
    
    @property
    def is_production(self) -> bool:
        return self.environment == "production"
    
    @property
    def is_development(self) -> bool:
        return self.environment == "development"
    
    @property
    def is_testing(self) -> bool:
        return self.environment == "testing"
    
    @property
    def use_postgres(self) -> bool:
        return self.database_url.startswith("postgresql")
    
    @property
    def postgres_dsn(self) -> str:
        """Build PostgreSQL connection string."""
        return f"postgresql://{self.postgres_user}:{self.postgres_password}@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False


class DevelopmentSettings(Settings):
    """Development environment settings."""
    environment: str = "development"
    debug: bool = True
    database_url: str = "sqlite:///./famba.db"
    database_echo: bool = True


class StagingSettings(Settings):
    """Staging environment settings."""
    environment: str = "staging"
    debug: bool = True


class ProductionSettings(Settings):
    """Production environment settings."""
    environment: str = "production"
    debug: bool = False
    database_echo: bool = False


class TestingSettings(Settings):
    """Testing environment settings."""
    environment: str = "testing"
    debug: bool = True
    database_url: str = "sqlite:///./test_famba.db"


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings based on environment."""
    env = os.getenv("ENVIRONMENT", "development").lower()
    
    settings_map = {
        "development": DevelopmentSettings,
        "staging": StagingSettings,
        "production": ProductionSettings,
        "testing": TestingSettings,
    }
    
    settings_class = settings_map.get(env, DevelopmentSettings)
    return settings_class()


# Global settings instance
settings = get_settings()

