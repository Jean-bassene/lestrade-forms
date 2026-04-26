"""
Callbacks onglet Panier — panier centralisé (Apps Script partagé).
L'URL du panier est gérée par l'administrateur dans api_client.CENTRAL_PANIER_URL.
Les utilisateurs sont identifiés par leur email (store-user-email).
"""
import io
import json
import base64
from datetime import datetime
from dash import callback, Output, Input, State, no_update, html, ctx
import dash_bootstrap_components as dbc
import pandas as pd
from ..utils import security, api_client


def register(app):

    # ── Statut email + API + panier central ───────────────────────────────────

    @callback(
        Output("panier-email-status",   "children"),
        Output("panier-central-status", "children"),
        Output("panier-api-status",     "children"),
        Output("panier-quest-select",        "options"),
        Output("panier-sync-quest-select",   "options"),
        Output("panier-dl-quest-select",     "options"),
        Input("interval-refresh",       "n_intervals"),
        Input("store-user-email",       "data"),
    )
    def refresh_panier_status(_n, email):
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
                html.A("Configurer", href="#", id="link-open-email-modal",
                       style={"color": "#245c7c"}),
            ])

        # Statut panier central
        ps = api_client.panier_status()
        if "error" in ps:
            if not api_client.CENTRAL_PANIER_URL:
                central_div = html.Div([
                    html.Span("⚙ Non déployé", style={"color": "#f57f17"}),
                    html.Br(),
                    html.Small("Contactez l'administrateur pour le déploiement.", className="hint"),
                ])
            else:
                central_div = html.Div([
                    html.Span("✗ Panier inaccessible", style={"color": "#c62828"}),
                    html.Br(),
                    html.Small("Vérifiez votre connexion Internet.", className="hint"),
                ])
        else:
            central_div = html.Div([
                html.Span("✓ Panier opérationnel", style={"color": "#2e7d32"}),
                html.Span(f" v{ps.get('version', '?')}", className="hint ms-2"),
                html.Br(),
                html.Small(
                    f"{ps.get('nb_reponses', 0)} réponse(s) au total dans le panier",
                    className="hint",
                ),
            ])

        # Statut API locale
        h = api_client.health()
        if "error" in h:
            api_div = html.Div([
                html.Span("✗ API indisponible", style={"color": "#c62828"}),
                html.Br(),
                html.Small("Lancez : python -m uvicorn lestrade_python.main:app --port 8765",
                            className="hint"),
            ])
        else:
            api_div = html.Div([
                html.Span("✓ API opérationnelle", style={"color": "#2e7d32"}),
                html.Span(f" v{h.get('version', '?')}", className="hint ms-2"),
            ])

        # Options questionnaires
        quests = api_client.get_questionnaires()
        opts = [
            {"label": f"[{q['id']}] {security.sanitize_text(q['nom'], 60)}", "value": q["id"]}
            for q in quests
        ]

        return email_div, central_div, api_div, opts, opts, opts

    # ── Générer QR code ───────────────────────────────────────────────────────

    @callback(
        Output("panier-qr-container", "children"),
        Output("panier-qr-msg",       "children"),
        Input("btn-panier-gen-qr",    "n_clicks"),
        State("panier-quest-select",  "value"),
        prevent_initial_call=True,
    )
    def generate_qr(n_clicks, quest_id):
        if not n_clicks:
            return no_update, no_update

        if not quest_id:
            return no_update, html.Div("Sélectionnez un questionnaire.", className="alert-warn")

        data = api_client.get_questionnaire(int(quest_id))
        if "error" in data:
            return no_update, html.Div(f"Erreur : {data['error']}", className="alert-error")

        q = data.get("questionnaire", {})

        # IP locale
        import socket
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            local_ip = s.getsockname()[0]
            s.close()
        except Exception:
            local_ip = "127.0.0.1"

        # UID questionnaire
        import binascii
        crc   = binascii.crc32(q["nom"].encode()) & 0xFFFFFFFF
        hash4 = format(crc, "08x")[:4].upper()
        uid   = f"LEST-{q['id']:04d}-{hash4}"

        # Payload QR v4 : panier_url = URL centrale
        payload = {"uid": uid, "ip": local_ip, "port": 8765}
        if api_client.CENTRAL_PANIER_URL:
            payload["panier_url"] = api_client.CENTRAL_PANIER_URL
        coordinator_email = api_client.get_config("user_email") or ""
        if coordinator_email:
            payload["coordinator_email"] = coordinator_email

        qr_json = json.dumps(payload)

        try:
            import qrcode
            qr = qrcode.QRCode(version=None,
                               error_correction=qrcode.constants.ERROR_CORRECT_M,
                               box_size=6, border=4)
            qr.add_data(qr_json)
            qr.make(fit=True)
            img = qr.make_image(fill_color="#16324f", back_color="white")
            buf = io.BytesIO()
            img.save(buf, format="PNG")
            buf.seek(0)
            b64 = base64.b64encode(buf.read()).decode()
            img_src = f"data:image/png;base64,{b64}"

            container = html.Div([
                html.Img(src=img_src, style={
                    "maxWidth": "250px",
                    "border": "4px solid #16324f",
                    "borderRadius": "12px",
                }),
                html.P([
                    html.Strong("UID : "), uid,
                    html.Br(),
                    html.Small(f"IP locale : {local_ip}:8765", className="hint"),
                    html.Br(),
                    html.Small(
                        "Panier centralisé : ✓" if api_client.CENTRAL_PANIER_URL
                        else "Panier : non déployé",
                        style={"color": "#2e7d32"} if api_client.CENTRAL_PANIER_URL
                              else {"color": "#f57f17"},
                    ),
                ], className="mt-2"),
            ])
            return container, html.Div("QR généré.", className="alert-success")

        except ImportError:
            return html.Div([
                html.Pre(qr_json, style={
                    "background": "#f4f6f8", "padding": "12px",
                    "borderRadius": "8px", "fontSize": "13px",
                }),
                html.P("Installez qrcode[pil] : pip install qrcode[pil]", className="hint"),
            ]), html.Div("Module qrcode non installé — contenu affiché en texte.", className="alert-warn")

    # ── Sync panier → local ───────────────────────────────────────────────────

    @callback(
        Output("panier-sync-msg",            "children"),
        Input("btn-panier-sync",             "n_clicks"),
        State("panier-sync-quest-select",    "value"),
        State("store-user-email",            "data"),
        State("panier-auto-clear",           "value"),
        prevent_initial_call=True,
    )
    def sync_panier(n_clicks, quest_id, user_email, auto_clear):
        if not n_clicks:
            return no_update

        if not quest_id:
            return html.Div("Sélectionnez un questionnaire cible.", className="alert-warn")

        if not user_email or user_email.startswith("__skip__"):
            return html.Div("Configurez votre email coordinateur d'abord.", className="alert-warn")

        if not api_client.CENTRAL_PANIER_URL:
            return html.Div("Panier non déployé — contactez l'administrateur.", className="alert-warn")

        if not security.rate_limit("panier_sync", max_calls=5, window_s=60):
            return html.Div("Trop de synchronisations. Attendez une minute.", className="alert-warn")

        # Fetch sans filtre email : le mobile n'envoie pas user_email au panier
        result = api_client.fetch_panier_rows("", quest_id=int(quest_id))
        if "error" in result:
            return html.Div(f"Erreur panier : {result['error']}", className="alert-error")

        rows = result.get("reponses", [])
        if not rows:
            return html.Div("Panier vide — aucune réponse à importer.", className="alert-info")

        reponses_batch = []
        for row in rows:
            try:
                donnees = row.get("donnees_json", "{}")
                if not isinstance(donnees, str):
                    donnees = json.dumps(donnees, ensure_ascii=False)
                reponses_batch.append({
                    "donnees_json": donnees,
                    "uuid":         row.get("uuid", ""),
                    "horodateur":   row.get("horodateur", ""),
                })
            except Exception:
                continue

        if not reponses_batch:
            return html.Div("Aucune réponse valide dans le panier.", className="alert-warn")

        try:
            import httpx
            with httpx.Client(base_url="http://127.0.0.1:8765", timeout=30) as c:
                res = c.post("/reponses", json={
                    "quest_id":      int(quest_id),
                    "reponses_full": reponses_batch,
                })
                res.raise_for_status()
                r = res.json()
        except Exception as e:
            return html.Div(f"Erreur API locale : {type(e).__name__}", className="alert-error")

        saved   = r.get("saved",   0)
        skipped = r.get("skipped", 0)

        cleared_msg = ""
        if auto_clear:
            cl = api_client.clear_panier(quest_id=int(quest_id))
            if "error" not in cl:
                cleared_msg = " Panier vidé automatiquement."
            else:
                cleared_msg = " (⚠ Vidage du panier échoué — réessayez manuellement.)"

        return html.Div(
            f"Synchronisation terminée — {saved} réponse(s) importée(s), "
            f"{skipped} doublon(s) ignoré(s).{cleared_msg}",
            className="alert-success",
        )

    # ── Télécharger depuis le panier ──────────────────────────────────────────

    @callback(
        Output("download-panier",    "data"),
        Output("panier-dl-msg",      "children"),
        Input("btn-panier-download", "n_clicks"),
        State("panier-dl-quest-select", "value"),
        State("panier-dl-format",    "value"),
        State("store-user-email",    "data"),
        prevent_initial_call=True,
    )
    def download_panier(n_clicks, quest_id, fmt, user_email):
        if not n_clicks:
            return no_update, no_update

        if not user_email or user_email.startswith("__skip__"):
            return no_update, html.Div("Configurez votre email coordinateur d'abord.", className="alert-warn")

        if not api_client.CENTRAL_PANIER_URL:
            return no_update, html.Div("Panier non déployé — contactez l'administrateur.", className="alert-warn")

        if not security.rate_limit("panier_download", max_calls=5, window_s=60):
            return no_update, html.Div("Trop de téléchargements. Attendez une minute.", className="alert-warn")

        result = api_client.fetch_panier_rows(
            user_email, quest_id=int(quest_id) if quest_id else None
        )
        if "error" in result:
            return no_update, html.Div(f"Erreur : {result['error']}", className="alert-error")

        rows = result.get("reponses", [])
        if not rows:
            return no_update, html.Div("Aucune réponse dans le panier.", className="alert-info")

        # Aplatir donnees_json en colonnes séparées
        flat_rows = []
        for row in rows:
            flat = {
                "quest_id":   row.get("quest_id", ""),
                "horodateur": row.get("horodateur", ""),
            }
            try:
                donnees = row.get("donnees_json", "{}")
                if isinstance(donnees, str):
                    donnees = json.loads(donnees)
                if isinstance(donnees, dict):
                    flat.update(donnees)
            except Exception:
                pass
            flat_rows.append(flat)

        df = pd.DataFrame(flat_rows)

        # Sécurité Excel : neutralise les formules
        def _safe(v):
            s = str(v or "")
            return ("'" + s) if s.startswith(("=", "+", "-", "@")) else s

        for col in df.columns:
            df[col] = df[col].apply(_safe)

        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        quest_suffix = f"_q{quest_id}" if quest_id else ""

        if fmt == "csv":
            csv_str = df.to_csv(index=False, encoding="utf-8-sig")
            fname = f"panier{quest_suffix}_{ts}.csv"
            return dict(content=csv_str, filename=fname,
                        type="text/csv", base64=False), no_update
        else:
            buf = io.BytesIO()
            with pd.ExcelWriter(buf, engine="openpyxl") as writer:
                df.to_excel(writer, index=False, sheet_name="Panier")
            buf.seek(0)
            fname = f"panier{quest_suffix}_{ts}.xlsx"
            return dict(
                content=buf.read(), filename=fname,
                type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                base64=True,
            ), no_update

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

        return False, clean, "", {"display": "none"}, {"color": "#e6a700", "fontWeight": "800"}
