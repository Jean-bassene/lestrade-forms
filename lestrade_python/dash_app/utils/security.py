"""
Sécurité — validation, sanitisation, rate limiting.
Toutes les entrées utilisateur passent par ici avant d'aller à l'API.
"""
import re
import time
import html
import json
import base64
from collections import defaultdict
from pathlib import Path

# ── Constantes ────────────────────────────────────────────────────────────────

ALLOWED_UPLOAD_EXT  = {".xlsx", ".xls", ".csv"}
MAX_UPLOAD_MB       = 10
MAX_NAME_LEN        = 200
MAX_DESC_LEN        = 1000
MAX_TEXT_LEN        = 5000
MAX_OPTIONS_ENTRIES = 100

# Rate limiting in-memory (PID-local, suffit pour Desktop mono-utilisateur)
_rate_store: dict[str, list[float]] = defaultdict(list)


# ── Sanitisation ──────────────────────────────────────────────────────────────

def sanitize_text(s: object, max_len: int = MAX_TEXT_LEN) -> str:
    """Escape HTML + tronque. Jamais None en sortie."""
    if s is None:
        return ""
    s = str(s).strip()
    s = html.escape(s)
    return s[:max_len]


def strip_tags(s: str) -> str:
    """Retire tout tag HTML résiduel (défense en profondeur)."""
    return re.sub(r"<[^>]+>", "", s or "")


# ── Validation ────────────────────────────────────────────────────────────────

def validate_email(email: object) -> tuple[bool, str]:
    if not email:
        return False, "Email requis"
    email = str(email).strip().lower()
    if len(email) > 254:
        return False, "Email trop long"
    # RFC 5322 simplifiée (pas de Unicode)
    pattern = r"^[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}$"
    if not re.match(pattern, email):
        return False, "Format email invalide (ex: prenom.nom@domaine.sn)"
    # Blocage des domaines à risque connus pour du spam
    domain = email.split("@")[1]
    if domain in {"mailinator.com", "guerrillamail.com", "throwaway.email"}:
        return False, "Domaine email non autorisé"
    return True, ""


def validate_name(name: object, label: str = "Nom") -> tuple[bool, str]:
    if not name:
        return False, f"{label} obligatoire"
    name = str(name).strip()
    if not name:
        return False, f"{label} ne peut pas être vide"
    if len(name) > MAX_NAME_LEN:
        return False, f"{label} trop long (max {MAX_NAME_LEN} caractères)"
    if re.search(r"[<>]", name):
        return False, f"{label} contient des caractères invalides"
    return True, ""


def validate_options_text(raw: str) -> tuple[bool, str, list[str]]:
    """
    Parse les options (une par ligne ou séparées par virgule).
    Retourne (ok, erreur, liste_options_nettoyée).
    """
    if not raw or not raw.strip():
        return True, "", []
    lines = [l.strip() for l in re.split(r"[\n,;]", raw) if l.strip()]
    if len(lines) > MAX_OPTIONS_ENTRIES:
        return False, f"Trop d'options (max {MAX_OPTIONS_ENTRIES})", []
    # Sanitise chaque option
    clean = [sanitize_text(l, 200) for l in lines]
    clean = [l for l in clean if l]
    return True, "", clean


def validate_upload(
    filename: str | None,
    content_b64: str | None,
    max_size_mb: float = MAX_UPLOAD_MB,
) -> tuple[bool, str, bytes]:
    """
    Valide un fichier uploadé depuis dcc.Upload.
    Retourne (ok, message_erreur, contenu_bytes).
    Vérifie : extension whitelist, taille, décodage base64.
    """
    if not filename or not content_b64:
        return False, "Aucun fichier sélectionné", b""

    # Sécurisation du nom de fichier (pas de path traversal)
    safe_name = Path(filename).name
    ext = Path(safe_name).suffix.lower()

    if ext not in ALLOWED_UPLOAD_EXT:
        allowed = ", ".join(sorted(ALLOWED_UPLOAD_EXT))
        return False, f"Format non supporté. Formats acceptés : {allowed}", b""

    # Dash préfixe le contenu base64 avec "data:...;base64,"
    try:
        if "," in content_b64:
            content_b64 = content_b64.split(",", 1)[1]
        data = base64.b64decode(content_b64)
    except Exception:
        return False, "Fichier corrompu ou illisible", b""

    size_mb = len(data) / (1024 * 1024)
    if size_mb > max_size_mb:
        return False, f"Fichier trop volumineux ({size_mb:.1f} MB, max {max_size_mb} MB)", b""

    return True, "", data


def safe_json_loads(s: str | None) -> dict | list | None:
    try:
        return json.loads(s or "{}")
    except (json.JSONDecodeError, TypeError):
        return None


def safe_json_dumps(obj: object) -> str:
    try:
        return json.dumps(obj, ensure_ascii=False)
    except (TypeError, ValueError):
        return "{}"


# ── Rate Limiting ─────────────────────────────────────────────────────────────

def rate_limit(key: str, max_calls: int = 10, window_s: float = 60.0) -> bool:
    """
    Retourne True si l'action est autorisée, False si le quota est dépassé.
    Utilisé pour protéger les actions create/delete contre le spam.
    """
    now  = time.monotonic()
    hist = _rate_store[key]
    # Purge hors-fenêtre
    _rate_store[key] = [t for t in hist if now - t < window_s]
    if len(_rate_store[key]) >= max_calls:
        return False
    _rate_store[key].append(now)
    return True
