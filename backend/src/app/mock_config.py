"""
Mock configuration for Kiri Engine API testing.
This allows you to switch between mock and real API without code changes.
"""

import os
from typing import Optional


class MockConfig:
    """Configuration for mock vs real Kiri Engine API."""
    
    # Mock server settings
    MOCK_SERVER_URL = "http://127.0.0.1:8001"
    USE_MOCK_API = os.getenv("USE_MOCK_KIRI_API", "true").lower() == "true"
    
    # Real API settings (only used when USE_MOCK_API is False)
    REAL_API_URL = "https://api.kiriengine.app"
    REAL_API_KEY = os.getenv("KIRI_API_KEY")
    
    @classmethod
    def get_api_url(cls) -> str:
        """Get the appropriate API URL based on configuration."""
        return cls.MOCK_SERVER_URL if cls.USE_MOCK_API else cls.REAL_API_URL
    
    @classmethod
    def get_api_key(cls) -> Optional[str]:
        """Get the appropriate API key based on configuration."""
        if cls.USE_MOCK_API:
            return "mock-api-key"  # Mock key for testing
        return cls.REAL_API_KEY
    
    @classmethod
    def is_mock_mode(cls) -> bool:
        """Check if running in mock mode."""
        return cls.USE_MOCK_API
    
    @classmethod
    def get_headers(cls) -> dict:
        """Get appropriate headers based on configuration."""
        if cls.USE_MOCK_API:
            return {
                "Content-Type": "application/x-www-form-urlencoded"
            }
        else:
            return {
                "Authorization": f"Bearer {cls.get_api_key()}",
                "Content-Type": "application/x-www-form-urlencoded"
            }


# Global configuration instance
mock_config = MockConfig()
