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
    # Table demandes de licence
    """CREATE TABLE IF NOT EXISTS licence_requests (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        nom              TEXT NOT NULL,
        email            TEXT NOT NULL,
        formule          TEXT NOT NULL,
        promo_code       TEXT,
        promo_discount   INTEGER,
        statut           TEXT DEFAULT 'en_attente',
        cle              TEXT,
        num_recu         TEXT,
        date_demande     DATETIME DEFAULT CURRENT_TIMESTAMP,
        date_validation  DATETIME
    )""",
    # Index unique sur num_recu (la colonne est déjà dans le CREATE TABLE ci-dessus)
    "CREATE UNIQUE INDEX IF NOT EXISTS idx_licence_requests_num_recu ON licence_requests(num_recu) WHERE num_recu IS NOT NULL",
    # Isolation légère — propriétaire du questionnaire (NULL = visible par tous)
    "ALTER TABLE questionnaires ADD COLUMN owner_email TEXT",
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


async def swap_database(new_db_path: str) -> None:
    """Remplace la base courante par new_db_path (pour restauration).
    Dispose le moteur, swap les fichiers, puis recrée le moteur.
    ATTENTION : toute session active au moment de l'appel sera interrompue.
    À n'invoquer que depuis l'onglet Admin (mono-utilisateur local)."""
    import shutil
    global engine, AsyncSessionLocal
    await engine.dispose()
    shutil.copy2(DB_PATH, DB_PATH + ".bak")   # sauvegarde de sécurité
    shutil.move(new_db_path, DB_PATH)
    engine            = create_async_engine(DATABASE_URL, echo=False)
    AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)
    await init_db()   # ré-applique les migrations si la base restaurée est ancienne
