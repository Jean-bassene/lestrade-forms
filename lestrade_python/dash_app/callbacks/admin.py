"""
Callbacks onglet Admin — authentification par mot de passe, gestion des licences.
Tout est local (SQLite via FastAPI) — aucune dépendance Apps Script.
"""
import os
import hashlib
from dash import callback, Output, Input, State, no_update, html, ctx, ALL
import dash_bootstrap_components as dbc
from ..utils import security, api_client

_ADMIN_EMAIL     = os.environ.get("LESTRADE_ADMIN_EMAIL", "bassene.jean@yahoo.com")
_ADMIN_PASS_HASH = os.environ.get("LESTRADE_ADMIN_PASS", "")  # SHA256 du mot de passe

_STATUT_STYLES = {
    "en_attente": {"background": "#fef3c7", "color": "#92400e",
                   "padding": "2px 10px", "borderRadius": "999px",
                   "fontSize": "11px", "fontWeight": "700"},
    "validé":     {"background": "#d1fae5", "color": "#065f46",
                   "padding": "2px 10px", "borderRadius": "999px",
                   "fontSize": "11px", "fontWeight": "700"},
    "refusé":     {"background": "#fee2e2", "color": "#991b1b",
                   "padding": "2px 10px", "borderRadius": "999px",
                   "fontSize": "11px", "fontWeight": "700"},
}

_TH = {"padding": "8px 12px", "background": "#16324f", "color": "white",
       "textAlign": "left", "fontWeight": "600", "fontSize": "13px"}
_TD = {"padding": "8px 12px", "fontSize": "13px", "verticalAlign": "middle"}


def _badge(statut: str) -> html.Span:
    style = _STATUT_STYLES.get(statut, _STATUT_STYLES["en_attente"])
    labels = {"en_attente": "En attente", "validé": "Validé ✓", "refusé": "Refusé ✗"}
    return html.Span(labels.get(statut, statut), style=style)


def register(app):

    # ── Authentification admin ────────────────────────────────────────────────

    @callback(
        Output("admin-lock-area",    "style"),
        Output("admin-content-area", "style"),
        Input("store-admin-auth",    "data"),
    )
    def toggle_admin_view(auth):
        if auth == "ok":
            return {"display": "none"}, {}
        return {}, {"display": "none"}

    @callback(
        Output("store-admin-auth",  "data"),
        Output("admin-pass-error",  "children"),
        Output("admin-pass-error",  "style"),
        Input("btn-admin-login",    "n_clicks"),
        State("admin-pass-input",   "value"),
        prevent_initial_call=True,
    )
    def check_admin_password(n, password):
        if not n:
            return no_update, no_update, no_update
        if not security.rate_limit("admin_login", max_calls=5, window_s=60):
            return no_update, "Trop de tentatives. Attendez une minute.", {"display": "block"}
        if not _ADMIN_PASS_HASH:
            # Aucun mot de passe configuré → accès direct (mode dev)
            return "ok", "", {"display": "none"}
        entered = hashlib.sha256((password or "").encode()).hexdigest()
        if entered == _ADMIN_PASS_HASH:
            return "ok", "", {"display": "none"}
        return no_update, "Mot de passe incorrect.", {"display": "block"}

    # ── Charger la liste des demandes ─────────────────────────────────────────

    @callback(
        Output("admin-pending-table", "children"),
        Output("admin-req-count",     "children"),
        Input("btn-admin-refresh",    "n_clicks"),
        Input("interval-refresh",     "n_intervals"),
        Input("admin-activate-msg",   "children"),
    )
    def load_requests(_n, _interval, _msg):
        rows = api_client.get_licence_requests()

        nb_att = sum(1 for r in rows if r.get("statut") == "en_attente")
        count_txt = (f"{nb_att} en attente" if nb_att else "Aucune demande en attente")

        if not rows:
            return html.Div("Aucune demande de licence reçue.", className="hint"), count_txt

        tr_rows = []
        for r in rows:
            rid     = r["id"]
            statut  = r.get("statut", "en_attente")
            promo   = r.get("promo_code") or "—"
            remise  = f"  -{r['promo_discount']}%" if r.get("promo_discount") else ""
            date_d  = (r.get("date_demande") or "")[:16].replace("T", " ")
            cle_txt = r.get("cle") or "—"

            action_btns = []
            if statut == "en_attente":
                action_btns = [
                    dbc.Button("✓ Valider", id={"type": "btn-validate-req", "index": rid},
                               color="success", size="sm", className="me-1"),
                    dbc.Button("✗ Refuser", id={"type": "btn-reject-req",   "index": rid},
                               color="danger",  size="sm", outline=True),
                ]
            elif statut == "validé":
                action_btns = [html.Code(cle_txt, style={"fontSize": "12px", "color": "#065f46"})]

            tr_rows.append(html.Tr(style={"opacity": "0.5"} if statut == "refusé" else {}, children=[
                html.Td(rid,   style=_TD),
                html.Td(security.sanitize_text(r.get("nom",   ""), 40), style=_TD),
                html.Td(security.sanitize_text(r.get("email", ""), 60), style=_TD),
                html.Td(r.get("formule", ""), style=_TD),
                html.Td(f"{promo}{remise}", style={**_TD, "fontSize": "12px"}),
                html.Td(_badge(statut), style=_TD),
                html.Td(date_d, style={**_TD, "color": "#6b7785", "fontSize": "12px"}),
                html.Td(action_btns, style=_TD),
            ]))

        table = html.Table([
            html.Thead(html.Tr([
                html.Th("#",        style=_TH),
                html.Th("Nom",      style=_TH),
                html.Th("Email",    style=_TH),
                html.Th("Formule",  style=_TH),
                html.Th("Promo",    style=_TH),
                html.Th("Statut",   style=_TH),
                html.Th("Date",     style=_TH),
                html.Th("Action",   style=_TH),
            ])),
            html.Tbody(tr_rows),
        ], style={"width": "100%", "borderCollapse": "collapse"})

        return table, count_txt

    # ── Valider une demande ───────────────────────────────────────────────────

    @callback(
        Output("admin-activate-msg", "children"),
        Input({"type": "btn-validate-req", "index": ALL}, "n_clicks"),
        prevent_initial_call=True,
    )
    def validate_req(n_clicks):
        if not any(n for n in n_clicks if n):
            return no_update
        if not security.rate_limit("admin_validate", max_calls=30, window_s=60):
            return html.Div("Trop de tentatives.", className="alert-warn")

        req_id = ctx.triggered_id["index"]
        res = api_client.validate_licence_request(int(req_id))

        if "error" in res:
            return html.Div(f"Erreur : {res['error']}", className="alert-error")

        cle   = res.get("cle", "")
        email = res.get("email", "")
        already = res.get("status") == "already_validated"

        return html.Div([
            html.Strong("✓ Licence validée" + (" (déjà validée)" if already else "") + " !"),
            html.Br(),
            html.Span("Clé à envoyer à ", style={"fontSize": "13px"}),
            html.Strong(email, style={"fontSize": "13px"}),
            html.Span(" :", style={"fontSize": "13px"}),
            html.Div(
                html.Code(cle, style={"fontSize": "16px", "fontWeight": "800",
                                      "color": "#065f46", "letterSpacing": "1px"}),
                style={"background": "#d1fae5", "padding": "10px 16px",
                       "borderRadius": "8px", "marginTop": "8px",
                       "display": "inline-block"},
            ),
            html.P("Copiez cette clé et envoyez-la par email au client.",
                   className="hint mt-2"),
        ], className="alert-success mt-2")

    # ── Refuser une demande ───────────────────────────────────────────────────

    @callback(
        Output("admin-activate-msg", "children", allow_duplicate=True),
        Input({"type": "btn-reject-req", "index": ALL}, "n_clicks"),
        prevent_initial_call=True,
    )
    def reject_req(n_clicks):
        if not any(n for n in n_clicks if n):
            return no_update
        req_id = ctx.triggered_id["index"]
        res = api_client.reject_licence_request(int(req_id))
        if "error" in res:
            return html.Div(f"Erreur : {res['error']}", className="alert-error")
        return html.Div(f"Demande #{req_id} refusée.", className="alert-warn mt-2")

    # ── Générer une clé manuellement ─────────────────────────────────────────

    @callback(
        Output("admin-generate-msg",    "children"),
        Output("admin-generated-key",   "children"),
        Output("admin-email-input",     "value"),
        Input("btn-admin-generate-key", "n_clicks"),
        State("admin-email-input",      "value"),
        State("admin-formule-input",    "value"),
        prevent_initial_call=True,
    )
    def generate_key(n_clicks, email, formule):
        if not n_clicks:
            return no_update, no_update, no_update
        if not security.rate_limit("admin_generate", max_calls=10, window_s=60):
            return html.Div("Trop de tentatives.", className="alert-warn"), no_update, no_update

        ok, msg = security.validate_email(email)
        if not ok:
            return html.Div(msg, className="alert-error"), no_update, no_update

        res = api_client.generate_licence_key(
            email=str(email).strip().lower(),
            formule=formule or "annuel",
        )
        if "error" in res:
            return html.Div(f"Erreur : {res['error']}", className="alert-error"), no_update, no_update

        cle = res.get("cle", "")
        return (
            html.Div(f"✓ Clé générée pour {res.get('email', '')}.", className="alert-success"),
            html.Code(cle, style={"fontSize": "14px", "color": "#065f46",
                                  "background": "#d1fae5", "padding": "4px 10px",
                                  "borderRadius": "6px"}),
            "",
        )

    # ── Sauvegarder la base ───────────────────────────────────────────────────

    @callback(
        Output("download-db-backup", "data"),
        Output("admin-backup-msg",   "children"),
        Input("btn-admin-backup",    "n_clicks"),
        prevent_initial_call=True,
    )
    def backup_database(n):
        import os, base64, shutil, tempfile
        from datetime import datetime
        if not n:
            return no_update, no_update
        db_path = os.getenv("LESTRADE_DB_PATH", "questionnaires.db")
        if not os.path.exists(db_path):
            return no_update, html.Div("Base introuvable.", className="alert-error")
        tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".db")
        tmp.close()
        shutil.copy2(db_path, tmp.name)
        with open(tmp.name, "rb") as f:
            b64 = base64.b64encode(f.read()).decode()
        os.unlink(tmp.name)
        fname = f"lestrade_backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}.db"
        return (dict(content=b64, filename=fname, base64=True,
                     type="application/octet-stream"),
                html.Div(f"Sauvegarde téléchargée : {fname}", className="alert-success"))

    # ── Restaurer la base ─────────────────────────────────────────────────────

    @callback(
        Output("admin-backup-msg", "children", allow_duplicate=True),
        Input("upload-admin-restore", "contents"),
        State("upload-admin-restore", "filename"),
        prevent_initial_call=True,
    )
    def restore_database(contents, filename):
        import base64
        if not contents:
            return no_update
        if not (filename or "").endswith(".db"):
            return html.Div("Fichier invalide — choisissez un fichier .db", className="alert-error")

        # Décoder le base64 envoyé par dcc.Upload
        _, b64 = contents.split(",", 1)
        file_bytes = base64.b64decode(b64)

        # Valider la signature SQLite
        if file_bytes[:16] != b"SQLite format 3\x00":
            return html.Div("Ce fichier n'est pas une base SQLite valide.", className="alert-error")

        res = api_client.restore_database(file_bytes)
        if "error" in res:
            return html.Div(f"Erreur : {res['error']}", className="alert-error")
        return html.Div(
            "✓ Base restaurée avec succès. Rafraîchissez la page pour voir les données.",
            className="alert-success",
        )

    # ── Statut clé Anthropic ─────────────────────────────────────────────────

    @callback(
        Output("admin-anthropic-status", "children"),
        Input("interval-refresh", "n_intervals"),
    )
    def load_anthropic_status(_n):
        if os.environ.get("ANTHROPIC_API_KEY", ""):
            return "✓ via .env"
        stored = api_client.get_config("anthropic_api_key") or ""
        if stored:
            return f"✓ configurée ({stored[:8]}…)"
        return "⚠ non configurée"

    # ── Enregistrer la clé Anthropic ─────────────────────────────────────────

    @callback(
        Output("admin-anthropic-msg",    "children"),
        Output("admin-anthropic-status", "children", allow_duplicate=True),
        Output("admin-anthropic-key",    "value"),
        Input("btn-admin-save-anthropic","n_clicks"),
        State("admin-anthropic-key",     "value"),
        prevent_initial_call=True,
    )
    def save_anthropic_key(n_clicks, key):
        if not n_clicks:
            return no_update, no_update, no_update
        key = (key or "").strip()
        if not key.startswith("sk-"):
            return html.Div("Clé invalide — doit commencer par sk-", className="alert-error"), no_update, no_update
        if not security.rate_limit("admin_anthropic", max_calls=5, window_s=60):
            return html.Div("Trop de tentatives.", className="alert-warn"), no_update, no_update
        res = api_client.set_config("anthropic_api_key", key)
        if "error" in res:
            return html.Div(f"Erreur d'enregistrement : {res['error']}", className="alert-error"), no_update, no_update
        return (
            html.Div("Clé enregistrée — l'analyse IA est disponible.", className="alert-success"),
            f"✓ configurée ({key[:8]}…)",
            "",
        )
