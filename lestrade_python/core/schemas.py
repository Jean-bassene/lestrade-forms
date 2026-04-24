"""
Schémas Pydantic — validation entrées/sorties API
"""
from datetime import datetime
from typing import Any
from pydantic import BaseModel, ConfigDict, field_validator
import re


# ── Questionnaire ─────────────────────────────────────────────────────────────

class QuestionnaireIn(BaseModel):
    nom:         str
    description: str | None = None

    @field_validator("nom")
    @classmethod
    def nom_valid(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Nom obligatoire")
        if len(v) > 200:
            raise ValueError("Nom trop long (max 200 caractères)")
        if re.search(r"[<>]", v):
            raise ValueError("Caractères invalides")
        return v

    @field_validator("description")
    @classmethod
    def desc_valid(cls, v: str | None) -> str | None:
        if v is None:
            return v
        v = v.strip()
        if len(v) > 1000:
            raise ValueError("Description trop longue (max 1000 caractères)")
        return v


class QuestionnaireOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id:            int
    nom:           str
    description:   str | None = None
    date_creation: datetime | None = None
    nb_sections:   int = 0
    nb_questions:  int = 0


# ── Section ───────────────────────────────────────────────────────────────────

class SectionIn(BaseModel):
    nom: str

    @field_validator("nom")
    @classmethod
    def nom_valid(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Nom de section obligatoire")
        if len(v) > 200:
            raise ValueError("Nom trop long")
        if re.search(r"[<>]", v):
            raise ValueError("Caractères invalides")
        return v


class SectionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id:               int
    questionnaire_id: int
    nom:              str
    ordre:            int = 1


# ── Question ──────────────────────────────────────────────────────────────────

ALLOWED_TYPES = {"text", "textarea", "radio", "checkbox", "likert",
                 "dropdown", "email", "phone", "date"}


class QuestionIn(BaseModel):
    type:            str
    texte:           str
    options:         str | None = None
    role_analytique: str | None = None
    obligatoire:     int = 0

    @field_validator("type")
    @classmethod
    def type_valid(cls, v: str) -> str:
        if v not in ALLOWED_TYPES:
            raise ValueError(f"Type invalide. Autorisés : {ALLOWED_TYPES}")
        return v

    @field_validator("texte")
    @classmethod
    def texte_valid(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Texte de question obligatoire")
        if len(v) > 2000:
            raise ValueError("Texte trop long")
        return v


class QuestionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id:              int
    section_id:      int
    type:            str
    texte:           str
    options:         str | None = None
    role_analytique: str | None = None
    obligatoire:     int = 0
    ordre:           int = 1
    section_nom:     str | None = None


class QuestionnaireFullOut(BaseModel):
    questionnaire: QuestionnaireOut
    sections:      list[SectionOut]
    questions:     list[QuestionOut]


# ── Réponses ──────────────────────────────────────────────────────────────────

class ReponseOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id:               int
    questionnaire_id: int
    horodateur:       datetime | None = None
    donnees_json:     str
    uuid:             str | None = None


class ReponseIn(BaseModel):
    uuid:         str | None = None
    horodateur:   str | None = None
    donnees_json: str = "{}"


class ReponsesPostIn(BaseModel):
    quest_id:      int
    reponses_full: list[ReponseIn] = []


class ReponsesPostOut(BaseModel):
    status:  str
    saved:   int
    skipped: int = 0


class ReponseUpdateIn(BaseModel):
    donnees_json: str

    @field_validator("donnees_json")
    @classmethod
    def json_valid(cls, v: str) -> str:
        import json
        try:
            json.loads(v)
        except json.JSONDecodeError as e:
            raise ValueError(f"JSON invalide: {e}")
        return v


# ── Config ────────────────────────────────────────────────────────────────────

class ConfigOut(BaseModel):
    key:   str
    value: str | None = None


class ConfigIn(BaseModel):
    value: str

    @field_validator("value")
    @classmethod
    def value_safe(cls, v: str) -> str:
        if len(v) > 2000:
            raise ValueError("Valeur trop longue")
        return v.strip()


# ── Health ────────────────────────────────────────────────────────────────────

class HealthOut(BaseModel):
    status:  str
    version: str
    db:      bool
    ts:      str
