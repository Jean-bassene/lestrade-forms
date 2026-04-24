"""
Client HTTP synchrone vers FastAPI (port 8765).
Toutes les erreurs sont capturées et renvoyées sous forme de dict {"error": "..."}.
Le Dash UI ne voit jamais de stack trace.
"""
import httpx

_BASE  = "http://127.0.0.1:8765"
_TIMEOUT = httpx.Timeout(connect=3.0, read=15.0, write=10.0, pool=5.0)


def _client() -> httpx.Client:
    return httpx.Client(base_url=_BASE, timeout=_TIMEOUT)


def _err(msg: str) -> dict:
    return {"error": msg}


# ── Health ────────────────────────────────────────────────────────────────────

def health() -> dict:
    try:
        with _client() as c:
            return c.get("/health").json()
    except Exception as e:
        return _err(f"API inaccessible: {e}")


# ── Questionnaires ────────────────────────────────────────────────────────────

def get_questionnaires() -> list:
    try:
        with _client() as c:
            r = c.get("/questionnaires")
            r.raise_for_status()
            return r.json()
    except httpx.HTTPStatusError as e:
        return []
    except Exception:
        return []


def get_questionnaire(quest_id: int) -> dict:
    try:
        with _client() as c:
            r = c.get(f"/questionnaires/{quest_id}")
            r.raise_for_status()
            return r.json()
    except httpx.HTTPStatusError as e:
        return _err(e.response.json().get("detail", str(e)))
    except Exception as e:
        return _err(str(e))


def create_questionnaire(nom: str, description: str) -> dict:
    try:
        with _client() as c:
            r = c.post("/questionnaires", json={"nom": nom, "description": description})
            r.raise_for_status()
            return r.json()
    except httpx.HTTPStatusError as e:
        detail = e.response.json()
        return _err(str(detail.get("detail", e)))
    except Exception as e:
        return _err(str(e))


def delete_questionnaire(quest_id: int) -> dict:
    try:
        with _client() as c:
            r = c.delete(f"/questionnaires/{quest_id}")
            r.raise_for_status()
            return {"ok": True}
    except httpx.HTTPStatusError as e:
        return _err(e.response.json().get("detail", str(e)))
    except Exception as e:
        return _err(str(e))


# ── Sections ──────────────────────────────────────────────────────────────────

def create_section(quest_id: int, nom: str) -> dict:
    try:
        with _client() as c:
            r = c.post(f"/questionnaires/{quest_id}/sections", json={"nom": nom})
            r.raise_for_status()
            return r.json()
    except httpx.HTTPStatusError as e:
        return _err(e.response.json().get("detail", str(e)))
    except Exception as e:
        return _err(str(e))


def delete_section(section_id: int) -> dict:
    try:
        with _client() as c:
            r = c.delete(f"/sections/{section_id}")
            r.raise_for_status()
            return {"ok": True}
    except httpx.HTTPStatusError as e:
        return _err(e.response.json().get("detail", str(e)))
    except Exception as e:
        return _err(str(e))


# ── Questions ─────────────────────────────────────────────────────────────────

def create_question(section_id: int, payload: dict) -> dict:
    try:
        with _client() as c:
            r = c.post(f"/sections/{section_id}/questions", json=payload)
            r.raise_for_status()
            return r.json()
    except httpx.HTTPStatusError as e:
        return _err(e.response.json().get("detail", str(e)))
    except Exception as e:
        return _err(str(e))


def delete_question(question_id: int) -> dict:
    try:
        with _client() as c:
            r = c.delete(f"/questions/{question_id}")
            r.raise_for_status()
            return {"ok": True}
    except httpx.HTTPStatusError as e:
        return _err(e.response.json().get("detail", str(e)))
    except Exception as e:
        return _err(str(e))


# ── Réponses ──────────────────────────────────────────────────────────────────

def get_reponses(quest_id: int) -> list:
    try:
        with _client() as c:
            r = c.get(f"/reponses/{quest_id}")
            r.raise_for_status()
            return r.json()
    except Exception:
        return []


def get_reponses_wide(quest_id: int) -> list:
    try:
        with _client() as c:
            r = c.get(f"/reponses/{quest_id}/wide")
            r.raise_for_status()
            return r.json()
    except Exception:
        return []


def post_reponse(quest_id: int, donnees_json: str) -> dict:
    try:
        with _client() as c:
            payload = {
                "quest_id": quest_id,
                "reponses_full": [{"donnees_json": donnees_json}],
            }
            r = c.post("/reponses", json=payload)
            r.raise_for_status()
            return r.json()
    except httpx.HTTPStatusError as e:
        return _err(e.response.json().get("detail", str(e)))
    except Exception as e:
        return _err(str(e))


def delete_reponse(reponse_id: int) -> dict:
    try:
        with _client() as c:
            r = c.delete(f"/reponses/{reponse_id}")
            r.raise_for_status()
            return {"ok": True}
    except httpx.HTTPStatusError as e:
        return _err(e.response.json().get("detail", str(e)))
    except Exception as e:
        return _err(str(e))


# ── Config ────────────────────────────────────────────────────────────────────

def get_config(key: str) -> str | None:
    try:
        with _client() as c:
            r = c.get(f"/config/{key}")
            r.raise_for_status()
            return r.json().get("value")
    except Exception:
        return None


def set_config(key: str, value: str) -> dict:
    try:
        with _client() as c:
            r = c.put(f"/config/{key}", json={"value": value})
            r.raise_for_status()
            return r.json()
    except httpx.HTTPStatusError as e:
        return _err(e.response.json().get("detail", str(e)))
    except Exception as e:
        return _err(str(e))
