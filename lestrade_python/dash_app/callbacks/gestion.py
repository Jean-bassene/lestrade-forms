"""
Callbacks onglet Gestion — CRUD questionnaires, métriques globales, navigation.
"""
import io
import json
import base64
import binascii
import socket
from dash import callback, Output, Input, State, no_update, ctx, html
from ..utils import security, api_client


def register(app):

    # ── Métriques globales (header + onglet Accueil) ─────────────────────────

    @callback(
        Output("acc-metric-quest",      "children"),
        Output("acc-metric-sec",        "children"),
        Output("acc-metric-q",          "children"),
        Output("acc-metric-rep",        "children"),
        Output("table-questionnaires",  "data"),
        Input("interval-refresh",       "n_intervals"),
        Input("gestion-create-msg",     "children"),
        Input("gestion-action-msg",     "children"),
        Input("store-user-email",       "data"),
    )
    def refresh_metrics(_n, _create, _action, user_email):
        clean = (user_email or "").strip().lower()
        owner = clean if (clean and not clean.startswith("__skip__")) else None
        quests = api_client.get_questionnaires(owner_email=owner)
        nb_q   = len(quests)
        nb_s   = sum(q.get("nb_sections",  0) for q in quests)
        nb_qu  = sum(q.get("nb_questions", 0) for q in quests)

        nb_rep = 0
        rows = []
        for q in quests:
            nb_r = len(api_client.get_reponses(q["id"]))
            nb_rep += nb_r
            rows.append({
                "id":            q.get("id", ""),
                "nom":           security.sanitize_text(q.get("nom", ""), 100),
                "description":   security.sanitize_text(q.get("description", "") or "", 120),
                "nb_sections":   q.get("nb_sections",  0),
                "nb_questions":  q.get("nb_questions", 0),
                "nb_reponses":   nb_r,
                "date_creation": (q.get("date_creation") or "")[:19].replace("T", " "),
            })

        s = str(nb_q), str(nb_s), str(nb_qu), str(nb_rep)
        return *s, rows

    # ── Créer questionnaire ───────────────────────────────────────────────────

    @callback(
        Output("gestion-create-msg",   "children"),
        Output("input-nom-quest",      "value"),
        Output("input-desc-quest",     "value"),
        Input("btn-creer-quest",       "n_clicks"),
        State("input-nom-quest",       "value"),
        State("input-desc-quest",      "value"),
        State("store-licence-key",     "data"),
        State("store-user-email",      "data"),
        prevent_initial_call=True,
    )
    def creer_questionnaire(n_clicks, nom, desc, licence, user_email):
        if not n_clicks:
            return no_update, no_update, no_update

        # Rate limiting — 20 créations / minute
        if not security.rate_limit("create_quest", max_calls=20, window_s=60):
            return _warn("Trop de créations. Attendez une minute."), no_update, no_update

        # Limite freemium : max 3 questionnaires en plan Free
        if not security.is_premium(licence):
            existing = api_client.get_questionnaires()
            if len(existing) >= security.FREE_QUEST_LIMIT:
                return _warn(
                    f"🔒 Limite Free : {security.FREE_QUEST_LIMIT} questionnaires maximum. "
                    "Passez au plan Pro (onglet Plan) pour en créer davantage."
                ), no_update, no_update

        ok, msg = security.validate_name(nom, "Nom du questionnaire")
        if not ok:
            return _err(msg), no_update, no_update

        if desc:
            ok2, msg2 = security.validate_name(desc, "Description")
            if not ok2:
                return _err(msg2), no_update, no_update

        clean_nom  = security.sanitize_text(nom,  200)
        clean_desc = security.sanitize_text(desc or "", 1000)
        clean_email = (user_email or "").strip().lower()
        owner = clean_email if (clean_email and not clean_email.startswith("__skip__")) else None

        res = api_client.create_questionnaire(clean_nom, clean_desc, owner_email=owner)
        if "error" in res:
            return _err(f"Erreur : {res['error']}"), no_update, no_update

        return _ok(f"Questionnaire « {clean_nom} » créé (ID {res['id']})."), "", ""

    # ── Sélection et navigation ───────────────────────────────────────────────

    @callback(
        Output("store-selected-quest-id", "data"),
        Input("table-questionnaires",     "selected_rows"),
        State("table-questionnaires",     "data"),
    )
    def store_selected(selected_rows, data):
        if not selected_rows or not data:
            return None
        return data[selected_rows[0]]["id"]

    @callback(
        Output("main-tabs", "active_tab", allow_duplicate=True),
        Input("btn-goto-build",       "n_clicks"),
        Input("btn-goto-fill",        "n_clicks"),
        Input("btn-goto-reponses",    "n_clicks"),
        Input("btn-goto-analytics",   "n_clicks"),
        Input("btn-goto-panier",      "n_clicks"),
        Input("btn-acc-gestion",      "n_clicks"),
        Input("btn-acc-construction", "n_clicks"),
        Input("btn-acc-remplir",      "n_clicks"),
        Input("btn-acc-reponses",     "n_clicks"),
        Input("btn-acc-analytics",    "n_clicks"),
        Input("btn-acc-import",       "n_clicks"),
        prevent_initial_call=True,
    )
    def navigate_tabs(*_):
        mapping = {
            "btn-goto-build":       "construction",
            "btn-goto-fill":        "remplir",
            "btn-goto-reponses":    "reponses",
            "btn-goto-analytics":   "analytics",
            "btn-goto-panier":      "panier",
            "btn-acc-gestion":      "gestion",
            "btn-acc-construction": "construction",
            "btn-acc-remplir":      "remplir",
            "btn-acc-reponses":     "reponses",
            "btn-acc-analytics":    "analytics",
            "btn-acc-import":       "import",
        }
        triggered = ctx.triggered_id
        return mapping.get(triggered, no_update)

    # ── QR code inline par questionnaire sélectionné ─────────────────────────

    @callback(
        Output("gestion-qr-panel", "children"),
        Input("table-questionnaires", "selected_rows"),
        State("table-questionnaires", "data"),
    )
    def show_qr_for_selected(selected_rows, data):
        if not selected_rows or not data:
            return None

        row = data[selected_rows[0]]
        quest_id = row.get("id")
        nom      = row.get("nom", "")

        # Générer UID
        crc   = binascii.crc32(nom.encode()) & 0xFFFFFFFF
        hash4 = format(crc, "08x")[:4].upper()
        uid   = f"LEST-{quest_id:04d}-{hash4}"

        # IP locale
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            try:
                s.connect(("8.8.8.8", 80))
                local_ip = s.getsockname()[0]
            finally:
                s.close()
        except Exception:
            local_ip = "127.0.0.1"

        payload = {"uid": uid, "ip": local_ip, "port": 8765}
        if api_client.CENTRAL_PANIER_URL:
            payload["panier_url"] = api_client.CENTRAL_PANIER_URL
        # Email coordinateur → le mobile l'envoie avec chaque réponse au panier
        coordinator_email = api_client.get_config("user_email") or ""
        if coordinator_email:
            payload["coordinator_email"] = coordinator_email

        try:
            import qrcode
            qr = qrcode.QRCode(version=None,
                               error_correction=qrcode.constants.ERROR_CORRECT_M,
                               box_size=5, border=3)
            qr.add_data(json.dumps(payload))
            qr.make(fit=True)
            img = qr.make_image(fill_color="#16324f", back_color="white")
            buf = io.BytesIO()
            img.save(buf, format="PNG")
            buf.seek(0)
            b64 = base64.b64encode(buf.read()).decode()
            img_src = f"data:image/png;base64,{b64}"

            return html.Div(className="card", style={"display": "flex", "gap": "20px",
                                                      "alignItems": "flex-start",
                                                      "flexWrap": "wrap"}, children=[
                html.Img(src=img_src, style={"width": "160px", "borderRadius": "8px",
                                             "border": "3px solid #16324f"}),
                html.Div([
                    html.Div(className="badge-step", children="QR Questionnaire"),
                    html.P([html.Strong(security.sanitize_text(nom, 80))],
                           style={"margin": "4px 0 2px"}),
                    html.P([html.Span("UID : ", style={"fontWeight": "600"}), uid],
                           style={"fontFamily": "monospace", "fontSize": "13px", "margin": "2px 0"}),
                    html.P([html.Span("IP : ", style={"fontWeight": "600"}),
                            f"{local_ip}:8765"],
                           className="hint", style={"margin": "2px 0"}),
                    html.P("Scannez avec l'app mobile pour importer ce questionnaire.",
                           className="hint", style={"marginTop": "6px"}),
                ]),
            ])
        except ImportError:
            return html.Div(className="alert-warn", children=[
                html.Strong("Module qrcode non installé — "),
                html.Code(json.dumps(payload), style={"fontSize": "12px"}),
                html.P("pip install qrcode[pil]", className="hint"),
            ])

    # ── Publier questionnaire vers panier (Apps Script Questionnaires sheet) ──

    @callback(
        Output("gestion-action-msg", "children", allow_duplicate=True),
        Input("btn-publish-quest",          "n_clicks"),
        State("store-selected-quest-id",    "data"),
        prevent_initial_call=True,
    )
    def publish_quest(n_clicks, quest_id):
        if not n_clicks or not quest_id:
            return _warn("Sélectionnez un questionnaire avant de publier.")

        if not api_client.CENTRAL_PANIER_URL:
            return _warn("Panier non configuré — contactez l'administrateur.")

        data = api_client.get_questionnaire(int(quest_id))
        if "error" in data:
            return _err(f"Erreur API : {data['error']}")

        q     = data.get("questionnaire", {})
        nom   = q.get("nom", "")
        crc   = binascii.crc32(nom.encode()) & 0xFFFFFFFF
        hash4 = format(crc, "08x")[:4].upper()
        uid   = f"LEST-{int(quest_id):04d}-{hash4}"

        res = api_client.publish_quest_to_panier(uid, nom, data)
        if "error" in res:
            return _err(f"Erreur publication : {res['error']}")

        action = res.get("action", "ok")
        return _ok(f"Questionnaire publié vers le panier ({action}) — UID : {uid}")

    # ── Suppression questionnaire ─────────────────────────────────────────────

    @callback(
        Output("modal-confirm-delete-quest", "is_open"),
        Output("store-quest-to-delete",      "data"),
        Input("btn-supprimer-quest",         "n_clicks"),
        State("store-selected-quest-id",     "data"),
        prevent_initial_call=True,
    )
    def open_delete_modal(n_clicks, quest_id):
        if not n_clicks or not quest_id:
            return no_update, no_update
        return True, quest_id

    @callback(
        Output("modal-confirm-delete-quest", "is_open",  allow_duplicate=True),
        Output("gestion-action-msg",         "children"),
        Input("btn-delete-quest-confirm",    "n_clicks"),
        Input("btn-delete-quest-cancel",     "n_clicks"),
        State("store-quest-to-delete",       "data"),
        prevent_initial_call=True,
    )
    def confirm_delete(n_confirm, n_cancel, quest_id):
        triggered = ctx.triggered_id
        if triggered == "btn-delete-quest-cancel" or not n_confirm:
            return False, no_update

        if not security.rate_limit("delete_quest", max_calls=10, window_s=60):
            return False, _warn("Trop de suppressions. Attendez une minute.")

        if not quest_id:
            return False, _err("Aucun questionnaire sélectionné.")

        res = api_client.delete_questionnaire(int(quest_id))
        if "error" in res:
            return False, _err(f"Erreur : {res['error']}")
        return False, _ok(f"Questionnaire {quest_id} supprimé.")


# ── Helpers UI ────────────────────────────────────────────────────────────────

def _ok(msg):
    return html.Div(msg, className="alert-success mt-2")

def _err(msg):
    return html.Div(msg, className="alert-error mt-2")

def _warn(msg):
    return html.Div(msg, className="alert-warn mt-2")
