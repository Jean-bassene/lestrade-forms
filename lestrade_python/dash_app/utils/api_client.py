"""
Client HTTP synchrone vers FastAPI (port 8765).
Toutes les erreurs sont capturées et renvoyées sous forme de dict {"error": "..."}.
Le Dash UI ne voit jamais de stack trace.
"""
import os
import json
import httpx

_BASE  = "http://127.0.0.1:8765"
_TIMEOUT = httpx.Timeout(connect=3.0, read=15.0, write=10.0, pool=5.0)

# ── Panier centralisé ─────────────────────────────────────────────────────────
# Surchargeable via la variable d'environnement LESTRADE_PANIER_URL.
# Format : https://script.google.com/macros/s/AKfycb.../exec
CENTRAL_PANIER_URL = os.environ.get(
    "LESTRADE_PANIER_URL",
    "https://script.google.com/macros/s/AKfycbxIbSS4DlokdvAJoAi4_lPXdzHJi0J9XKEquXK3zeFtRf-9ThEKze1Z4truyf7CWDkyXg/exec",
)

_PANIER_TIMEOUT = httpx.Timeout(connect=5.0, read=20.0, write=15.0, pool=5.0)


def panier_status() -> dict:
    """Ping le panier central — retourne {"ok": True, "version": "4.0"} ou {"error": ...}."""
    if not CENTRAL_PANIER_URL:
        return {"error": "URL non configurée"}
    try:
        r = httpx.get(CENTRAL_PANIER_URL, params={"action": "info"},
                      timeout=_PANIER_TIMEOUT, follow_redirects=True)
        r.raise_for_status()
        return r.json()
    except Exception as e:
        return {"error": type(e).__name__}


def fetch_panier_rows(user_email: str, quest_id: int | None = None) -> dict:
    """Retourne les réponses du panier pour cet utilisateur (et optionnellement ce questionnaire)."""
    if not CENTRAL_PANIER_URL:
        return {"error": "URL panier central non configurée"}
    try:
        params: dict = {"action": "list", "user_email": user_email}
        if quest_id:
            params["quest_id"] = str(quest_id)
        r = httpx.get(CENTRAL_PANIER_URL, params=params,
                      timeout=_PANIER_TIMEOUT, follow_redirects=True)
        r.raise_for_status()
        return r.json()
    except Exception as e:
        return {"error": type(e).__name__}


def publish_quest_to_panier(uid: str, nom: str, quest_json: dict) -> dict:
    """Publie un questionnaire dans la feuille Questionnaires du panier central."""
    if not CENTRAL_PANIER_URL:
        return {"error": "URL panier central non configurée"}
    try:
        payload = {"action": "save_quest", "uid": uid, "nom": nom,
                   "quest_json": json.dumps(quest_json, ensure_ascii=False)}
        r = httpx.post(CENTRAL_PANIER_URL, json=payload,
                       timeout=_PANIER_TIMEOUT, follow_redirects=True)
        r.raise_for_status()
        return r.json()
    except Exception as e:
        return {"error": type(e).__name__}


def clear_panier(quest_id: int | None = None) -> dict:
    """Vide le panier central (toutes réponses ou pour un questionnaire donné)."""
    if not CENTRAL_PANIER_URL:
        return {"error": "URL panier central non configurée"}
    try:
        params: dict = {"action": "clear"}
        if quest_id:
            params["quest_id"] = str(quest_id)
        r = httpx.get(CENTRAL_PANIER_URL, params=params,
                      timeout=_PANIER_TIMEOUT, follow_redirects=True)
        r.raise_for_status()
        return r.json()
    except Exception as e:
        return {"error": type(e).__name__}


def push_to_panier(user_email: str, quest_id: int, reponses_full: list) -> dict:
    """Envoie des réponses vers le panier central."""
    if not CENTRAL_PANIER_URL:
        return {"error": "URL panier central non configurée"}
    try:
        payload = {"quest_id": quest_id, "user_email": user_email, "reponses_full": reponses_full}
        r = httpx.post(CENTRAL_PANIER_URL, json=payload,
                       timeout=_PANIER_TIMEOUT, follow_redirects=True)
        r.raise_for_status()
        return r.json()
    except Exception as e:
        return {"error": type(e).__name__}


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

def get_questionnaires(owner_email: str | None = None) -> list:
    try:
        params = {}
        if owner_email:
            params["owner_email"] = owner_email
        with _client() as c:
            r = c.get("/questionnaires", params=params)
            r.raise_for_status()
            return r.json()
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


def create_questionnaire(nom: str, description: str,
                         owner_email: str | None = None) -> dict:
    try:
        payload: dict = {"nom": nom, "description": description}
        if owner_email:
            payload["owner_email"] = owner_email
        with _client() as c:
            r = c.post("/questionnaires", json=payload)
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


# ── Licences ─────────────────────────────────────────────────────────────────

def create_licence_request(nom: str, email: str, formule: str,
                            promo_code: str | None = None,
                            promo_discount: int | None = None) -> dict:
    try:
        payload: dict = {"nom": nom, "email": email, "formule": formule}
        if promo_code:
            payload["promo_code"]     = promo_code
            payload["promo_discount"] = promo_discount
        with _client() as c:
            r = c.post("/licences/requests", json=payload)
            r.raise_for_status()
            return r.json()
    except httpx.HTTPStatusError as e:
        return _err(e.response.json().get("detail", str(e)))
    except Exception as e:
        return _err(str(e))


def get_licence_requests() -> list:
    try:
        with _client() as c:
            r = c.get("/licences/requests")
            r.raise_for_status()
            return r.json()
    except Exception:
        return []


def validate_licence_request(req_id: int) -> dict:
    try:
        with _client() as c:
            r = c.post(f"/licences/requests/{req_id}/validate")
            r.raise_for_status()
            return r.json()
    except httpx.HTTPStatusError as e:
        return _err(e.response.json().get("detail", str(e)))
    except Exception as e:
        return _err(str(e))


def reject_licence_request(req_id: int) -> dict:
    try:
        with _client() as c:
            r = c.post(f"/licences/requests/{req_id}/reject")
            r.raise_for_status()
            return r.json()
    except httpx.HTTPStatusError as e:
        return _err(e.response.json().get("detail", str(e)))
    except Exception as e:
        return _err(str(e))


def check_licence_status(email: str) -> dict:
    """Retourne le statut de la dernière demande pour cet email."""
    try:
        with _client() as c:
            r = c.get("/licences/status", params={"email": email})
            r.raise_for_status()
            return r.json()
    except Exception:
        return {"found": False}


def verify_licence_key(key: str, email: str | None = None) -> dict:
    """Retourne {"valid": True/False} — vérifie en base que la clé est réellement validée.
    Si email est fourni, vérifie que la clé appartient bien à cet email."""
    try:
        params = {}
        if email:
            params["email"] = email
        with _client() as c:
            r = c.get(f"/licences/verify/{key}", params=params)
            r.raise_for_status()
            return r.json()
    except Exception:
        return {"valid": False}


def generate_licence_key(email: str, formule: str, nom: str = "") -> dict:
    try:
        with _client() as c:
            r = c.post("/licences/generate",
                       json={"email": email, "formule": formule, "nom": nom or email})
            r.raise_for_status()
            return r.json()
    except httpx.HTTPStatusError as e:
        return _err(e.response.json().get("detail", str(e)))
    except Exception as e:
        return _err(str(e))


# ── Backup / Restore ─────────────────────────────────────────────────────────

def restore_database(file_bytes: bytes) -> dict:
    try:
        with _client() as c:
            r = c.post("/admin/restore",
                       files={"file": ("backup.db", file_bytes, "application/octet-stream")},
                       timeout=httpx.Timeout(connect=5.0, read=60.0, write=30.0, pool=5.0))
            r.raise_for_status()
            return r.json()
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
