"""
Notification Telegram — alternative/complément à l'email SMTP.
Utilise l'API Bot Telegram via httpx (déjà en dépendance).
Config : TELEGRAM_BOT_TOKEN + TELEGRAM_CHAT_ID dans .env
"""
import os
import httpx

_TIMEOUT = httpx.Timeout(connect=5.0, read=10.0, write=5.0, pool=3.0)

_TARIFS  = {"annuel": "$120/an (~75 000 FCFA)", "mensuel": "$15/mois (~10 000 FCFA)"}
_LIBELLE = {"annuel": "Pro Annuel",              "mensuel": "Pro Mensuel"}


def _send(text: str) -> bool:
    # Lu au runtime pour prendre en compte les changements de .env sans redémarrage
    token   = os.environ.get("TELEGRAM_BOT_TOKEN", "")
    chat_id = os.environ.get("TELEGRAM_CHAT_ID",   "")
    if not token or not chat_id:
        return False
    try:
        url = f"https://api.telegram.org/bot{token}/sendMessage"
        r = httpx.post(url, json={"chat_id": chat_id, "text": text, "parse_mode": "HTML"},
                       timeout=_TIMEOUT)
        return r.status_code == 200
    except Exception:
        return False


def notify_new_request(req_id: int, nom: str, email: str, formule: str,
                       promo_code: str | None, promo_discount: int | None) -> bool:
    libelle = _LIBELLE.get(formule, formule)
    montant = _TARIFS.get(formule, formule)
    promo   = f"\n🏷 Promo : <code>{promo_code}</code> (-{promo_discount}%)" if promo_code else ""
    text = (
        f"🔔 <b>Nouvelle demande #{req_id}</b>\n"
        f"👤 {nom}\n"
        f"📧 {email}\n"
        f"📦 {libelle} — {montant}{promo}\n\n"
        f"→ Attendez la preuve de paiement puis validez dans l'onglet Admin."
    )
    return _send(text)


def notify_licence_activated(email: str, nom: str, cle: str, formule: str, num_recu: str) -> bool:
    libelle = _LIBELLE.get(formule, formule)
    text = (
        f"✅ <b>Licence activée — {num_recu}</b>\n"
        f"👤 {nom} ({email})\n"
        f"📦 {libelle}\n"
        f"🔑 <code>{cle}</code>\n\n"
        f"Email de confirmation envoyé au client."
    )
    return _send(text)
