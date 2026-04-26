"""
Lestrade Forms — API Python (FastAPI)
Remplace plumber.R — compatible Flutter sans modification
"""
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .core.database import init_db
from .routers import health, questionnaires, reponses, sections, questions, config, licences, admin_db


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield


app = FastAPI(
    title       = "Lestrade Forms API",
    description = "API REST pour l'app Desktop et Flutter mobile",
    version     = "2.0.0",
    lifespan    = lifespan,
    # Pas de docs en prod pour réduire la surface d'attaque
    # docs_url=None, redoc_url=None,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins     = ["*"],
    allow_methods     = ["*"],
    allow_headers     = ["*"],
    allow_credentials = False,
)

app.include_router(health.router)
app.include_router(questionnaires.router)
app.include_router(reponses.router)
app.include_router(sections.router)
app.include_router(questions.router)
app.include_router(config.router)
app.include_router(licences.router)
app.include_router(admin_db.router)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("lestrade_python.main:app", host="0.0.0.0", port=8765, reload=False)
