"""
Connexion SQLite — même base que l'app R (questionnaires.db)
SQLAlchemy async pour FastAPI
"""
import os
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase

DB_PATH      = os.getenv("LESTRADE_DB_PATH", "questionnaires.db")
DATABASE_URL = f"sqlite+aiosqlite:///{DB_PATH}"

engine            = create_async_engine(DATABASE_URL, echo=False)
AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


async def get_db():
    async with AsyncSessionLocal() as session:
        yield session


_MIGRATIONS = [
    # Colonnes ajoutées après la création initiale par l'app R
    "ALTER TABLE reponses ADD COLUMN uuid TEXT",
    "ALTER TABLE questions ADD COLUMN role_analytique TEXT",
    # Table config (nouvelle — Python uniquement)
    """CREATE TABLE IF NOT EXISTS config (
        key   TEXT PRIMARY KEY,
        value TEXT
    )""",
]


async def init_db():
    """Crée les tables si absentes et applique les migrations."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        for stmt in _MIGRATIONS:
            try:
                await conn.execute(text(stmt))
            except Exception:
                pass   # colonne ou table déjà existante → on ignore
