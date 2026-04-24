"""
Callbacks onglet Admin — gestion des licences via Apps Script.
- Liste les demandes en attente
- Active une clé sur confirmation de paiement
- Génère et envoie une clé manuellement
"""
import hashlib
import httpx
from dash import callback, Output, Input, State, no_update, html, ctx
import dash_bootstrap_components as dbc
from ..utils import security, api_client

# Token admin : SHA256(email admin)[:16].upper()  — même calcul que R
_ADMIN_TOKEN = hashlib.sha256("bassene.jean@yahoo.com".encode()).hexdigest()[:16].upper()

_TIMEOUT = httpx.Timeout(connect=5.0, read=15.0, write=10.0, pool=5.0)


def _get_panier_url() -> str | None:
    return api_client.get_config("panier_url")


def _apps_script_get(url: str, params: dict) -> dict | None:
    try:
        r = httpx.get(url, params=params, timeout=_TIMEOUT, follow_redirects=True)
        if r.status_code == 200:
            return r.json()
    except Exception:
        pass
    return None


def _apps_script_post(url: str, data: dict) -> dict | None:
    try:
        r = httpx.post(url, json=data, timeout=_TIMEOUT, follow_redirects=True)
        if r.status_code == 200:
            return r.json()
    except Exception:
        pass
    return None


def register(app):

    # ── Charger les demandes en attente ───────────────────────────────────────

    @callback(
        Output("admin-pending-table",  "children"),
        Output("admin-panier-status",  "children"),
        Input("btn-admin-refresh",     "n_clicks"),
        Input("interval-refresh",      "n_intervals"),
        Input("admin-activate-msg",    "children"),
    )
    def load_pending(_n, _interval, _msg):
        panier_url = _get_panier_url()
        if not panier_url:
            return (
                html.Div("Panier non configuré — allez dans l'onglet Panier / Drive.", className="alert-warn"),
                "⚠ Panier non configuré",
            )

        data = _apps_script_get(panier_url, {"action": "list_pending"})
        if data is None:
            return (
                html.Div("Impossible de contacter le panier.", className="alert-error"),
                "✗ Panier inaccessible",
            )

        pending = data.get("pending", [])
        status_txt = f"✓ {len(pending)} demande(s) en attente"

        if not pending:
            return html.Div("Aucune demande en attente.", className="hint"), status_txt

        rows = []
        for p in pending:
            cle   = security.sanitize_text(str(p.get("cle",     "")), 50)
            email = security.sanitize_text(str(p.get("email",   "")), 100)
            nom   = security.sanitize_text(str(p.get("nom",     "")), 100)
            fmt   = security.sanitize_text(str(p.get("formule", "")), 30)
            date_ = security.sanitize_text(str(p.get("date",    "")), 30)
            rows.append(html.Tr([
                html.Td(cle,   style={"fontFamily": "monospace", "fontSize": "13px", "padding": "8px"}),
                html.Td(email, style={"padding": "8px"}),
                html.Td(nom,   style={"padding": "8px"}),
                html.Td(fmt,   style={"padding": "8px"}),
                html.Td(date_, style={"padding": "8px"}),
                html.Td(
                    dbc.Button("Activer", id={"type": "btn-activate-cle", "index": cle},
                               color="success", size="sm"),
                    style={"padding": "8px"},
                ),
            ]))

        table = html.Table(
            [
                html.Thead(html.Tr([
                    html.Th("Clé",      style={"padding": "8px", "background": "#16324f", "color": "white"}),
                    html.Th("Email",    style={"padding": "8px", "background": "#16324f", "color": "white"}),
                    html.Th("Nom",      style={"padding": "8px", "background": "#16324f", "color": "white"}),
                    html.Th("Formule",  style={"padding": "8px", "background": "#16324f", "color": "white"}),
                    html.Th("Date",     style={"padding": "8px", "background": "#16324f", "color": "white"}),
                    html.Th("Action",   style={"padding": "8px", "background": "#16324f", "color": "white"}),
                ])),
                html.Tbody(rows),
            ],
            style={"width": "100%", "borderCollapse": "collapse", "fontSize": "14px"},
        )
        return table, status_txt

    # ── Activer une clé depuis le tableau ─────────────────────────────────────

    @callback(
        Output("admin-activate-msg",         "children"),
        Output("store-admin-activate-cle",   "data"),
        Input({"type": "btn-activate-cle", "index": "*"}, "n_clicks"),
        prevent_initial_call=True,
    )
    def activate_cle(n_clicks):
        triggered = ctx.triggered_id
        if not triggered or not any(n_clicks):
            return no_update, no_update

        cle = triggered.get("index", "")
        if not cle:
            return html.Div("Clé introuvable.", className="alert-error"), no_update

        if not security.rate_limit("admin_activate", max_calls=20, window_s=60):
            return html.Div("Trop de tentatives. Attendez une minute.", className="alert-warn"), no_update

        panier_url = _get_panier_url()
        if not panier_url:
            return html.Div("Panier non configuré.", className="alert-error"), no_update

        resp = _apps_script_post(panier_url, {
            "action":      "admin_activate",
            "cle":         cle,
            "admin_token": _ADMIN_TOKEN,
        })

        if resp and resp.get("status") == "ok":
            return html.Div(f"✓ Clé {cle} activée avec succès.", className="alert-success"), cle

        msg = resp.get("message", "Erreur inconnue") if resp else "Pas de réponse du panier"
        return html.Div(f"Erreur : {security.sanitize_text(msg, 200)}", className="alert-error"), no_update

    # ── Générer une clé manuellement ─────────────────────────────────────────

    @callback(
        Output("admin-generate-msg",   "children"),
        Output("admin-generated-key",  "children"),
        Output("admin-email-input",    "value"),
        Input("btn-admin-generate-key","n_clicks"),
        State("admin-email-input",     "value"),
        State("admin-formule-input",   "value"),
        prevent_initial_call=True,
    )
    def generate_key(n_clicks, email, formule):
        if not n_clicks:
            return no_update, no_update, no_update

        if not security.rate_limit("admin_generate", max_calls=10, window_s=60):
            return html.Div("Trop de tentatives. Attendez.", className="alert-warn"), no_update, no_update

        ok, msg = security.validate_email(email)
        if not ok:
            return html.Div(msg, className="alert-error"), no_update, no_update

        panier_url = _get_panier_url()
        if not panier_url:
            return html.Div("Panier non configuré.", className="alert-error"), no_update, no_update

        clean_email = str(email).strip().lower()
        resp = _apps_script_post(panier_url, {
            "action":  "request_licence",
            "nom":     clean_email,
            "email":   clean_email,
            "formule": formule or "annuel",
        })

        if resp and resp.get("status") == "ok":
            cle = security.sanitize_text(str(resp.get("cle", "")), 50)
            return (
                html.Div(f"✓ Clé générée et envoyée à {clean_email}", className="alert-success"),
                cle,
                "",
            )

        msg_err = resp.get("message", "Génération échouée") if resp else "Pas de réponse du panier"
        return html.Div(f"Erreur : {security.sanitize_text(msg_err, 200)}", className="alert-error"), no_update, no_update
