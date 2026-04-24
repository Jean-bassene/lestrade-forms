"""
Configuration applicative clé-valeur (email utilisateur, préférences…)
"""
from fastapi import APIRouter, Depends
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.database import get_db
from ..core.models import Config
from ..core.schemas import ConfigIn, ConfigOut

router = APIRouter(prefix="/config", tags=["config"])

# Clés autorisées — whitelist stricte (évite key injection)
_ALLOWED_KEYS = {"user_email", "welcome_shown", "theme", "panier_url"}


def _check_key(key: str) -> None:
    if key not in _ALLOWED_KEYS:
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail=f"Clé non autorisée: {key}")


@router.get("/{key}", response_model=ConfigOut)
async def get_config(key: str, db: AsyncSession = Depends(get_db)):
    _check_key(key)
    row = await db.get(Config, key)
    return ConfigOut(key=key, value=row.value if row else None)


@router.put("/{key}", response_model=ConfigOut)
async def set_config(key: str, body: ConfigIn, db: AsyncSession = Depends(get_db)):
    _check_key(key)
    stmt = (
        sqlite_insert(Config)
        .values(key=key, value=body.value)
        .on_conflict_do_update(index_elements=["key"], set_={"value": body.value})
    )
    await db.execute(stmt)
    await db.commit()
    return ConfigOut(key=key, value=body.value)
