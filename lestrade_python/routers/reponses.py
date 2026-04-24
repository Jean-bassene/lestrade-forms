"""
Endpoints réponses — miroir exact de plumber.R + DELETE/PUT pour Desktop
"""
import json
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.database import get_db
from ..core.models import Reponse, Question, Section
from ..core.schemas import (
    ReponseOut, ReponsesPostIn, ReponsesPostOut, ReponseUpdateIn,
)

router = APIRouter(prefix="/reponses", tags=["réponses"])


# ── GET /reponses/{quest_id} ──────────────────────────────────────────────────

@router.get("/{quest_id}", response_model=list[ReponseOut])
async def list_reponses(quest_id: int, db: AsyncSession = Depends(get_db)):
    rows = (await db.execute(
        select(Reponse)
        .where(Reponse.questionnaire_id == quest_id)
        .order_by(Reponse.horodateur.desc())
    )).scalars().all()
    return [ReponseOut.model_validate(r) for r in rows]


# ── POST /reponses ────────────────────────────────────────────────────────────

@router.post("", response_model=ReponsesPostOut)
async def post_reponses(body: ReponsesPostIn, db: AsyncSession = Depends(get_db)):
    if not body.reponses_full:
        raise HTTPException(status_code=400, detail="reponses_full requis")

    existing = set((await db.execute(
        select(Reponse.uuid)
        .where(Reponse.questionnaire_id == body.quest_id, Reponse.uuid.isnot(None))
    )).scalars().all())

    saved = 0
    skipped = 0
    for rep in body.reponses_full:
        uuid = (rep.uuid or "").strip()
        if uuid and uuid in existing:
            skipped += 1
            continue

        try:
            json.loads(rep.donnees_json or "{}")
        except json.JSONDecodeError as e:
            raise HTTPException(status_code=422, detail=f"JSON invalide: {e}")

        horo = None
        if rep.horodateur:
            try:
                horo = datetime.fromisoformat(rep.horodateur.replace("T", " ").strip())
            except ValueError:
                horo = None

        r = Reponse(
            questionnaire_id = body.quest_id,
            horodateur       = horo,
            donnees_json     = rep.donnees_json or "{}",
            uuid             = uuid or None,
        )
        db.add(r)
        if uuid:
            existing.add(uuid)
        saved += 1

    await db.commit()
    return ReponsesPostOut(status="ok", saved=saved, skipped=skipped)


# ── PUT /reponses/{reponse_id} ────────────────────────────────────────────────

@router.put("/{reponse_id}", response_model=ReponseOut)
async def update_reponse(reponse_id: int, body: ReponseUpdateIn, db: AsyncSession = Depends(get_db)):
    r = await db.get(Reponse, reponse_id)
    if not r:
        raise HTTPException(status_code=404, detail="Réponse non trouvée")
    r.donnees_json = body.donnees_json
    await db.commit()
    await db.refresh(r)
    return ReponseOut.model_validate(r)


# ── DELETE /reponses/{reponse_id} ─────────────────────────────────────────────

@router.delete("/{reponse_id}", status_code=204)
async def delete_reponse(reponse_id: int, db: AsyncSession = Depends(get_db)):
    if not await db.get(Reponse, reponse_id):
        raise HTTPException(status_code=404, detail="Réponse non trouvée")
    await db.execute(delete(Reponse).where(Reponse.id == reponse_id))
    await db.commit()


# ── GET /reponses/{quest_id}/wide ─────────────────────────────────────────────

@router.get("/{quest_id}/wide")
async def reponses_wide(quest_id: int, db: AsyncSession = Depends(get_db)):
    reponses = (await db.execute(
        select(Reponse)
        .where(Reponse.questionnaire_id == quest_id)
        .order_by(Reponse.horodateur.desc())
    )).scalars().all()

    questions = (await db.execute(
        select(Question, Section.nom.label("section_nom"))
        .join(Section, Question.section_id == Section.id)
        .where(Section.questionnaire_id == quest_id)
        .order_by(Section.ordre, Question.ordre)
    )).all()

    if not reponses or not questions:
        return []

    q_ids  = [str(row.Question.id) for row in questions]
    labels = [f"{row.section_nom} / {row.Question.texte}" for row in questions]

    rows = []
    for rep in reponses:
        try:
            data = json.loads(rep.donnees_json)
        except Exception:
            data = {}
        row: dict = {"reponse_id": rep.id, "horodateur": str(rep.horodateur)}
        for qid, label in zip(q_ids, labels):
            val = data.get(qid, "")
            row[label] = " | ".join(val) if isinstance(val, list) else str(val) if val else ""
        rows.append(row)
    return rows
