"""
CRUD questions — endpoints pour Dash UI Desktop
"""
import json
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, func, delete
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.database import get_db
from ..core.models import Question, Section
from ..core.schemas import QuestionIn, QuestionOut

router = APIRouter(tags=["questions"])


@router.post("/sections/{section_id}/questions", response_model=QuestionOut, status_code=201)
async def create_question(section_id: int, body: QuestionIn, db: AsyncSession = Depends(get_db)):
    sec = await db.get(Section, section_id)
    if not sec:
        raise HTTPException(status_code=404, detail="Section non trouvée")

    # Valider options si fourni
    if body.options:
        try:
            json.loads(body.options)
        except json.JSONDecodeError as e:
            raise HTTPException(status_code=422, detail=f"options JSON invalide: {e}")

    max_ordre = (await db.execute(
        select(func.coalesce(func.max(Question.ordre), 0))
        .where(Question.section_id == section_id)
    )).scalar_one()

    q = Question(
        section_id      = section_id,
        type            = body.type,
        texte           = body.texte,
        options         = body.options or "{}",
        role_analytique = body.role_analytique,
        obligatoire     = body.obligatoire,
        ordre           = max_ordre + 1,
    )
    db.add(q)
    await db.commit()
    await db.refresh(q)

    # Charger section_nom pour la réponse
    await db.refresh(sec)
    return QuestionOut(
        id              = q.id,
        section_id      = q.section_id,
        type            = q.type,
        texte           = q.texte,
        options         = q.options,
        role_analytique = q.role_analytique,
        obligatoire     = q.obligatoire,
        ordre           = q.ordre,
        section_nom     = sec.nom,
    )


@router.delete("/questions/{question_id}", status_code=204)
async def delete_question(question_id: int, db: AsyncSession = Depends(get_db)):
    if not await db.get(Question, question_id):
        raise HTTPException(status_code=404, detail="Question non trouvée")
    await db.execute(delete(Question).where(Question.id == question_id))
    await db.commit()


@router.put("/questions/{question_id}", response_model=QuestionOut)
async def update_question(question_id: int, body: QuestionIn, db: AsyncSession = Depends(get_db)):
    q = await db.get(Question, question_id)
    if not q:
        raise HTTPException(status_code=404, detail="Question non trouvée")

    if body.options:
        try:
            json.loads(body.options)
        except json.JSONDecodeError as e:
            raise HTTPException(status_code=422, detail=f"options JSON invalide: {e}")

    q.type            = body.type
    q.texte           = body.texte
    q.options         = body.options or "{}"
    q.role_analytique = body.role_analytique
    q.obligatoire     = body.obligatoire

    await db.commit()
    await db.refresh(q)
    sec = await db.get(Section, q.section_id)
    return QuestionOut(
        id              = q.id,
        section_id      = q.section_id,
        type            = q.type,
        texte           = q.texte,
        options         = q.options,
        role_analytique = q.role_analytique,
        obligatoire     = q.obligatoire,
        ordre           = q.ordre,
        section_nom     = sec.nom if sec else None,
    )
