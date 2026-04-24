"""
Callbacks onglet Gestion — CRUD questionnaires, métriques globales, navigation.
"""
from dash import callback, Output, Input, State, no_update, ctx
from ..utils import security, api_client


def register(app):

    # ── Métriques globales (header + onglet Accueil) ─────────────────────────

    @callback(
        Output("metric-questionnaires", "children"),
        Output("metric-sections",       "children"),
        Output("metric-questions",      "children"),
        Output("metric-reponses",       "children"),
        Output("acc-metric-quest",      "children"),
        Output("acc-metric-sec",        "children"),
        Output("acc-metric-q",          "children"),
        Output("acc-metric-rep",        "children"),
        Output("table-questionnaires",  "data"),
        Input("interval-refresh",       "n_intervals"),
        Input("gestion-create-msg",     "children"),
        Input("gestion-action-msg",     "children"),
    )
    def refresh_metrics(_n, _create, _action):
        quests = api_client.get_questionnaires()
        nb_q   = len(quests)
        nb_s   = sum(q.get("nb_sections",  0) for q in quests)
        nb_qu  = sum(q.get("nb_questions", 0) for q in quests)

        nb_rep = 0
        for q in quests:
            reps = api_client.get_reponses(q["id"])
            nb_rep += len(reps) if isinstance(reps, list) else 0

        rows = []
        for q in quests:
            rows.append({
                "id":            q.get("id", ""),
                "nom":           security.sanitize_text(q.get("nom", ""), 100),
                "description":   security.sanitize_text(q.get("description", "") or "", 120),
                "nb_sections":   q.get("nb_sections",  0),
                "nb_questions":  q.get("nb_questions", 0),
                "date_creation": (q.get("date_creation") or "")[:19].replace("T", " "),
            })

        s = str(nb_q), str(nb_s), str(nb_qu), str(nb_rep)
        return *s, *s, rows

    # ── Créer questionnaire ───────────────────────────────────────────────────

    @callback(
        Output("gestion-create-msg",   "children"),
        Output("input-nom-quest",      "value"),
        Output("input-desc-quest",     "value"),
        Input("btn-creer-quest",       "n_clicks"),
        State("input-nom-quest",       "value"),
        State("input-desc-quest",      "value"),
        prevent_initial_call=True,
    )
    def creer_questionnaire(n_clicks, nom, desc):
        if not n_clicks:
            return no_update, no_update, no_update

        # Rate limiting — 20 créations / minute
        if not security.rate_limit("create_quest", max_calls=20, window_s=60):
            return _warn("Trop de créations. Attendez une minute."), no_update, no_update

        ok, msg = security.validate_name(nom, "Nom du questionnaire")
        if not ok:
            return _err(msg), no_update, no_update

        if desc:
            ok2, msg2 = security.validate_name(desc, "Description")
            if not ok2:
                return _err(msg2), no_update, no_update

        clean_nom  = security.sanitize_text(nom,  200)
        clean_desc = security.sanitize_text(desc or "", 1000)

        res = api_client.create_questionnaire(clean_nom, clean_desc)
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
        Output("main-tabs", "active_tab"),
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
    from dash import html
    return html.Div(msg, className="alert-success mt-2")

def _err(msg):
    from dash import html
    return html.Div(msg, className="alert-error mt-2")

def _warn(msg):
    from dash import html
    return html.Div(msg, className="alert-warn mt-2")
