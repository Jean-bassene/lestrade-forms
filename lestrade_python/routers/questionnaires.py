"""
Endpoints questionnaires — Flutter-compatible + CRUD Desktop
"""
import binascii
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, func, delete, or_
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.database import get_db
from ..core.models import Questionnaire, Section, Question
from ..core.schemas import (
    QuestionnaireIn, QuestionnaireOut, QuestionnaireFullOut,
    SectionOut, QuestionOut,
)

router = APIRouter(prefix="/questionnaires", tags=["questionnaires"])


# ── Helpers ───────────────────────────────────────────────────────────────────

async def _count_sections(db: AsyncSession, quest_id: int) -> int:
    r = await db.execute(
        select(func.count()).where(Section.questionnaire_id == quest_id)
    )
    return r.scalar_one()


async def _count_questions(db: AsyncSession, quest_id: int) -> int:
    r = await db.execute(
        select(func.count())
        .select_from(Question)
        .join(Section, Question.section_id == Section.id)
        .where(Section.questionnaire_id == quest_id)
    )
    return r.scalar_one()


def _generate_uid(quest_id: int, nom: str) -> str:
    crc   = binascii.crc32(nom.encode()) & 0xFFFFFFFF
    hash4 = format(crc, "08x")[:4].upper()
    return f"LEST-{quest_id:04d}-{hash4}"


async def _build_full(db: AsyncSession, quest_id: int) -> QuestionnaireFullOut | None:
    q = await db.get(Questionnaire, quest_id)
    if not q:
        return None

    secs = (await db.execute(
        select(Section).where(Section.questionnaire_id == quest_id).order_by(Section.ordre)
    )).scalars().all()

    qs = (await db.execute(
        select(Question, Section.nom.label("section_nom"))
        .join(Section, Question.section_id == Section.id)
        .where(Section.questionnaire_id == quest_id)
        .order_by(Section.ordre, Question.ordre)
    )).all()

    questionnaire_out = QuestionnaireOut(
        id            = q.id,
        nom           = q.nom,
        description   = q.description,
        date_creation = q.date_creation,
        nb_sections   = len(secs),
        nb_questions  = len(qs),
    )
    return QuestionnaireFullOut(
        questionnaire = questionnaire_out,
        sections      = [SectionOut.model_validate(s) for s in secs],
        questions     = [
            QuestionOut(
                id              = row.Question.id,
                section_id      = row.Question.section_id,
                type            = row.Question.type,
                texte           = row.Question.texte,
                options         = row.Question.options,
                role_analytique = row.Question.role_analytique,
                obligatoire     = row.Question.obligatoire,
                ordre           = row.Question.ordre,
                section_nom     = row.section_nom,
            )
            for row in qs
        ],
    )


# ── GET /questionnaires ───────────────────────────────────────────────────────

@router.get("", response_model=list[QuestionnaireOut])
async def list_questionnaires(owner_email: str | None = None,
                              db: AsyncSession = Depends(get_db)):
    """Retourne les questionnaires visibles pour cet utilisateur :
    les siens (owner_email correspond) + ceux sans propriétaire (héritage)."""
    stmt = select(Questionnaire).order_by(Questionnaire.date_creation.desc())
    if owner_email:
        email = owner_email.strip().lower()
        stmt = stmt.where(
            or_(Questionnaire.owner_email == email,
                Questionnaire.owner_email.is_(None))
        )
    rows = (await db.execute(stmt)).scalars().all()

    result = []
    for q in rows:
        result.append(QuestionnaireOut(
            id            = q.id,
            nom           = q.nom,
            description   = q.description,
            date_creation = q.date_creation,
            nb_sections   = await _count_sections(db, q.id),
            nb_questions  = await _count_questions(db, q.id),
        ))
    return result


# ── POST /questionnaires ──────────────────────────────────────────────────────

@router.post("", response_model=QuestionnaireOut, status_code=201)
async def create_questionnaire(body: QuestionnaireIn, db: AsyncSession = Depends(get_db)):
    owner = (body.owner_email or "").strip().lower() or None
    q = Questionnaire(nom=body.nom, description=body.description, owner_email=owner)
    db.add(q)
    await db.commit()
    await db.refresh(q)
    return QuestionnaireOut(
        id            = q.id,
        nom           = q.nom,
        description   = q.description,
        date_creation = q.date_creation,
        nb_sections   = 0,
        nb_questions  = 0,
    )


# ── DELETE /questionnaires/{id} ───────────────────────────────────────────────

@router.delete("/{quest_id}", status_code=204)
async def delete_questionnaire(quest_id: int, db: AsyncSession = Depends(get_db)):
    if not await db.get(Questionnaire, quest_id):
        raise HTTPException(status_code=404, detail="Questionnaire non trouvé")
    # Statement-level delete — SQLite CASCADE supprime sections/questions/réponses
    await db.execute(delete(Questionnaire).where(Questionnaire.id == quest_id))
    await db.commit()


# ── GET /questionnaires/uid/{uid} — doit être avant /{quest_id} (int) ─────────

@router.get("/uid/{uid}", response_model=QuestionnaireFullOut)
async def get_questionnaire_by_uid(uid: str, db: AsyncSession = Depends(get_db)):
    rows = (await db.execute(select(Questionnaire))).scalars().all()
    for q in rows:
        if _generate_uid(q.id, q.nom) == uid.upper():
            full = await _build_full(db, q.id)
            if full:
                return full
    raise HTTPException(status_code=404, detail=f"UID {uid} introuvable")


# ── GET /questionnaires/{id} ──────────────────────────────────────────────────

@router.get("/{quest_id}", response_model=QuestionnaireFullOut)
async def get_questionnaire(quest_id: int, db: AsyncSession = Depends(get_db)):
    full = await _build_full(db, quest_id)
    if not full:
        raise HTTPException(status_code=404, detail="Questionnaire non trouvé")
    return full
