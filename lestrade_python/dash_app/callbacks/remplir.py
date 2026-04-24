"""
Callbacks onglet Remplir — rendu dynamique du formulaire + soumission sécurisée.
Les champs utilisent des IDs pattern-matching {"type": "form-field", "index": q_id}
pour que la callback de soumission puisse collecter toutes les valeurs via ALL.
"""
import json
from dash import callback, Output, Input, State, no_update, html, dcc, ALL
import dash_bootstrap_components as dbc
from ..utils import security, api_client


def register(app):

    @callback(
        Output("fill-quest-info", "children"),
        Output("fill-form-body",  "children"),
        Input("fill-quest-select","value"),
    )
    def load_form(quest_id):
        if not quest_id:
            return html.P("Sélectionnez un questionnaire.", className="hint"), []

        data = api_client.get_questionnaire(int(quest_id))
        if "error" in data:
            return html.Div(f"Erreur : {data['error']}", className="alert-error"), []

        q    = data.get("questionnaire", {})
        secs = data.get("sections",  [])
        qs   = data.get("questions", [])

        info = html.Div([
            html.Small(f"{q.get('nb_sections',0)} section(s) · {q.get('nb_questions',0)} question(s)", className="hint"),
        ])

        if not secs:
            return info, [html.Div("Ce questionnaire n'a pas encore de questions.", className="alert-warn")]

        q_by_sec = {}
        for question in qs:
            sid = str(question["section_id"])
            q_by_sec.setdefault(sid, []).append(question)

        form_sections = []
        for sec in secs:
            sid    = str(sec["id"])
            sec_qs = q_by_sec.get(sid, [])
            fields = [_render_question(q) for q in sec_qs]

            form_sections.append(html.Div(className="section-card", children=[
                html.Strong(security.sanitize_text(sec["nom"], 80), style={"display": "block", "marginBottom": "10px"}),
                *fields,
            ]))

        return info, form_sections

    @callback(
        Output("fill-submit-msg", "children"),
        Input("btn-soumettre",    "n_clicks"),
        State("fill-quest-select","value"),
        State({"type": "form-field", "index": ALL}, "value"),
        State({"type": "form-field", "index": ALL}, "id"),
        prevent_initial_call=True,
    )
    def soumettre(n_clicks, quest_id, values, ids):
        if not n_clicks or not quest_id:
            return no_update

        if not security.rate_limit("submit_answer", max_calls=30, window_s=60):
            return html.Div("Trop de soumissions. Attendez une minute.", className="alert-warn")

        answers = {}
        for id_dict, val in zip(ids, values):
            qid = str(id_dict["index"])
            if val is None:
                val = ""
            if isinstance(val, list):
                answers[qid] = [security.sanitize_text(str(x), 2000) for x in val]
            else:
                answers[qid] = security.sanitize_text(str(val), 2000)

        donnees_json = json.dumps(answers, ensure_ascii=False)
        res = api_client.post_reponse(int(quest_id), donnees_json)
        if "error" in res:
            return html.Div(f"Erreur : {res['error']}", className="alert-error")

        return html.Div("Réponse soumise avec succès !", className="alert-success")


def _render_question(q: dict) -> html.Div:
    """Rend un champ de formulaire adapté au type de question."""
    q_id   = str(q.get("id", ""))
    texte  = security.sanitize_text(q.get("texte", ""), 200)
    q_type = q.get("type", "text")
    req    = bool(q.get("obligatoire"))
    label  = html.Label([
        texte,
        html.Span(" *", style={"color": "#c81e1e", "fontWeight": "700"}) if req else "",
    ], className="mb-1 fw-semibold")

    # Parse options
    opts_raw = q.get("options") or "[]"
    try:
        opts = json.loads(opts_raw)
        if isinstance(opts, str):
            opts = json.loads(opts)
        if not isinstance(opts, list):
            opts = []
    except Exception:
        opts = []

    opts_clean = [{"label": security.sanitize_text(str(o), 100), "value": security.sanitize_text(str(o), 100)} for o in opts]

    # Pattern-matching ID — permet à soumettre() de collecter toutes les valeurs via ALL
    field_id = {"type": "form-field", "index": q_id}

    if q_type == "text":
        field = dbc.Input(id=field_id, type="text", maxLength=500, className="mb-3")
    elif q_type == "textarea":
        field = dbc.Textarea(id=field_id, rows=3, maxLength=2000, className="mb-3")
    elif q_type == "email":
        field = dbc.Input(id=field_id, type="email", maxLength=254, className="mb-3")
    elif q_type == "phone":
        field = dbc.Input(id=field_id, type="tel", maxLength=20, className="mb-3")
    elif q_type == "date":
        field = dbc.Input(id=field_id, type="date", className="mb-3")
    elif q_type == "radio":
        field = dbc.RadioItems(id=field_id, options=opts_clean, className="mb-3")
    elif q_type == "checkbox":
        field = dbc.Checklist(id=field_id, options=opts_clean, className="mb-3")
    elif q_type in ("dropdown", "likert"):
        field = dcc.Dropdown(id=field_id, options=opts_clean, clearable=True, className="mb-3")
    else:
        field = dbc.Input(id=field_id, type="text", maxLength=500, className="mb-3")

    return html.Div(className="question-item mb-2", children=[label, field])
