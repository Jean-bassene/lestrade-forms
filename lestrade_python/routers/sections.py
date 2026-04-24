"""
CRUD sections — endpoints ajoutés pour le Dash UI Desktop
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, func, delete
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.database import get_db
from ..core.models import Section, Question, Questionnaire
from ..core.schemas import SectionIn, SectionOut

router = APIRouter(tags=["sections"])


@router.post("/questionnaires/{quest_id}/sections", response_model=SectionOut, status_code=201)
async def create_section(quest_id: int, body: SectionIn, db: AsyncSession = Depends(get_db)):
    if not await db.get(Questionnaire, quest_id):
        raise HTTPException(status_code=404, detail="Questionnaire non trouvé")

    max_ordre = (await db.execute(
        select(func.coalesce(func.max(Section.ordre), 0))
        .where(Section.questionnaire_id == quest_id)
    )).scalar_one()

    sec = Section(questionnaire_id=quest_id, nom=body.nom, ordre=max_ordre + 1)
    db.add(sec)
    await db.commit()
    await db.refresh(sec)
    return SectionOut.model_validate(sec)


@router.delete("/sections/{section_id}", status_code=204)
async def delete_section(section_id: int, db: AsyncSession = Depends(get_db)):
    if not await db.get(Section, section_id):
        raise HTTPException(status_code=404, detail="Section non trouvée")
    await db.execute(delete(Section).where(Section.id == section_id))
    await db.commit()
