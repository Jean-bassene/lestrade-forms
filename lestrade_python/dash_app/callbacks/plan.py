"""
Callbacks onglet Plan — statut licence, codes promo, demande de clé, activation.
"""
import os
import re
import hashlib
from datetime import date
from dash import callback, Output, Input, State, no_update, html, ctx
import dash_bootstrap_components as dbc
from ..utils import security, api_client

_ADMIN_EMAIL = os.environ.get("LESTRADE_ADMIN_EMAIL", "bassene.jean@yahoo.com")

# ── Codes promo ───────────────────────────────────────────────────────────────
_PROMO_CODES = {
    "LESTRADE2026": {"discount_pct": 30, "expires": "2026-12-31", "label": "Lancement 2026"},
    "ONG2026":      {"discount_pct": 20, "expires": "2026-12-31", "label": "ONG partenaire"},
    "BETA2026":     {"discount_pct": 50, "expires": "2026-09-30", "label": "Testeur bêta"},
}

_BADGE_STYLES = {
    "free":    {"background": "#f3f4f6", "color": "#52606d"},
    "premium": {"background": "#d1fae5", "color": "#065f46"},
}
_BADGE_BASE = {
    "display": "inline-block", "padding": "5px 16px",
    "borderRadius": "999px", "fontWeight": "700", "fontSize": "13px",
}


def _validate_promo(code: str) -> tuple[bool, int, str]:
    """Retourne (valide, discount_pct, message)."""
    code = (code or "").strip().upper()
    if not code:
        return False, 0, "Saisissez un code."
    promo = _PROMO_CODES.get(code)
    if not promo:
        return False, 0, "Code inconnu."
    try:
        if date.fromisoformat(promo["expires"]) < date.today():
            return False, 0, f"Code expiré le {promo['expires']}."
    except Exception:
        pass
    return True, promo["discount_pct"], promo["label"]


def register(app):

    # ── Statut actuel : badge + détail ───────────────────────────────────────

    @callback(
        Output("plan-status-badge",  "children"),
        Output("plan-status-badge",  "style"),
        Output("plan-status-detail", "children"),
        Input("store-licence-key",   "data"),
        Input("store-user-email",    "data"),
    )
    def update_plan_status(licence, email):
        if licence and licence not in ("", "__free__"):
            return "Premium ✓", {**_BADGE_BASE, **_BADGE_STYLES["premium"]}, \
                   "Licence premium active — aucune publicité."
        user = (email or "").strip()
        detail = (f"Connecté en tant que {user}"
                  if user and not user.startswith("__skip__")
                  else "Entrez votre email pour demander une licence.")
        return "Free", {**_BADGE_BASE, **_BADGE_STYLES["free"]}, detail

    # ── Pré-remplir email depuis le store ────────────────────────────────────

    @callback(
        Output("plan-request-email", "value"),
        Output("plan-status-email",  "value"),
        Input("store-user-email",    "data"),
        prevent_initial_call=True,   # ne pas écraser une valeur déjà saisie au chargement
    )
    def prefill_email(email):
        if email and not email.startswith("__skip__"):
            return email, email
        return no_update, no_update

    # ── Pré-remplir la formule depuis les boutons des cartes ─────────────────

    @callback(
        Output("plan-request-formule", "value"),
        Input("btn-plan-annual",       "n_clicks"),
        Input("btn-plan-monthly",      "n_clicks"),
        prevent_initial_call=True,
    )
    def prefill_formule(_ann, _month):
        return "mensuel" if ctx.triggered_id == "btn-plan-monthly" else "annuel"

    # ── Valider et appliquer un code promo ────────────────────────────────────

    @callback(
        Output("plan-promo-msg",   "children"),
        Output("store-promo-code", "data"),
        Input("btn-plan-promo",    "n_clicks"),
        State("plan-promo-input",  "value"),
        prevent_initial_call=True,
    )
    def apply_promo(n, code):
        if not n:
            return no_update, no_update
        if not security.rate_limit("plan_promo", max_calls=10, window_s=60):
            return html.Div("Trop de tentatives.", className="alert-warn"), no_update

        code_upper = (code or "").strip().upper()
        valid, discount, label = _validate_promo(code_upper)
        if not valid:
            return html.Div(f"⚠ {label}", className="alert-error"), no_update

        msg = html.Div([
            html.Span("🎉 Code "),
            html.Code(code_upper, style={
                "background": "#d1fae5", "padding": "1px 6px", "borderRadius": "4px",
            }),
            html.Span(
                f" appliqué — remise de {discount}% sur votre commande",
                style={"fontWeight": "600", "color": "#065f46"},
            ),
        ], className="alert-success")
        return msg, {"code": code_upper, "discount_pct": discount, "label": label}

    # ── Envoyer une demande de licence ────────────────────────────────────────

    @callback(
        Output("plan-request-msg",  "children"),
        Input("btn-plan-request",   "n_clicks"),
        State("plan-request-nom",     "value"),
        State("plan-request-email",   "value"),
        State("plan-request-formule", "value"),
        State("store-promo-code",     "data"),
        prevent_initial_call=True,
    )
    def send_licence_request(n, nom, email, formule, promo):
        if not n:
            return no_update
        if not security.rate_limit("plan_request", max_calls=3, window_s=120):
            return html.Div("Trop de tentatives. Attendez 2 minutes.", className="alert-warn")

        ok, msg = security.validate_email(email)
        if not ok:
            return html.Div(msg, className="alert-error")

        clean_email = str(email).strip().lower()
        clean_nom   = security.sanitize_text(str(nom or clean_email), 200)
        clean_form  = formule if formule in ("annuel", "mensuel") else "annuel"

        promo_code     = promo.get("code")       if promo else None
        promo_discount = promo.get("discount_pct") if promo else None

        res = api_client.create_licence_request(
            nom=clean_nom, email=clean_email, formule=clean_form,
            promo_code=promo_code, promo_discount=promo_discount,
        )

        if "error" in res:
            return html.Div(
                f"Erreur : {security.sanitize_text(res['error'], 200)}",
                className="alert-error",
            )

        prix = "$120/an" if clean_form == "annuel" else "$15/mois"
        promo_line = (
            html.Div([
                html.Span("Code promo : "),
                html.Code(promo_code),
                html.Span(f" (-{promo_discount}%)",
                          style={"color": "#065f46", "fontWeight": "600"}),
            ], className="mt-1")
            if promo_code else None
        )
        return html.Div([
            html.Strong("Demande enregistrée ✓"),
            html.Br(),
            html.Span(
                f"Nous avons reçu votre demande pour le plan Pro {clean_form} ({prix}).",
                style={"fontSize": "13px"},
            ),
            html.Br(),
            html.Span(
                f"Envoyez votre paiement puis écrivez à {_ADMIN_EMAIL} — "
                "votre clé vous sera transmise par email.",
                style={"fontSize": "12px", "color": "#6b7785"},
            ),
            promo_line,
        ], className="alert-success")

    # ── Suivre le statut d'une demande ───────────────────────────────────────

    @callback(
        Output("plan-status-result", "children"),
        Input("btn-plan-check-status", "n_clicks"),
        State("plan-status-email",     "value"),
        prevent_initial_call=True,
    )
    def check_request_status(n, email):
        if not n:
            return no_update
        if not security.rate_limit("plan_status", max_calls=10, window_s=60):
            return html.Div("Trop de tentatives. Attendez une minute.", className="alert-warn")

        ok, msg = security.validate_email(email)
        if not ok:
            return html.Div(msg, className="alert-error")

        res = api_client.check_licence_status(str(email).strip().lower())
        if not res.get("found"):
            return html.Div("Aucune demande trouvée pour cet email.", className="alert-warn")

        statut  = res.get("statut", "en_attente")
        formule = res.get("formule", "")
        date    = (res.get("date") or "")[:16].replace("T", " ")
        recu    = res.get("num_recu") or ""

        _libelle = {"annuel": "Pro Annuel", "mensuel": "Pro Mensuel"}
        _icons   = {"en_attente": "⏳", "validé": "✅", "refusé": "❌"}
        _msgs    = {
            "en_attente": "Votre demande est en cours de traitement — vous recevrez votre clé par email après confirmation du paiement.",
            "validé":     f"Votre licence est activée ! Votre clé a été envoyée à {email}.",
            "refusé":     "Votre demande a été refusée. Contactez-nous pour plus d'informations.",
        }
        _cls = {"en_attente": "alert-warn", "validé": "alert-success", "refusé": "alert-error"}

        children = [
            html.Strong(f"{_icons.get(statut, '')} {statut.replace('_', ' ').capitalize()}"),
            html.Br(),
            html.Span(_libelle.get(formule, formule),
                      style={"fontSize": "13px", "color": "#6b7785"}),
            html.Span(f"  ·  {date}", style={"fontSize": "12px", "color": "#9aa5b1"}),
            html.Br(),
            html.Span(_msgs.get(statut, ""), style={"fontSize": "13px"}),
        ]
        if recu:
            children += [html.Br(), html.Span(f"N° reçu : {recu}",
                         style={"fontSize": "12px", "fontFamily": "monospace"})]

        return html.Div(children, className=_cls.get(statut, "alert-warn") + " mt-2")

    # ── Activer une clé depuis l'onglet Plan ──────────────────────────────────

    @callback(
        Output("store-freemium-seen", "data",  allow_duplicate=True),
        Output("store-licence-key",   "data",  allow_duplicate=True),
        Output("ad-zone",             "style", allow_duplicate=True),
        Output("plan-activate-msg",   "children"),
        Output("plan-activate-error", "children"),
        Output("plan-activate-error", "style"),
        Input("btn-plan-activate",    "n_clicks"),
        State("plan-licence-key",     "value"),
        State("store-user-email",     "data"),
        prevent_initial_call=True,
    )
    def activate_from_plan(n, key, user_email):
        no_err = "", {"display": "none"}
        if not n:
            return no_update, no_update, no_update, no_update, *no_err
        if not security.rate_limit("plan_activate", max_calls=10, window_s=60):
            return (no_update, no_update, no_update, no_update,
                    "Trop de tentatives. Attendez une minute.", {"display": "block"})
        key = (key or "").strip()
        if not _validate_key(key):
            return (no_update, no_update, no_update, no_update,
                    "Format de clé invalide.", {"display": "block"})

        # Vérification en base — clé validée ET liée à l'email utilisateur
        clean_email = (user_email or "").strip().lower()
        valid_email  = clean_email if (clean_email and not clean_email.startswith("__skip__")) else None
        check = api_client.verify_licence_key(key, email=valid_email)
        if not check.get("valid"):
            msg = ("Cette clé est associée à un autre compte email."
                   if check.get("wrong_owner")
                   else "Clé inconnue ou non encore validée — attendez la confirmation de paiement.")
            return (no_update, no_update, no_update, no_update, msg, {"display": "block"})

        return (
            "shown", key, {"display": "none"},
            html.Div("Licence premium activée ! Merci.", className="alert-success"),
            "", {"display": "none"},
        )


# ── Helpers ───────────────────────────────────────────────────────────────────

_KEY_RE = re.compile(r'^[A-Za-z0-9\-_]{12,64}$')

def _validate_key(key: str) -> bool:
    return bool(_KEY_RE.match(key))
