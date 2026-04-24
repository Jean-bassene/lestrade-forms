"""
Callbacks onglet Panier / Drive — statut email, URL panier, QR code, sync.
"""
import json
import io
import base64
from dash import callback, Output, Input, State, no_update, html, ctx
import dash_bootstrap_components as dbc
from ..utils import security, api_client


def register(app):

    # ── Statut email + API ────────────────────────────────────────────────────

    @callback(
        Output("panier-email-status", "children"),
        Output("panier-api-status",   "children"),
        Output("panier-url-input",    "value"),
        Output("panier-quest-select", "options"),
        Output("panier-sync-quest-select", "options"),
        Input("interval-refresh",     "n_intervals"),
        Input("store-user-email",     "data"),
        Input("store-panier-url",     "data"),
    )
    def refresh_panier_status(_n, email, panier_url):
        # Statut email
        if email and not email.startswith("__skip__"):
            email_div = html.Div([
                html.Span("✓ ", style={"color": "#2e7d32", "fontWeight": "700"}),
                html.Strong(security.sanitize_text(email, 100)),
                html.Span(" (configuré)", className="hint ms-2"),
            ])
        elif email and email.startswith("__skip__"):
            email_div = html.Div("— Non configuré (ignoré)", className="hint")
        else:
            email_div = html.Div([
                html.Span("⚠ Email non configuré — ", style={"color": "#f57f17"}),
                html.A("Configurer", href="#", id="link-open-email-modal", style={"color": "#245c7c"}),
            ])

        # Statut API
        h = api_client.health()
        if "error" in h:
            api_div = html.Div([
                html.Span("✗ API indisponible", style={"color": "#c62828"}),
                html.Br(),
                html.Small("Lancez : python -m uvicorn lestrade_python.main:app --port 8765", className="hint"),
            ])
        else:
            api_div = html.Div([
                html.Span("✓ API opérationnelle", style={"color": "#2e7d32"}),
                html.Span(f" v{h.get('version', '?')}", className="hint ms-2"),
            ])

        # URL panier depuis store local
        url_val = panier_url or ""

        # Options questionnaires
        quests = api_client.get_questionnaires()
        opts = [
            {"label": f"[{q['id']}] {security.sanitize_text(q['nom'], 60)}", "value": q["id"]}
            for q in quests
        ]

        return email_div, api_div, url_val, opts, opts

    # ── Enregistrer URL panier ────────────────────────────────────────────────

    @callback(
        Output("store-panier-url", "data"),
        Output("panier-url-msg",   "children"),
        Input("btn-panier-save-url",  "n_clicks"),
        State("panier-url-input",     "value"),
        prevent_initial_call=True,
    )
    def save_panier_url(n_clicks, url):
        if not n_clicks:
            return no_update, no_update

        if not url or not url.strip():
            return no_update, html.Div("URL vide — non enregistrée.", className="alert-warn")

        url = url.strip()
        # Validation basique URL Apps Script
        if not url.startswith("https://script.google.com/"):
            return no_update, html.Div(
                "URL invalide. Doit commencer par https://script.google.com/", className="alert-error"
            )
        if len(url) > 500:
            return no_update, html.Div("URL trop longue.", className="alert-error")

        # Tente de sauvegarder aussi côté API
        api_client.set_config("panier_url", url)

        return url, html.Div("URL panier enregistrée.", className="alert-success")

    # ── Générer QR code ───────────────────────────────────────────────────────

    @callback(
        Output("panier-qr-container", "children"),
        Output("panier-qr-msg",       "children"),
        Input("btn-panier-gen-qr",    "n_clicks"),
        State("panier-quest-select",  "value"),
        State("store-panier-url",     "data"),
        prevent_initial_call=True,
    )
    def generate_qr(n_clicks, quest_id, panier_url):
        if not n_clicks:
            return no_update, no_update

        if not quest_id:
            return no_update, html.Div("Sélectionnez un questionnaire.", className="alert-warn")

        # Récupérer le questionnaire
        data = api_client.get_questionnaire(int(quest_id))
        if "error" in data:
            return no_update, html.Div(f"Erreur : {data['error']}", className="alert-error")

        q = data.get("questionnaire", {})

        # Détecter l'IP locale
        import socket
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            local_ip = s.getsockname()[0]
            s.close()
        except Exception:
            local_ip = "127.0.0.1"

        # Générer l'UID questionnaire
        import binascii
        crc   = binascii.crc32(q["nom"].encode()) & 0xFFFFFFFF
        hash4 = format(crc, "08x")[:4].upper()
        uid   = f"LEST-{q['id']:04d}-{hash4}"

        # Payload QR v2 (avec panier_url si disponible)
        payload = {"uid": uid, "ip": local_ip, "port": 8765}
        if panier_url:
            payload["panier_url"] = panier_url

        qr_json = json.dumps(payload)

        # Générer le QR code image
        try:
            import qrcode
            from PIL import Image as PILImage
            qr = qrcode.QRCode(version=None, error_correction=qrcode.constants.ERROR_CORRECT_M, box_size=6, border=4)
            qr.add_data(qr_json)
            qr.make(fit=True)
            img = qr.make_image(fill_color="#16324f", back_color="white")
            buf = io.BytesIO()
            img.save(buf, format="PNG")
            buf.seek(0)
            b64 = base64.b64encode(buf.read()).decode()
            img_src = f"data:image/png;base64,{b64}"

            container = html.Div([
                html.Img(src=img_src, style={"maxWidth": "250px", "border": "4px solid #16324f", "borderRadius": "12px"}),
                html.P([
                    html.Strong("UID : "), uid,
                    html.Br(),
                    html.Small(f"IP : {local_ip}:8765", className="hint"),
                    html.Br() if panier_url else None,
                    html.Small("Panier : configuré ✓", style={"color": "#2e7d32"}) if panier_url else None,
                ], className="mt-2"),
            ])
            return container, html.Div("QR généré.", className="alert-success")

        except ImportError:
            # Fallback texte si qrcode non installé
            return html.Div([
                html.Pre(qr_json, style={"background": "#f4f6f8", "padding": "12px", "borderRadius": "8px", "fontSize": "13px"}),
                html.P("Installez qrcode[pil] pour afficher l'image : pip install qrcode[pil]", className="hint"),
            ]), html.Div("Module qrcode non installé — contenu affiché en texte.", className="alert-warn")

    # ── Sync panier → local ───────────────────────────────────────────────────

    @callback(
        Output("panier-sync-msg",       "children"),
        Input("btn-panier-sync",        "n_clicks"),
        State("panier-sync-quest-select","value"),
        State("store-panier-url",       "data"),
        prevent_initial_call=True,
    )
    def sync_panier(n_clicks, quest_id, panier_url):
        if not n_clicks:
            return no_update

        if not quest_id:
            return html.Div("Sélectionnez un questionnaire cible.", className="alert-warn")
        if not panier_url:
            return html.Div("URL panier non configurée — allez dans le champ ci-dessus.", className="alert-warn")

        if not security.rate_limit("panier_sync", max_calls=5, window_s=60):
            return html.Div("Trop de synchronisations. Attendez une minute.", className="alert-warn")

        try:
            import httpx
            # GET ?action=list depuis le panier
            r = httpx.get(panier_url, params={"action": "list"}, timeout=15, follow_redirects=True)
            if r.status_code != 200:
                return html.Div(f"Erreur panier HTTP {r.status_code}", className="alert-error")

            panier_data = r.json()
            rows = panier_data if isinstance(panier_data, list) else panier_data.get("data", [])
        except Exception as e:
            return html.Div(f"Erreur réseau : {type(e).__name__}", className="alert-error")

        if not rows:
            return html.Div("Panier vide — aucune réponse à importer.", className="alert-info")

        # Envoi des réponses vers l'API locale
        reponses_batch = []
        for row in rows:
            try:
                if isinstance(row, str):
                    donnees = row
                elif isinstance(row, dict):
                    donnees = json.dumps(row, ensure_ascii=False)
                else:
                    continue
                reponses_batch.append({"donnees_json": donnees})
            except Exception:
                continue

        if not reponses_batch:
            return html.Div("Aucune réponse valide trouvée dans le panier.", className="alert-warn")

        try:
            import httpx
            with httpx.Client(base_url="http://127.0.0.1:8765", timeout=30) as c:
                res = c.post("/reponses", json={"quest_id": int(quest_id), "reponses_full": reponses_batch})
                res.raise_for_status()
                result = res.json()
        except Exception as e:
            return html.Div(f"Erreur API locale : {type(e).__name__}", className="alert-error")

        saved   = result.get("saved",   0)
        skipped = result.get("skipped", 0)
        return html.Div(
            f"Synchronisation terminée — {saved} réponse(s) importée(s), {skipped} doublon(s) ignoré(s).",
            className="alert-success",
        )

    # ── Modal changement email ────────────────────────────────────────────────

    @callback(
        Output("modal-change-email", "is_open"),
        Input("btn-panier-change-email", "n_clicks"),
        Input("btn-email-modal-cancel",  "n_clicks"),
        prevent_initial_call=True,
    )
    def toggle_email_modal(n_open, n_cancel):
        triggered = ctx.triggered_id
        if triggered == "btn-panier-change-email" and n_open:
            return True
        return False

    @callback(
        Output("modal-change-email", "is_open",   allow_duplicate=True),
        Output("store-user-email",   "data",      allow_duplicate=True),
        Output("panier-email-error", "children"),
        Output("panier-email-error", "style"),
        Output("tab-panier",         "label_style", allow_duplicate=True),
        Input("btn-email-modal-confirm", "n_clicks"),
        State("panier-new-email",        "value"),
        prevent_initial_call=True,
    )
    def save_new_email(n_clicks, email):
        if not n_clicks:
            return no_update, no_update, no_update, no_update, no_update

        ok, msg = security.validate_email(email)
        if not ok:
            return no_update, no_update, msg, {"display": "block"}, no_update

        clean = str(email).strip().lower()
        api_client.set_config("user_email", clean)

        return False, clean, "", {"display": "none"}, {"color": "#e6a700", "fontWeight": "700"}
