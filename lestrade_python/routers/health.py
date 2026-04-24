import os
from datetime import datetime, timezone
from fastapi import APIRouter
from ..core.schemas import HealthOut

router = APIRouter()

@router.get("/health", response_model=HealthOut, tags=["système"])
async def health():
    db_path = os.getenv("LESTRADE_DB_PATH", "questionnaires.db")
    return HealthOut(
        status  = "ok",
        version = "2.0-python",
        db      = os.path.exists(db_path),
        ts      = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    )
