"""
Connexion SQLite — même base que l'app R (questionnaires.db)
SQLAlchemy async pour FastAPI
"""
import os
from sqlalchemy import text, event
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase

DB_PATH      = os.getenv("LESTRADE_DB_PATH", "questionnaires.db")
DATABASE_URL = f"sqlite+aiosqlite:///{DB_PATH}"

engine            = create_async_engine(DATABASE_URL, echo=False)
AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


# SQLite désactive les FK par défaut — on les active sur chaque connexion.
# Sans ça, DELETE questionnaire ne cascade pas aux sections/questions/réponses.
@event.listens_for(engine.sync_engine, "connect")
def _enable_fk(dbapi_conn, _):
    cursor = dbapi_conn.cursor()
    cursor.execute("PRAGMA foreign_keys=ON")
    cursor.close()


async def get_db():
    async with AsyncSessionLocal() as session:
        yield session


# ── Migration AUTOINCREMENT ───────────────────────────────────────────────────
# SQLite ne supporte pas ALTER COLUMN → on recrée les tables.
# Ordre : feuilles d'abord (FK vérifiées à l'INSERT, pas au RENAME/DROP),
# puis parents — ce qui évite toute violation pendant la migration.

_AUTOINCREMENT_DDL = [
    ("reponses", """CREATE TABLE reponses (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        questionnaire_id INTEGER NOT NULL REFERENCES questionnaires(id) ON DELETE CASCADE,
        horodateur       DATETIME DEFAULT CURRENT_TIMESTAMP,
        donnees_json     TEXT NOT NULL,
        uuid             TEXT UNIQUE
    )"""),
    ("questions", """CREATE TABLE questions (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        section_id      INTEGER NOT NULL REFERENCES sections(id) ON DELETE CASCADE,
        type            TEXT NOT NULL,
        texte           TEXT NOT NULL,
        options         TEXT,
        role_analytique TEXT,
        obligatoire     INTEGER DEFAULT 0,
        ordre           INTEGER DEFAULT 1
    )"""),
    ("sections", """CREATE TABLE sections (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        questionnaire_id INTEGER NOT NULL REFERENCES questionnaires(id) ON DELETE CASCADE,
        nom              TEXT NOT NULL,
        ordre            INTEGER DEFAULT 1
    )"""),
    ("questionnaires", """CREATE TABLE questionnaires (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        nom           TEXT NOT NULL,
        description   TEXT,
        owner_email   TEXT,
        date_creation DATETIME DEFAULT CURRENT_TIMESTAMP
    )"""),
]


async def _repair_stale_fk_refs(conn) -> None:
    """Répare les FK brisées laissées par une migration incomplète.
    Symptôme : sections/questions/réponses référencent _*_mig au lieu des vraies tables.
    Idempotent — ne fait rien si les FK sont déjà correctes."""
    import os, traceback
    log_path = os.path.join(
        os.environ.get("APPDATA", ""), "LestradeForms", "migration.log"
    )
    def _log(msg: str):
        try:
            with open(log_path, "a", encoding="utf-8") as f:
                import datetime
                f.write(f"[{datetime.datetime.now().isoformat()}] {msg}\n")
        except Exception:
            pass

    # Tables à vérifier : (nom, DDL correct, table_parent_correcte)
    tables_to_check = [
        ("sections",  _AUTOINCREMENT_DDL[2][1],  "_questionnaires_mig"),
        ("questions", _AUTOINCREMENT_DDL[1][1],  "_sections_mig"),
        ("reponses",  _AUTOINCREMENT_DDL[0][1],  "_questionnaires_mig"),
    ]
    stale_mig_tables = ["_reponses_mig", "_questions_mig", "_sections_mig", "_questionnaires_mig"]

    needs_repair = False
    for table, _, stale_ref in tables_to_check:
        sql = (await conn.execute(
            text("SELECT sql FROM sqlite_master WHERE type='table' AND name=:t"),
            {"t": table},
        )).scalar()
        if sql and stale_ref.lower() in sql.lower():
            needs_repair = True
            break

    if not needs_repair:
        return

    _log("_repair_stale_fk_refs : réparation FK brisées démarrée")
    try:
        await conn.execute(text("PRAGMA foreign_keys=OFF"))
        await conn.execute(text("PRAGMA legacy_alter_table=ON"))

        # Récupère les données de _sections_mig si elles existent
        sections_mig_rows = []
        has_sections_mig = (await conn.execute(
            text("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='_sections_mig'")
        )).scalar()
        if has_sections_mig:
            rows = (await conn.execute(text("SELECT id, questionnaire_id, nom, ordre FROM _sections_mig"))).fetchall()
            sections_mig_rows = list(rows)

        # Recrée sections, questions, réponses avec les bonnes FK
        for table, ddl in [
            ("sections",  _AUTOINCREMENT_DDL[2][1]),
            ("questions", _AUTOINCREMENT_DDL[1][1]),
            ("reponses",  _AUTOINCREMENT_DDL[0][1]),
        ]:
            sql = (await conn.execute(
                text("SELECT sql FROM sqlite_master WHERE type='table' AND name=:t"),
                {"t": table},
            )).scalar()
            if not sql:
                continue
            tmp = f"_{table}_repair"
            await conn.execute(text(f"ALTER TABLE \"{table}\" RENAME TO \"{tmp}\""))
            await conn.execute(text(ddl))
            # Copie les données existantes (s'il y en a)
            await conn.execute(text(f"INSERT OR IGNORE INTO {table} SELECT * FROM \"{tmp}\""))
            await conn.execute(text(f"DROP TABLE IF EXISTS \"{tmp}\""))
            _log(f"  {table} → FK réparée ✓")

        # Récupère les lignes orphelines de _sections_mig dans sections
        if sections_mig_rows:
            for row in sections_mig_rows:
                q_exists = (await conn.execute(
                    text("SELECT id FROM questionnaires WHERE id=:qid"),
                    {"qid": row[1]},
                )).scalar()
                if q_exists:
                    await conn.execute(
                        text("INSERT OR IGNORE INTO sections(id, questionnaire_id, nom, ordre) VALUES(:id,:qid,:nom,:ord)"),
                        {"id": row[0], "qid": row[1], "nom": row[2], "ord": row[3]},
                    )
            _log(f"  _sections_mig → {len(sections_mig_rows)} ligne(s) récupérée(s) ✓")

        # Supprime les tables _*_mig résiduelles
        for t in stale_mig_tables:
            exists = (await conn.execute(
                text("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name=:t"),
                {"t": t},
            )).scalar()
            if exists:
                await conn.execute(text(f"DROP TABLE IF EXISTS \"{t}\""))
                _log(f"  {t} → supprimée ✓")

        await conn.execute(text("PRAGMA legacy_alter_table=OFF"))
        await conn.execute(text("PRAGMA foreign_keys=ON"))
        _log("_repair_stale_fk_refs : terminé ✓")
    except Exception:
        _log(f"ERREUR _repair_stale_fk_refs :\n{traceback.format_exc()}")
        await conn.execute(text("PRAGMA foreign_keys=ON"))


async def _ensure_autoincrement(conn) -> None:
    """Migre les tables sans AUTOINCREMENT vers AUTOINCREMENT.
    Idempotent : skip si déjà migré ou si la table n'existe pas encore.
    Non-fatale : toute erreur est loggée dans APPDATA/LestradeForms/migration.log."""
    import os, traceback
    log_path = os.path.join(
        os.environ.get("APPDATA", ""), "LestradeForms", "migration.log"
    )
    def _log(msg: str):
        try:
            with open(log_path, "a", encoding="utf-8") as f:
                import datetime
                f.write(f"[{datetime.datetime.now().isoformat()}] {msg}\n")
        except Exception:
            pass

    _log("_ensure_autoincrement démarré")
    try:
        # Empêche SQLite 3.26+ de mettre à jour automatiquement les références FK
        # dans les tables enfants quand on renomme une table parent.
        # Sans ça, RENAME questionnaires → _questionnaires_mig met à jour les FK de
        # sections/réponses, qui se retrouvent à référencer _questionnaires_mig après
        # que cette table temporaire est supprimée.
        await conn.execute(text("PRAGMA legacy_alter_table=ON"))
        for table, ddl in _AUTOINCREMENT_DDL:
            existing = (await conn.execute(
                text("SELECT sql FROM sqlite_master WHERE type='table' AND name=:t"),
                {"t": table},
            )).scalar()
            if existing is None or "AUTOINCREMENT" in existing.upper():
                _log(f"  {table} → skip (absent ou déjà AUTOINCREMENT)")
                continue
            _log(f"  {table} → migration en cours…")
            tmp = f"_{table}_mig"
            await conn.execute(text(f"ALTER TABLE {table} RENAME TO {tmp}"))
            await conn.execute(text(ddl))
            await conn.execute(text(f"INSERT INTO {table} SELECT * FROM {tmp}"))
            await conn.execute(text(f"DROP TABLE {tmp}"))
            _log(f"  {table} → migré ✓")
        await conn.execute(text("PRAGMA legacy_alter_table=OFF"))
        _log("_ensure_autoincrement terminé ✓")
    except Exception:
        _log(f"ERREUR _ensure_autoincrement :\n{traceback.format_exc()}")
        await conn.execute(text("PRAGMA legacy_alter_table=OFF"))


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
    # Nettoyage des orphelins issus d'anciennes suppressions sans CASCADE
    "DELETE FROM sections  WHERE questionnaire_id NOT IN (SELECT id FROM questionnaires)",
    "DELETE FROM questions WHERE section_id       NOT IN (SELECT id FROM sections)",
    "DELETE FROM reponses  WHERE questionnaire_id NOT IN (SELECT id FROM questionnaires)",
]


async def init_db():
    """Crée les tables si absentes et applique les migrations."""
    async with engine.begin() as conn:
        await _repair_stale_fk_refs(conn)   # répare les FK brisées par l'ancienne migration
        await _ensure_autoincrement(conn)   # avant create_all
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

    # Réattacher le listener FK sur le nouveau moteur
    @event.listens_for(engine.sync_engine, "connect")
    def _enable_fk_new(dbapi_conn, _):
        cursor = dbapi_conn.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

    await init_db()   # ré-applique les migrations si la base restaurée est ancienne
