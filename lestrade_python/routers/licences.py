"""
Router licences — CRUD demandes de licence, génération et validation de clés.
Toute la logique est locale (SQLite), aucune dépendance Apps Script.
"""
import re
import secrets
from datetime import datetime, timezone

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.database import get_db
from ..core.models import LicenceRequest
from ..core import mailer, notifier

router = APIRouter(prefix="/licences", tags=["licences"])


_EMAIL_RE = re.compile(r"^[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}$")


def _generate_key() -> str:
    """Génère une clé au format LEST-XXXX-XXXX-XXXX-XXXX (128 bits d'entropie)."""
    token = secrets.token_hex(16).upper()   # 16 octets = 128 bits
    return f"LEST-{token[:4]}-{token[4:8]}-{token[8:12]}-{token[12:16]}"


def _row_to_dict(r: LicenceRequest) -> dict:
    return {
        "id":              r.id,
        "nom":             r.nom,
        "email":           r.email,
        "formule":         r.formule,
        "promo_code":      r.promo_code,
        "promo_discount":  r.promo_discount,
        "statut":          r.statut,
        "cle":             r.cle,
        "num_recu":        r.num_recu,
        "date_demande":    r.date_demande.isoformat() if r.date_demande else None,
        "date_validation": r.date_validation.isoformat() if r.date_validation else None,
    }


async def _next_receipt_number(db: AsyncSession) -> str:
    """Génère un numéro de reçu séquentiel : LF-2026-0001."""
    result = await db.execute(
        select(func.count()).where(LicenceRequest.statut == "validé")
    )
    count = result.scalar() or 0
    year = datetime.now(timezone.utc).year
    return f"LF-{year}-{count + 1:04d}"


# ── Créer une demande (depuis onglet Plan) ────────────────────────────────────

@router.post("/requests")
async def create_request(data: dict, background_tasks: BackgroundTasks,
                         db: AsyncSession = Depends(get_db)):
    formule = data.get("formule", "annuel")
    if formule not in ("mensuel", "annuel"):
        formule = "annuel"

    email = str(data.get("email", "")).strip().lower()[:254]
    if not email or not _EMAIL_RE.match(email):
        raise HTTPException(status_code=422, detail="Email invalide")

    req = LicenceRequest(
        nom=str(data.get("nom", "")).strip()[:200] or "N/A",
        email=email,
        formule=formule,
        promo_code=data.get("promo_code"),
        promo_discount=data.get("promo_discount"),
    )
    db.add(req)
    await db.commit()
    await db.refresh(req)

    background_tasks.add_task(
        mailer.notify_admin_new_request,
        req.id, req.nom, req.email, req.formule,
        req.promo_code, req.promo_discount,
    )
    background_tasks.add_task(
        notifier.notify_new_request,
        req.id, req.nom, req.email, req.formule,
        req.promo_code, req.promo_discount,
    )
    return {"id": req.id, "status": "ok"}


# ── Lister toutes les demandes (admin) ────────────────────────────────────────

@router.get("/requests")
async def list_requests(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(LicenceRequest).order_by(LicenceRequest.date_demande.desc())
    )
    return [_row_to_dict(r) for r in result.scalars().all()]


# ── Valider une demande → génère la clé ──────────────────────────────────────

@router.post("/requests/{req_id}/validate")
async def validate_request(req_id: int, background_tasks: BackgroundTasks,
                           db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(LicenceRequest).where(LicenceRequest.id == req_id))
    req = result.scalar_one_or_none()
    if not req:
        raise HTTPException(status_code=404, detail="Demande introuvable")
    if req.statut == "validé":
        return {"id": req.id, "cle": req.cle, "num_recu": req.num_recu,
                "email": req.email, "status": "already_validated"}

    num_recu = await _next_receipt_number(db)
    cle = _generate_key()
    req.statut          = "validé"
    req.cle             = cle
    req.num_recu        = num_recu
    req.date_validation = datetime.now(timezone.utc)
    await db.commit()

    background_tasks.add_task(
        mailer.send_licence_activated,
        req.email, req.nom, cle, req.formule, num_recu,
    )
    background_tasks.add_task(
        notifier.notify_licence_activated,
        req.email, req.nom, cle, req.formule, num_recu,
    )
    return {"id": req.id, "cle": cle, "num_recu": num_recu, "email": req.email, "status": "ok"}


# ── Refuser une demande ───────────────────────────────────────────────────────

@router.post("/requests/{req_id}/reject")
async def reject_request(req_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(LicenceRequest).where(LicenceRequest.id == req_id))
    req = result.scalar_one_or_none()
    if not req:
        raise HTTPException(status_code=404, detail="Demande introuvable")
    req.statut = "refusé"
    await db.commit()
    return {"id": req.id, "status": "ok"}


# ── Statut d'une demande (côté client, par email) ────────────────────────────

@router.get("/status")
async def status_by_email(email: str, db: AsyncSession = Depends(get_db)):
    """Retourne la dernière demande associée à cet email."""
    email = email.strip().lower()
    if not email:
        return {"found": False}
    result = await db.execute(
        select(LicenceRequest)
        .where(LicenceRequest.email == email)
        .order_by(LicenceRequest.date_demande.desc())
    )
    req = result.scalars().first()
    if not req:
        return {"found": False}
    return {
        "found":    True,
        "statut":   req.statut,
        "formule":  req.formule,
        "num_recu": req.num_recu,
        "date":     req.date_demande.isoformat() if req.date_demande else None,
    }


# ── Vérifier une clé (activation côté client) ────────────────────────────────

@router.get("/verify/{key}")
async def verify_key(key: str, email: str | None = None,
                     db: AsyncSession = Depends(get_db)):
    """Retourne True si la clé existe EN BASE avec statut 'validé'.
    Si email est fourni, vérifie également que la clé appartient à cet email."""
    if not key or len(key) > 64:
        return {"valid": False}
    conditions = [LicenceRequest.cle == key, LicenceRequest.statut == "validé"]
    if email:
        conditions.append(LicenceRequest.email == email.strip().lower())
    result = await db.execute(select(LicenceRequest).where(*conditions))
    req = result.scalar_one_or_none()
    if not req:
        wrong_owner = False
        if email:
            # Vérifier si la clé existe mais appartient à un autre email
            r2 = await db.execute(
                select(LicenceRequest).where(
                    LicenceRequest.cle    == key,
                    LicenceRequest.statut == "validé",
                )
            )
            wrong_owner = r2.scalar_one_or_none() is not None
        return {"valid": False, "wrong_owner": wrong_owner}
    return {"valid": True, "formule": req.formule}


# ── Générer une clé directement (admin manuel) ────────────────────────────────

@router.post("/generate")
async def generate_key(data: dict, db: AsyncSession = Depends(get_db)):
    """Crée une demande et la valide immédiatement — pour les clés hors formulaire."""
    email = str(data.get("email", "")).strip().lower()
    if not email:
        raise HTTPException(status_code=422, detail="Email requis")
    formule = data.get("formule", "annuel")
    if formule not in ("mensuel", "annuel"):
        formule = "annuel"

    cle = _generate_key()
    req = LicenceRequest(
        nom=str(data.get("nom", email)).strip()[:200],
        email=email,
        formule=formule,
        statut="validé",
        cle=cle,
        date_validation=datetime.now(timezone.utc),
    )
    db.add(req)
    await db.commit()
    await db.refresh(req)
    return {"id": req.id, "cle": cle, "email": req.email, "status": "ok"}
