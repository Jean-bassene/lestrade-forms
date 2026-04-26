"""
Envoi d'emails SMTP — licence requests et confirmations.
Config lue depuis les variables d'environnement (chargées par dotenv au démarrage).
"""
import os
import smtplib
import ssl
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

_APP_NAME = "Lestrade Forms"
_SEP = "─" * 46

_TARIFS  = {"annuel": "$120/an (~75 000 FCFA)", "mensuel": "$15/mois (~10 000 FCFA)"}
_LIBELLE = {"annuel": "Pro Annuel",              "mensuel": "Pro Mensuel"}


def _cfg() -> dict:
    return {
        "host":     os.environ.get("SMTP_HOST",  "smtp.gmail.com"),
        "port":     int(os.environ.get("SMTP_PORT", "587")),
        "user":     os.environ.get("SMTP_USER",  ""),
        "password": os.environ.get("SMTP_PASS",  ""),
        "from_hdr": os.environ.get("SMTP_FROM",  f"{_APP_NAME} <noreply@lestrade-forms.com>"),
    }


def _send(to: str, subject: str, body: str) -> bool:
    """Envoie un email via SMTP TLS. Retourne True si succès, False sinon (silencieux)."""
    cfg = _cfg()
    if not cfg["user"] or not cfg["password"]:
        return False
    try:
        msg = MIMEMultipart()
        msg["From"]    = cfg["from_hdr"]
        msg["To"]      = to
        msg["Subject"] = subject
        msg.attach(MIMEText(body, "plain", "utf-8"))

        ctx = ssl.create_default_context()
        with smtplib.SMTP(cfg["host"], cfg["port"], timeout=15) as srv:
            srv.ehlo()
            srv.starttls(context=ctx)
            srv.login(cfg["user"], cfg["password"])
            srv.sendmail(cfg["user"], [to], msg.as_string())
        return True
    except Exception as exc:
        if os.environ.get("LESTRADE_DEBUG"):
            print(f"[mailer] SMTP error → {type(exc).__name__}: {exc}")
        return False


# ── Email 1 : Notification admin (nouvelle demande) ──────────────────────────

def notify_admin_new_request(req_id: int, nom: str, email: str, formule: str,
                              promo_code: str | None, promo_discount: int | None) -> bool:
    admin_email = os.environ.get("LESTRADE_ADMIN_EMAIL", "bassene.jean@yahoo.com")
    wave        = os.environ.get("LESTRADE_WAVE", "(configurer LESTRADE_WAVE dans .env)")
    libelle     = _LIBELLE.get(formule, formule)
    montant     = _TARIFS.get(formule, formule)
    promo_txt   = f"\n  Promo    : {promo_code} (-{promo_discount}%)" if promo_code else ""

    body = (
        f"Nouvelle demande de licence #{req_id} reçue.\n\n"
        f"  Nom      : {nom}\n"
        f"  Email    : {email}\n"
        f"  Formule  : {libelle} — {montant}{promo_txt}\n\n"
        f"→ Attendez la preuve de paiement Wave ({wave}),\n"
        f"  puis validez depuis l'onglet Admin."
    )
    subject = f"[{_APP_NAME}] Demande #{req_id} — {nom} ({libelle})"
    return _send(admin_email, subject, body)


# ── Email 2 : Reçu + clé au client (validation admin) ────────────────────────

def send_licence_activated(to: str, nom: str, cle: str, formule: str, num_recu: str) -> bool:
    admin_email = os.environ.get("LESTRADE_ADMIN_EMAIL", "bassene.jean@yahoo.com")
    wave        = os.environ.get("LESTRADE_WAVE", "(configurer LESTRADE_WAVE dans .env)")
    libelle     = _LIBELLE.get(formule, formule)
    montant     = _TARIFS.get(formule, formule)

    body = (
        f"Bonjour {nom},\n\n"
        f"Votre paiement a été reçu et votre licence est activée. Merci !\n\n"
        f"{_SEP}\n"
        f"  REÇU — {_APP_NAME}\n"
        f"  N° {num_recu}\n"
        f"{_SEP}\n"
        f"  Formule  : {libelle}\n"
        f"  Montant  : {montant}\n"
        f"  Clé      : {cle}\n"
        f"{_SEP}\n\n"
        f"Activer votre licence dans l'application :\n"
        f"  1. Ouvrez Lestrade Forms\n"
        f"  2. Allez dans l'onglet Plan\n"
        f"  3. Collez votre clé : {cle}\n"
        f"  4. Cliquez « Activer la licence » → accès premium immédiat\n\n"
        f"Conservez cet email comme preuve de paiement.\n\n"
        f"Merci pour votre confiance !\n"
        f"L'équipe {_APP_NAME}\n"
        f"{admin_email} · Wave : {wave}"
    )
    subject = f"[{_APP_NAME}] ✓ Licence activée — {num_recu}"
    return _send(to, subject, body)
