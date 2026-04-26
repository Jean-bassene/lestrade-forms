"""
Endpoints admin — sauvegarde et restauration de la base SQLite.
Accessible uniquement en local (127.0.0.1).
"""
import os
import shutil
import tempfile

from fastapi import APIRouter, HTTPException, Request, UploadFile, File
from fastapi.responses import FileResponse
from starlette.background import BackgroundTask

from ..core import database as db_module

router = APIRouter(prefix="/admin", tags=["admin"])

_SQLITE_MAGIC  = b"SQLite format 3\x00"
_MAX_RESTORE_MB = 200


def _require_local(request: Request):
    host = request.client.host if request.client else ""
    if host not in ("127.0.0.1", "::1", "localhost"):
        raise HTTPException(status_code=403, detail="Accès local uniquement")


# ── GET /admin/backup ─────────────────────────────────────────────────────────

@router.get("/backup")
async def backup(request: Request):
    _require_local(request)
    db_path = db_module.DB_PATH
    if not os.path.exists(db_path):
        raise HTTPException(status_code=404, detail="Base introuvable")
    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".db")
    tmp.close()
    shutil.copy2(db_path, tmp.name)
    return FileResponse(
        tmp.name,
        media_type="application/octet-stream",
        filename="lestrade_backup.db",
        background=BackgroundTask(os.unlink, tmp.name),
    )


# ── POST /admin/restore ───────────────────────────────────────────────────────

@router.post("/restore")
async def restore(request: Request, file: UploadFile = File(...)):
    _require_local(request)
    content = await file.read()

    if len(content) > _MAX_RESTORE_MB * 1024 * 1024:
        raise HTTPException(status_code=413,
                            detail=f"Fichier trop volumineux (max {_MAX_RESTORE_MB} MB)")
    if len(content) < 16 or content[:16] != _SQLITE_MAGIC:
        raise HTTPException(status_code=400,
                            detail="Fichier invalide — ce n'est pas une base SQLite")

    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".db")
    try:
        tmp.write(content)
        tmp.close()
        await db_module.swap_database(tmp.name)
    except Exception:
        tmp.close()
        if os.path.exists(tmp.name):
            os.unlink(tmp.name)
        raise HTTPException(status_code=500, detail="Erreur lors de la restauration")

    return {"status": "ok", "message": "Base restaurée avec succès"}
