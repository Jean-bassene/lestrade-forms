"""
Callbacks onglet Réponses — tableau, export Excel sécurisé, suppression, détail, carte GPS.
"""
import io
import json
from datetime import datetime, date
from dash import callback, Output, Input, State, no_update, html, ctx
import plotly.graph_objects as go
import pandas as pd
from ..utils import security, api_client


def register(app):

    # ── Sync dropdown depuis sélection Gestion ────────────────────────────────

    @callback(
        Output("rep-quest-select", "value"),
        Input("store-selected-quest-id", "data"),
    )
    def sync_rep_dropdown(quest_id):
        return quest_id

    # ── Chargement du tableau ─────────────────────────────────────────────────

    @callback(
        Output("table-reponses",          "columns"),
        Output("table-reponses",          "data"),
        Input("rep-quest-select",         "value"),
        Input("rep-date-range",           "start_date"),
        Input("rep-date-range",           "end_date"),
        Input("rep-action-msg",           "children"),
        Input("btn-refresh-reponses",     "n_clicks"),
    )
    def load_reponses(quest_id, start, end, _msg, _refresh):
        if not quest_id:
            return [], []

        rows = api_client.get_reponses_wide(int(quest_id))

        # Fallback : si reponses_wide vide (pas de questions locales), afficher raw
        if not rows:
            raw = api_client.get_reponses(int(quest_id))
            if not raw:
                return [{"name": "Info", "id": "msg"}], [{"msg": "Aucune réponse enregistrée."}]
            flat = []
            for r in raw:
                row = {"reponse_id": r.get("id", ""), "horodateur": str(r.get("horodateur", ""))}
                try:
                    d = json.loads(r.get("donnees_json") or "{}")
                    row.update({str(k): str(v) for k, v in d.items()})
                except Exception:
                    row["donnees_json"] = r.get("donnees_json", "")
                flat.append(row)
            rows = flat

        # Filtre dates
        if start or end:
            filtered = []
            for r in rows:
                horo = r.get("horodateur", "")
                try:
                    d = datetime.fromisoformat(str(horo)[:19]).date()
                    if start and d < date.fromisoformat(start):
                        continue
                    if end and d > date.fromisoformat(end):
                        continue
                except Exception:
                    pass
                filtered.append(r)
            rows = filtered

        # Sanitise toutes les valeurs
        clean_rows = []
        for r in rows:
            clean_r = {}
            for k, v in r.items():
                clean_r[security.sanitize_text(str(k), 100)] = security.sanitize_text(str(v or ""), 200)
            clean_rows.append(clean_r)

        if not clean_rows:
            return [], []

        cols = [{"name": k, "id": k} for k in clean_rows[0].keys()]
        return cols, clean_rows

    # ── Export Excel ──────────────────────────────────────────────────────────

    @callback(
        Output("download-excel",  "data"),
        Output("rep-action-msg",  "children", allow_duplicate=True),
        Input("btn-export-excel",  "n_clicks"),
        State("rep-quest-select",  "value"),
        State("store-licence-key", "data"),
        prevent_initial_call=True,
    )
    def export_excel(n_clicks, quest_id, licence):
        if not n_clicks or not quest_id:
            return no_update, no_update
        if not security.is_premium(licence):
            return no_update, html.Div(
                "🔒 Export Excel — fonctionnalité Pro. "
                "L'export CSV reste disponible gratuitement. "
                "Rendez-vous dans l'onglet Plan.",
                className="alert-warn",
            )

        rows = api_client.get_reponses_wide(int(quest_id))
        if not rows:
            return no_update, html.Div("Aucune réponse à exporter.", className="alert-warn")

        df = pd.DataFrame(rows)

        # Sécurité export Excel : neutralise les formules (injection CSV/XLSX)
        def _safe_cell(v):
            s = str(v or "")
            if s.startswith(("=", "+", "-", "@", "\t", "\r")):
                return "'" + s   # préfixe apostrophe — Excel traite comme texte
            return s

        for col in df.columns:
            df[col] = df[col].apply(_safe_cell)

        buffer = io.BytesIO()
        with pd.ExcelWriter(buffer, engine="openpyxl") as writer:
            df.to_excel(writer, index=False, sheet_name="Réponses")
        buffer.seek(0)

        fname = f"reponses_{quest_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.xlsx"
        return dict(content=buffer.read(), filename=fname, type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", base64=True), no_update

    # ── Suppression réponse ───────────────────────────────────────────────────

    @callback(
        Output("modal-confirm-delete-rep", "is_open"),
        Output("store-rep-to-delete",      "data"),
        Input("btn-supprimer-reponse",     "n_clicks"),
        State("table-reponses",            "selected_rows"),
        State("table-reponses",            "data"),
        prevent_initial_call=True,
    )
    def open_delete_rep(n_clicks, sel, data):
        if not n_clicks or not sel or not data:
            return no_update, no_update
        rep_id = data[sel[0]].get("reponse_id")
        if not rep_id:
            return no_update, no_update
        return True, rep_id

    @callback(
        Output("modal-confirm-delete-rep", "is_open",  allow_duplicate=True),
        Output("rep-action-msg",           "children"),
        Input("btn-delete-rep-confirm",    "n_clicks"),
        Input("btn-delete-rep-cancel",     "n_clicks"),
        State("store-rep-to-delete",       "data"),
        prevent_initial_call=True,
    )
    def confirm_delete_rep(n_confirm, n_cancel, rep_id):
        triggered = ctx.triggered_id
        if triggered == "btn-delete-rep-cancel" or not n_confirm:
            return False, no_update

        if not security.rate_limit("delete_rep", max_calls=20, window_s=60):
            return False, html.Div("Trop de suppressions. Attendez.", className="alert-warn")

        if not rep_id:
            return False, html.Div("Aucune réponse sélectionnée.", className="alert-error")

        res = api_client.delete_reponse(int(rep_id))
        if "error" in res:
            return False, html.Div(f"Erreur : {res['error']}", className="alert-error")
        return False, html.Div("Réponse supprimée.", className="alert-success")

    # ── Carte GPS ─────────────────────────────────────────────────────────────

    @callback(
        Output("rep-gps-card", "style"),
        Output("rep-gps-map",  "figure"),
        Input("rep-quest-select", "value"),
        Input("rep-action-msg",   "children"),
    )
    def update_gps_map(quest_id, _msg):
        hidden = {"display": "none"}
        empty_fig = go.Figure()
        empty_fig.update_layout(margin={"l": 0, "r": 0, "t": 0, "b": 0})

        if not quest_id:
            return hidden, empty_fig

        rows = api_client.get_reponses_wide(int(quest_id))
        if not rows:
            return hidden, empty_fig

        df = pd.DataFrame(rows)

        # Cherche latitude/longitude : clés renommées, brutes (_latitude) ou via texte question
        lat_col = next((c for c in df.columns if c.lower() in ("latitude", "_latitude")
                        or "latitude" in c.lower()), None)
        lon_col = next((c for c in df.columns if c.lower() in ("longitude", "_longitude")
                        or "longitude" in c.lower()), None)
        if not lat_col or not lon_col:
            return hidden, empty_fig

        df[lat_col] = pd.to_numeric(df[lat_col], errors="coerce")
        df[lon_col] = pd.to_numeric(df[lon_col], errors="coerce")
        df = df.dropna(subset=[lat_col, lon_col])
        if df.empty:
            return hidden, empty_fig

        # Popup : horodateur + précision GPS si disponible
        prec_col = next((c for c in df.columns if "precision" in c.lower() or "précision" in c.lower()), None)
        texts = []
        for _, row in df.iterrows():
            t = f"Date : {row.get('horodateur', '')}"
            if prec_col and pd.notna(row.get(prec_col)):
                t += f"<br>Précision : ±{row[prec_col]} m"
            texts.append(t)

        fig = go.Figure(go.Scattermap(
            lat=df[lat_col].tolist(),
            lon=df[lon_col].tolist(),
            mode="markers",
            marker=go.scattermap.Marker(size=12, color="#f59e0b", opacity=0.9),
            text=texts,
            hovertemplate="%{text}<extra></extra>",
        ))
        fig.update_layout(
            map={"style": "open-street-map",
                 "center": {"lat": df[lat_col].mean(), "lon": df[lon_col].mean()},
                 "zoom": 10},
            margin={"l": 0, "r": 0, "t": 0, "b": 0},
        )
        return {"display": "block"}, fig

    # ── Détail réponse ────────────────────────────────────────────────────────

    @callback(
        Output("modal-reponse-detail",      "is_open"),
        Output("modal-reponse-detail-body", "children"),
        Input("btn-voir-reponse",           "n_clicks"),
        Input("btn-close-rep-detail",       "n_clicks"),
        State("table-reponses",             "selected_rows"),
        State("table-reponses",             "data"),
        prevent_initial_call=True,
    )
    def voir_detail(n_voir, n_close, sel, data):
        triggered = ctx.triggered_id
        if triggered == "btn-close-rep-detail":
            return False, []
        if not n_voir or not sel or not data:
            return no_update, no_update

        row = data[sel[0]]
        items = []
        for k, v in row.items():
            items.append(html.Tr([
                html.Td(security.sanitize_text(str(k), 150), style={"fontWeight": "600", "width": "40%", "padding": "6px"}),
                html.Td(security.sanitize_text(str(v or ""), 500), style={"padding": "6px"}),
            ]))

        body = html.Table(
            html.Tbody(items),
            style={"width": "100%", "borderCollapse": "collapse", "fontSize": "14px"},
        )
        return True, body
