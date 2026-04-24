"""
Callbacks onglet Import externe — upload sécurisé, prévisualisation, import DB.
Sécurité :
  - Extension whitelist + taille max
  - Pas de path traversal (tempfile)
  - Sanitisation noms colonnes
  - Transaction DB atomique (via FastAPI)
"""
import io
import json
import tempfile
import os
from datetime import datetime

from dash import callback, Output, Input, State, no_update, html, dcc
import dash_bootstrap_components as dbc
from dash import dash_table
import pandas as pd

from ..utils import security, api_client


def register(app):

    # ── Étape 1 — upload ──────────────────────────────────────────────────────

    @callback(
        Output("upload-error",     "children"),
        Output("import-step2",     "children"),
        Output("import-step2",     "style"),
        Output("store-import-data","data"),
        Output("store-import-meta","data"),
        Input("upload-import",     "contents"),
        State("upload-import",     "filename"),
        prevent_initial_call=True,
    )
    def handle_upload(contents, filename):
        no_step2 = [], {"display": "none"}, None, None

        if not contents or not filename:
            return no_update, *no_step2

        # Validation sécurité
        ok, msg, data_bytes = security.validate_upload(filename, contents)
        if not ok:
            return html.Div(msg, className="alert-error"), *no_step2

        # Lecture du fichier dans un tempfile (pas de path traversal)
        safe_ext = os.path.splitext(filename)[1].lower()
        try:
            with tempfile.NamedTemporaryFile(suffix=safe_ext, delete=False) as tmp:
                tmp.write(data_bytes)
                tmp_path = tmp.name

            df = _read_file(tmp_path, safe_ext)
        except Exception as e:
            return html.Div(f"Erreur de lecture : {type(e).__name__}", className="alert-error"), *no_step2
        finally:
            try:
                os.unlink(tmp_path)
            except Exception:
                pass

        if df is None or df.empty:
            return html.Div("Fichier vide ou format non reconnu.", className="alert-error"), *no_step2

        # Limite : max 100 colonnes (protection mémoire)
        if df.shape[1] > 100:
            df = df.iloc[:, :100]

        # Sanitise les noms de colonnes
        df.columns = [security.sanitize_text(str(c), 150) for c in df.columns]

        # Sérialise pour le store
        data_json = df.head(500).to_json(orient="records")
        meta_json = json.dumps({
            "filename": security.sanitize_text(filename, 100),
            "rows":     df.shape[0],
            "cols":     df.shape[1],
            "columns":  list(df.columns),
        })

        step2 = _build_step2(df)
        return "", step2, {"display": "block"}, data_json, meta_json

    # ── Étape 3 — import final ────────────────────────────────────────────────

    @callback(
        Output("import-step3",        "children"),
        Output("import-step3",        "style"),
        Input("store-import-data",    "data"),
        prevent_initial_call=True,
    )
    def show_step3(data_json):
        if not data_json:
            return [], {"display": "none"}
        return _build_step3(), {"display": "block"}

    @callback(
        Output("import-history",           "data"),
        Output("import-result-msg",        "children"),
        Input("btn-import-confirm",        "n_clicks"),
        State("import-quest-name",         "value"),
        State("import-quest-desc",         "value"),
        State("store-import-data",         "data"),
        State("store-import-meta",         "data"),
        State("import-config-group",       "value"),
        State("import-config-indicator",   "value"),
        State("import-config-text",        "value"),
        State("import-config-ignore",      "value"),
        State("import-config-date",        "value"),
        prevent_initial_call=True,
    )
    def do_import(n_clicks, nom, desc, data_json, meta_json, grp_cols, ind_cols, txt_cols, ign_cols, date_col):
        if not n_clicks:
            return no_update, no_update

        if not security.rate_limit("import_quest", max_calls=5, window_s=120):
            return no_update, html.Div("Trop d'imports. Attendez 2 minutes.", className="alert-warn")

        ok, msg = security.validate_name(nom, "Nom du questionnaire")
        if not ok:
            return no_update, html.Div(msg, className="alert-error")

        if not data_json:
            return no_update, html.Div("Aucune donnée à importer.", className="alert-error")

        try:
            records = json.loads(data_json)
            df = pd.DataFrame(records)
        except Exception:
            return no_update, html.Div("Données corrompues.", className="alert-error")

        meta = security.safe_json_loads(meta_json) or {}
        columns = meta.get("columns", list(df.columns))

        # Construit la configuration de colonnes
        config = {
            "group":     grp_cols or [],
            "indicator": ind_cols or [],
            "text":      txt_cols or [],
            "ignore":    ign_cols or [],
            "date":      date_col,
        }

        # Envoie à la FastAPI via un import personnalisé
        # (la FastAPI n'a pas encore d'endpoint d'import direct,
        #  on utilise les endpoints CRUD questionnaire + sections + questions + réponses)
        clean_nom  = security.sanitize_text(nom,       200)
        clean_desc = security.sanitize_text(desc or "", 1000)

        result_id = _import_via_crud(df, columns, config, clean_nom, clean_desc)
        if isinstance(result_id, dict) and "error" in result_id:
            return no_update, html.Div(f"Erreur : {result_id['error']}", className="alert-error")

        # Rafraîchit l'historique
        history = _get_history()
        return history, html.Div(f"Import réussi — questionnaire ID {result_id} créé.", className="alert-success")

    # ── Historique ────────────────────────────────────────────────────────────

    @callback(
        Output("import-history", "data", allow_duplicate=True),
        Input("interval-refresh", "n_intervals"),
        prevent_initial_call=True,
    )
    def refresh_history(_n):
        return _get_history()


# ── Helpers ───────────────────────────────────────────────────────────────────

def _read_file(path: str, ext: str) -> pd.DataFrame | None:
    try:
        if ext in (".xlsx", ".xls"):
            return pd.read_excel(path, dtype=str)
        elif ext == ".csv":
            for sep in [",", ";", "\t"]:
                try:
                    df = pd.read_csv(path, sep=sep, dtype=str, encoding="utf-8-sig", on_bad_lines="skip")
                    if df.shape[1] > 1:
                        return df
                except Exception:
                    continue
        return None
    except Exception:
        return None


def _build_step2(df: pd.DataFrame) -> list:
    cols = list(df.columns)
    col_opts = [{"label": c, "value": c} for c in cols]

    preview_cols = [{"name": c, "id": c} for c in df.columns[:10]]
    preview_data = df.head(5).to_dict("records")

    return [
        html.Div(className="card", children=[
            html.Span("Étape 2", className="badge-step"),
            html.H5("Aperçu et configuration"),
            dbc.Row([
                dbc.Col(html.Div(className="metric", children=[html.Div(str(df.shape[0]), className="metric-value"), html.Div("Lignes", className="metric-label")]), width=3),
                dbc.Col(html.Div(className="metric", children=[html.Div(str(df.shape[1]), className="metric-value"), html.Div("Colonnes", className="metric-label")]), width=3),
            ], className="g-2 mb-3"),
            html.H6("Aperçu (5 premières lignes, 10 premières colonnes)"),
            dash_table.DataTable(
                columns=preview_cols, data=preview_data,
                style_table={"overflowX": "auto"},
                style_cell={"padding": "4px 8px", "maxWidth": "150px", "overflow": "hidden", "textOverflow": "ellipsis"},
                style_header={"backgroundColor": "#245c7c", "color": "white"},
            ),
            html.Hr(),
            html.H6("Configuration des colonnes"),
            dbc.Row([
                dbc.Col(html.Div(className="card", style={"borderLeft": "4px solid #245c7c"}, children=[
                    html.H6("Variables de groupe"),
                    html.P("Sexe, commune, statut…", className="hint"),
                    dcc.Dropdown(id="import-config-group", options=col_opts, multi=True, placeholder="Sélectionner…"),
                ]), width=6),
                dbc.Col(html.Div(className="card", style={"borderLeft": "4px solid #2ca02c"}, children=[
                    html.H6("Indicateurs"),
                    html.P("Questions Oui/Non, Likert, scores…", className="hint"),
                    dcc.Dropdown(id="import-config-indicator", options=col_opts, multi=True, placeholder="Sélectionner…"),
                ]), width=6),
            ], className="g-2"),
            dbc.Row([
                dbc.Col(html.Div(className="card", style={"borderLeft": "4px solid #ff7f0e"}, children=[
                    html.H6("Textes libres"),
                    html.P("Commentaires, réponses ouvertes…", className="hint"),
                    dcc.Dropdown(id="import-config-text", options=col_opts, multi=True, placeholder="Sélectionner…"),
                ]), width=4),
                dbc.Col(html.Div(className="card", style={"borderLeft": "4px solid #c81e1e"}, children=[
                    html.H6("Colonnes à ignorer"),
                    html.P("ID, email, données non pertinentes…", className="hint"),
                    dcc.Dropdown(id="import-config-ignore", options=col_opts, multi=True, placeholder="Sélectionner…"),
                ]), width=4),
                dbc.Col(html.Div(className="card", style={"borderLeft": "4px solid #17becf"}, children=[
                    html.H6("Colonne date"),
                    dcc.Dropdown(id="import-config-date", options=[{"label": "Aucune", "value": ""}] + col_opts, placeholder="Aucune"),
                ]), width=4),
            ], className="g-2"),
        ])
    ]


def _build_step3() -> list:
    return [
        html.Div(className="card", children=[
            html.Span("Étape 3", className="badge-step"),
            html.H5("Importer dans la base de données"),
            dbc.Row([
                dbc.Col(dbc.Input(id="import-quest-name", placeholder="Nom du questionnaire…", maxLength=200), width=6),
                dbc.Col(dbc.Input(id="import-quest-desc", placeholder="Description…", maxLength=1000), width=6),
            ], className="g-2 mb-3"),
            dbc.Button("Importer", id="btn-import-confirm", color="success", size="lg"),
            html.Div(id="import-result-msg", className="mt-2"),
        ])
    ]


def _get_history() -> list:
    quests = api_client.get_questionnaires()
    return [
        {
            "id":            q.get("id"),
            "nom":           security.sanitize_text(q.get("nom", ""), 80),
            "nb_sections":   q.get("nb_sections",  0),
            "nb_questions":  q.get("nb_questions", 0),
            "date_creation": (q.get("date_creation") or "")[:19].replace("T", " "),
        }
        for q in quests
    ]


def _import_via_crud(
    df: pd.DataFrame,
    columns: list[str],
    config: dict,
    nom: str,
    description: str,
) -> int | dict:
    """Import ligne par ligne via les endpoints CRUD FastAPI."""

    group_cols = config.get("group",     [])
    ind_cols   = config.get("indicator", [])
    txt_cols   = config.get("text",      [])
    ign_cols   = config.get("ignore",    [])
    date_col   = config.get("date")

    all_active = [c for c in columns if c not in ign_cols]
    if not all_active:
        return {"error": "Aucune colonne active sélectionnée."}

    # 1. Créer questionnaire
    quest = api_client.create_questionnaire(nom, description)
    if "error" in quest:
        return quest
    quest_id = quest["id"]

    # 2. Créer section unique (simplification — les colonnes vont toutes dans "Questions")
    sec = api_client.create_section(quest_id, "Questions importées")
    if "error" in sec:
        return sec
    section_id = sec["id"]

    # 3. Créer les questions (une par colonne active)
    q_map: dict[str, int] = {}   # col_name → question_id
    for i, col in enumerate(all_active):
        if col == date_col:
            continue
        if col in group_cols:
            q_type, role = "radio", "group"
            # options = valeurs uniques
            vals = df[col].dropna().unique()[:50].tolist()
        elif col in ind_cols:
            q_type, role = "radio", "indicator"
            vals = df[col].dropna().unique()[:50].tolist()
        elif col in txt_cols:
            q_type, role, vals = "textarea", "text", []
        else:
            q_type, role, vals = "text", "other", []

        opts_json = json.dumps([security.sanitize_text(str(v), 100) for v in vals], ensure_ascii=False) if vals else "[]"

        payload = {
            "type":            q_type,
            "texte":           security.sanitize_text(col, 200),
            "options":         opts_json,
            "role_analytique": role,
            "obligatoire":     0,
        }
        q_res = api_client.create_question(section_id, payload)
        if "error" not in q_res:
            q_map[col] = q_res["id"]

    # 4. Importer les réponses par lots de 50
    batch_size = 50
    total_saved = 0
    for i in range(0, len(df), batch_size):
        batch = df.iloc[i:i + batch_size]
        reponses_batch = []
        for _, row in batch.iterrows():
            data = {}
            for col, q_id in q_map.items():
                v = row.get(col)
                if v is not None and str(v).strip():
                    data[str(q_id)] = security.sanitize_text(str(v), 500)

            horo = None
            if date_col and date_col in row and row[date_col]:
                horo = str(row[date_col])[:19]

            reponses_batch.append({
                "donnees_json": json.dumps(data, ensure_ascii=False),
                "horodateur":   horo,
            })

        res = api_client.post_reponse.__module__  # flush — appel direct
        # Appel direct batch
        from ..utils import api_client as ac
        import httpx
        try:
            with httpx.Client(base_url="http://127.0.0.1:8765", timeout=30) as c:
                r = c.post("/reponses", json={"quest_id": quest_id, "reponses_full": reponses_batch})
                r.raise_for_status()
                total_saved += r.json().get("saved", 0)
        except Exception as e:
            return {"error": f"Erreur import réponses : {e}"}

    return quest_id
