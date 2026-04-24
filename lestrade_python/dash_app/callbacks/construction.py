"""
Callbacks onglet Construction — ajout de sections, questions, visualisation structure.
"""
import json
from dash import callback, Output, Input, State, no_update, html
from ..utils import security, api_client


def register(app):

    # ── Populate dropdowns depuis store ───────────────────────────────────────

    @callback(
        Output("builder-quest-select",  "options"),
        Output("fill-quest-select",     "options"),
        Output("rep-quest-select",      "options"),
        Output("ana-quest-select",      "options"),
        Input("interval-refresh",       "n_intervals"),
        Input("gestion-create-msg",     "children"),
    )
    def refresh_quest_dropdowns(_n, _msg):
        quests = api_client.get_questionnaires()
        opts = [
            {"label": f"[{q['id']}] {security.sanitize_text(q['nom'], 80)}", "value": q["id"]}
            for q in quests
        ]
        return opts, opts, opts, opts

    # ── Sections dropdown selon questionnaire sélectionné ─────────────────────

    @callback(
        Output("builder-section-target", "options"),
        Input("builder-quest-select",    "value"),
    )
    def load_sections_for_builder(quest_id):
        if not quest_id:
            return []
        data = api_client.get_questionnaire(int(quest_id))
        if "error" in data:
            return []
        return [
            {"label": security.sanitize_text(s["nom"], 80), "value": s["id"]}
            for s in data.get("sections", [])
        ]

    # ── Ajouter section ───────────────────────────────────────────────────────

    @callback(
        Output("builder-section-msg",  "children"),
        Output("builder-section-name", "value"),
        Output("builder-section-target", "options", allow_duplicate=True),
        Input("btn-add-section",       "n_clicks"),
        State("builder-quest-select",  "value"),
        State("builder-section-name",  "value"),
        prevent_initial_call=True,
    )
    def add_section(n_clicks, quest_id, nom):
        if not n_clicks:
            return no_update, no_update, no_update

        if not quest_id:
            return _err("Sélectionnez un questionnaire."), no_update, no_update

        if not security.rate_limit("add_section", max_calls=30, window_s=60):
            return _warn("Trop rapide. Attendez."), no_update, no_update

        ok, msg = security.validate_name(nom, "Nom de section")
        if not ok:
            return _err(msg), no_update, no_update

        res = api_client.create_section(int(quest_id), security.sanitize_text(nom, 200))
        if "error" in res:
            return _err(f"Erreur : {res['error']}"), no_update, no_update

        # Rafraîchit les options sections
        data = api_client.get_questionnaire(int(quest_id))
        opts = [
            {"label": security.sanitize_text(s["nom"], 80), "value": s["id"]}
            for s in data.get("sections", [])
        ]
        return _ok(f"Section « {security.sanitize_text(nom, 60)} » ajoutée."), "", opts

    # ── Ajouter question ──────────────────────────────────────────────────────

    @callback(
        Output("builder-question-msg", "children"),
        Output("builder-q-text",       "value"),
        Output("builder-q-options",    "value"),
        Output("builder-structure",    "children", allow_duplicate=True),
        Input("btn-add-question",      "n_clicks"),
        State("builder-quest-select",  "value"),
        State("builder-section-target","value"),
        State("builder-q-type",        "value"),
        State("builder-q-role",        "value"),
        State("builder-q-required",    "value"),
        State("builder-q-text",        "value"),
        State("builder-q-options",     "value"),
        prevent_initial_call=True,
    )
    def add_question(n_clicks, quest_id, section_id, q_type, role, required, texte, options_raw):
        if not n_clicks:
            return no_update, no_update, no_update, no_update

        if not quest_id:
            return _err("Sélectionnez un questionnaire."), no_update, no_update, no_update
        if not section_id:
            return _err("Sélectionnez une section cible."), no_update, no_update, no_update

        if not security.rate_limit("add_question", max_calls=50, window_s=60):
            return _warn("Trop rapide. Attendez."), no_update, no_update, no_update

        ok_t, msg_t = security.validate_name(texte, "Libellé de la question")
        if not ok_t:
            return _err(msg_t), no_update, no_update, no_update

        # Validation et parsing des options
        options_json = "{}"
        if options_raw and options_raw.strip():
            ok_o, msg_o, opts_list = security.validate_options_text(options_raw)
            if not ok_o:
                return _err(msg_o), no_update, no_update, no_update
            if opts_list:
                options_json = json.dumps(opts_list, ensure_ascii=False)

        payload = {
            "type":            q_type or "text",
            "texte":           security.sanitize_text(texte, 2000),
            "options":         options_json,
            "role_analytique": role or "other",
            "obligatoire":     1 if required else 0,
        }

        res = api_client.create_question(int(section_id), payload)
        if "error" in res:
            return _err(f"Erreur : {res['error']}"), no_update, no_update, no_update

        structure = _build_structure(int(quest_id))
        return _ok("Question ajoutée."), "", "", structure

    # ── Structure visuelle ────────────────────────────────────────────────────

    @callback(
        Output("builder-structure", "children"),
        Input("builder-quest-select", "value"),
        prevent_initial_call=True,
    )
    def show_structure(quest_id):
        if not quest_id:
            return []
        return _build_structure(int(quest_id))


def _build_structure(quest_id: int):
    """Construit l'affichage arborescent sections → questions."""
    data = api_client.get_questionnaire(quest_id)
    if "error" in data:
        return [html.Div(f"Erreur : {data['error']}", className="alert-error")]

    sections  = data.get("sections",  [])
    questions = data.get("questions", [])

    if not sections:
        return [html.P("Aucune section. Commencez par créer une section.", className="hint")]

    q_by_sec = {}
    for q in questions:
        sid = str(q["section_id"])
        q_by_sec.setdefault(sid, []).append(q)

    items = []
    for sec in sections:
        sid       = str(sec["id"])
        sec_qs    = q_by_sec.get(sid, [])
        q_items   = []
        for q in sec_qs:
            type_badge = q.get("type", "?").upper()
            req_mark   = " *" if q.get("obligatoire") else ""
            q_items.append(html.Div(className="question-item", children=[
                html.Div(className="question-item-text", children=[
                    html.Span(f"{req_mark}{security.sanitize_text(q['texte'], 100)}"),
                ]),
                html.Span(type_badge, className="question-type-badge"),
            ]))

        items.append(html.Div(className="section-card", children=[
            html.Div(style={"display": "flex", "justifyContent": "space-between", "alignItems": "center"}, children=[
                html.Strong(security.sanitize_text(sec["nom"], 80)),
                html.Span(f"{len(sec_qs)} question(s)", className="hint"),
            ]),
            html.Div(q_items) if q_items else html.P("Aucune question.", className="hint mt-1"),
        ]))

    return items


def _ok(msg):
    return html.Div(msg, className="alert-success mt-2")

def _err(msg):
    return html.Div(msg, className="alert-error mt-2")

def _warn(msg):
    return html.Div(msg, className="alert-warn mt-2")
