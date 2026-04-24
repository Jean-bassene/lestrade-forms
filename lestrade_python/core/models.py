"""
Modèles SQLAlchemy — miroir exact du schéma SQLite créé par R (global_final.R)
"""
from datetime import datetime
from sqlalchemy import Integer, String, Text, DateTime, ForeignKey, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from .database import Base


class Questionnaire(Base):
    __tablename__ = "questionnaires"

    id:            Mapped[int]          = mapped_column(Integer, primary_key=True, autoincrement=True)
    nom:           Mapped[str]          = mapped_column(String, nullable=False)
    description:   Mapped[str | None]   = mapped_column(Text)
    date_creation: Mapped[datetime]     = mapped_column(DateTime, server_default=func.now())

    sections:  Mapped[list["Section"]]  = relationship(back_populates="questionnaire", cascade="all, delete")
    reponses:  Mapped[list["Reponse"]]  = relationship(back_populates="questionnaire", cascade="all, delete")


class Section(Base):
    __tablename__ = "sections"

    id:               Mapped[int]       = mapped_column(Integer, primary_key=True, autoincrement=True)
    questionnaire_id: Mapped[int]       = mapped_column(ForeignKey("questionnaires.id", ondelete="CASCADE"))
    nom:              Mapped[str]       = mapped_column(String, nullable=False)
    ordre:            Mapped[int]       = mapped_column(Integer, default=1)

    questionnaire: Mapped["Questionnaire"]  = relationship(back_populates="sections")
    questions:     Mapped[list["Question"]] = relationship(back_populates="section", cascade="all, delete")


class Question(Base):
    __tablename__ = "questions"

    id:              Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    section_id:      Mapped[int]        = mapped_column(ForeignKey("sections.id", ondelete="CASCADE"))
    type:            Mapped[str]        = mapped_column(String, nullable=False)
    texte:           Mapped[str]        = mapped_column(Text, nullable=False)
    options:         Mapped[str | None] = mapped_column(Text)
    role_analytique: Mapped[str | None] = mapped_column(String)
    obligatoire:     Mapped[int]        = mapped_column(Integer, default=0)
    ordre:           Mapped[int]        = mapped_column(Integer, default=1)

    section: Mapped["Section"] = relationship(back_populates="questions")


class Reponse(Base):
    __tablename__ = "reponses"

    id:               Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    questionnaire_id: Mapped[int]        = mapped_column(ForeignKey("questionnaires.id", ondelete="CASCADE"))
    horodateur:       Mapped[datetime]   = mapped_column(DateTime, server_default=func.now())
    donnees_json:     Mapped[str]        = mapped_column(Text, nullable=False)
    uuid:             Mapped[str | None] = mapped_column(String, unique=True)

    questionnaire: Mapped["Questionnaire"] = relationship(back_populates="reponses")


class Config(Base):
    """Clé-valeur pour la configuration applicative (email, préférences…)."""
    __tablename__ = "config"

    key:   Mapped[str]        = mapped_column(String, primary_key=True)
    value: Mapped[str | None] = mapped_column(Text)
