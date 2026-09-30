import os
from datetime import datetime, timezone

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(
    title="Rakshak-AI Triage & Geospatial Service",
    description="Spatial proximity matching, bed capacity routing, and triage intelligence.",
    version="0.1.0",
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", tags=["Health"])
async def health_check():
    """Health check endpoint for service monitoring."""
    return {
        "status": "ok",
        "service": "rakshak-triage-service",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "environment": os.getenv("DEBUG", "True"),
    }


@app.get("/", tags=["Root"])
async def root():
    """Root entrypoint returning service metadata."""
    return {
        "message": "Rakshak-AI Triage Service is operational.",
        "version": "0.1.0",
        "docs": "/docs",
    }
