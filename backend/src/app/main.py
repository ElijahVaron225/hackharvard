from __future__ import annotations

import os
from typing import Literal
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

APP_NAME = os.getenv("APP_NAME", "FastAPI Minimal")
API_V1_PREFIX = os.getenv("API_V1_PREFIX", "/api/v1")
_CORS = os.getenv("BACKEND_CORS_ORIGINS", "")  # "http://localhost:3000,http://127.0.0.1:3000"

def _parse_origins(raw: str) -> list[str]:
    return [o.strip() for o in raw.split(",") if o.strip()]

def create_app() -> FastAPI:
    app = FastAPI(title=APP_NAME)

    origins = _parse_origins(_CORS)
    if origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=origins,
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )

    @app.get(f"{API_V1_PREFIX}/healthz")
    def healthz() -> dict[Literal["status"], Literal["ok"]]:
        return {"status": "ok"}

    return app

app = create_app()