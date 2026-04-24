"""
Layout principal — onglets Accueil, Gestion, Construction, Remplir,
Réponses (+ carte GPS), Analytics, Panier, Import, Admin.
"""
from dash import dcc, html, dash_table
import dash_bootstrap_components as dbc

QUESTION_TYPES = [
    {"label": "Texte court",      "value": "text"},
    {"label": "Texte long",       "value": "textarea"},
    {"label": "Choix unique",     "value": "radio"},
    {"label": "Choix multiples",  "value": "checkbox"},
    {"label": "Échelle Likert",   "value": "likert"},
    {"label": "Dropdown",         "value": "dropdown"},
    {"label": "Email",            "value": "email"},
    {"label": "Téléphone",        "value": "phone"},
    {"label": "Date",             "value": "date"},
]

ROLE_TYPES = [
    {"label": "Indicateur",         "value": "indicator"},
    {"label": "Variable de groupe", "value": "group"},
    {"label": "Texte libre",        "value": "text"},
    {"label": "Date",               "value": "date"},
    {"label": "Autre",              "value": "other"},
]


# ── Popup bienvenue ───────────────────────────────────────────────────────────

def welcome_modal() -> dbc.Modal:
    return dbc.Modal(
        id="modal-welcome",
        is_open=False,
        backdrop="static",
        keyboard=False,
        className="welcome-modal",
        children=[
            dbc.ModalHeader(dbc.ModalTitle("Bienvenue dans Lestrade Forms"), close_button=False),
            dbc.ModalBody([
                html.P(
                    "Lestrade Forms est votre outil de collecte terrain — "
                    "construction de formulaires, collecte mobile, analyse et export.",
                    className="mb-3",
                ),
                html.Hr(),
                html.P("📧  Votre adresse email nous permet de :", className="fw-semibold mb-1"),
                html.Ul([
                    html.Li("Vous envoyer automatiquement le lien de votre feuille Google Drive de collecte"),
                    html.Li("Vous informer des mises à jour importantes de l'application"),
                    html.Li("Vous assister en cas de problème technique"),
                ], className="mb-3 hint"),
                dbc.Input(
                    id="input-welcome-email",
                    type="email",
                    placeholder="prenom.nom@organisation.sn",
                    maxLength=254,
                    autocomplete="email",
                    className="mb-2",
                ),
                html.Div(id="welcome-email-error", className="alert-error mb-2", style={"display": "none"}),
                html.P(
                    "Votre email est stocké localement dans votre navigateur et n'est jamais partagé avec des tiers.",
                    className="hint mt-2",
                    style={"fontSize": "12px"},
                ),
            ]),
            dbc.ModalFooter([
                dbc.Button("Plus tard", id="btn-welcome-skip", color="secondary", outline=True, className="me-2"),
                dbc.Button("Confirmer", id="btn-welcome-confirm", color="primary"),
            ]),
        ],
    )


# ── Popup freemium ───────────────────────────────────────────────────────────

def freemium_modal() -> dbc.Modal:
    return dbc.Modal(
        id="modal-freemium",
        is_open=False,
        backdrop=True,
        keyboard=True,
        className="modal-freemium",
        children=[
            dbc.ModalHeader(dbc.ModalTitle("Lestrade Forms"), close_button=True),
            dbc.ModalBody([
                html.P(
                    "Choisissez comment utiliser Lestrade Forms. "
                    "Vous pouvez changer de formule à tout moment.",
                    className="text-center hint mb-4",
                ),
                dbc.Row([
                    dbc.Col([
                        html.Div(style={
                            "border": "1.5px solid #dde3ea", "borderRadius": "12px",
                            "padding": "20px", "textAlign": "center", "height": "100%",
                        }, children=[
                            html.Div("GRATUIT", style={"fontSize": "11px", "fontWeight": "700",
                                                        "letterSpacing": ".08em", "color": "#6b7785"}),
                            html.H3("Free", style={"fontWeight": "800", "color": "#245c7c", "margin": "10px 0"}),
                            html.Ul([
                                html.Li("Toutes les fonctionnalités"),
                                html.Li("Collecte terrain illimitée"),
                                html.Li("Analytics avancés"),
                                html.Li("Zone publicitaire affichée", style={"color": "#6b7785"}),
                            ], className="text-start mb-4", style={"fontSize": "13px", "paddingLeft": "20px"}),
                            dbc.Button("Continuer gratuitement", id="btn-freemium-free",
                                       color="secondary", outline=True, className="w-100"),
                        ]),
                    ], width=6),
                    dbc.Col([
                        html.Div(style={
                            "border": "2px solid #245c7c", "borderRadius": "12px",
                            "padding": "20px", "textAlign": "center", "height": "100%",
                            "background": "#f8fbff",
                        }, children=[
                            html.Div("PREMIUM", style={"fontSize": "11px", "fontWeight": "700",
                                                        "letterSpacing": ".08em", "color": "#245c7c"}),
                            html.H3("Pro", style={"fontWeight": "800", "color": "#245c7c", "margin": "10px 0"}),
                            html.Ul([
                                html.Li("Toutes les fonctionnalités"),
                                html.Li("Collecte terrain illimitée"),
                                html.Li("Analytics avancés"),
                                html.Li([html.Strong("Sans publicité"), " ✓"],
                                        style={"color": "#057a55"}),
                            ], className="text-start mb-3", style={"fontSize": "13px", "paddingLeft": "20px"}),
                            dbc.Input(id="input-licence-key", placeholder="Clé de licence…",
                                      maxLength=64, size="sm", className="mb-2"),
                            html.Div(id="freemium-key-error", style={"display": "none"},
                                     className="alert-error mb-2"),
                            dbc.Button("Activer la licence", id="btn-freemium-activate",
                                       color="primary", className="w-100"),
                        ]),
                    ], width=6),
                ], className="g-3"),
            ]),
        ],
    )


# ── Onglet Accueil ────────────────────────────────────────────────────────────

def tab_accueil() -> html.Div:
    def _card(btn_id, icon, title, desc, color):
        colors = {
            "blue":   ("#1a56db", "#eff6ff"),
            "teal":   ("#0694a2", "#ecfeff"),
            "green":  ("#057a55", "#f0fdf4"),
            "amber":  ("#c27803", "#fffbeb"),
            "purple": ("#7e3af2", "#f5f3ff"),
            "red":    ("#c81e1e", "#fff5f5"),
        }
        border, bg = colors.get(color, ("#245c7c", "#f0f8ff"))
        return html.Div(
            style={
                "border": f"1.5px solid {border}", "borderRadius": "12px",
                "background": bg, "padding": "20px 18px", "cursor": "pointer",
                "transition": "box-shadow .15s", "position": "relative",
            },
            children=[
                html.Div(icon, style={"fontSize": "28px", "marginBottom": "8px"}),
                html.H5(title, style={"color": border, "marginBottom": "6px", "fontWeight": "700"}),
                html.P(desc, className="hint", style={"fontSize": "13px", "marginBottom": "14px"}),
                dbc.Button("Ouvrir →", id=btn_id, color="link",
                           style={"padding": 0, "color": border, "fontWeight": "600",
                                  "position": "absolute", "bottom": "14px", "right": "16px"}),
            ],
        )

    return html.Div([
        # Hero
        html.Div(className="card", style={"background": "linear-gradient(135deg,#16324f 0%,#245c7c 100%)", "color": "white"}, children=[
            html.P("Plateforme universelle de gestion d'enquêtes",
                   style={"textTransform": "uppercase", "letterSpacing": ".08em", "fontSize": "11px",
                          "fontWeight": "600", "color": "rgba(255,255,255,.6)", "marginBottom": "6px"}),
            html.H2(["Collectez. Analysez. ", html.Em("Décidez.")],
                    style={"color": "white", "fontWeight": "800", "marginBottom": "10px"}),
            html.P("Construisez vos questionnaires, collectez des réponses terrain et produisez des analyses "
                   "statistiques avancées — conçu pour toute organisation qui travaille avec des données d'enquête.",
                   style={"color": "rgba(255,255,255,.8)", "maxWidth": "620px", "marginBottom": "20px"}),
            dbc.Row([
                dbc.Col(html.Div([html.Div("—", id="acc-metric-quest", style={"fontSize": "28px", "fontWeight": "800", "color": "white"}),
                                  html.Div("Questionnaires", style={"fontSize": "12px", "color": "rgba(255,255,255,.6)"})]), width=3),
                dbc.Col(html.Div([html.Div("—", id="acc-metric-rep",   style={"fontSize": "28px", "fontWeight": "800", "color": "white"}),
                                  html.Div("Réponses",       style={"fontSize": "12px", "color": "rgba(255,255,255,.6)"})]), width=3),
                dbc.Col(html.Div([html.Div("—", id="acc-metric-q",     style={"fontSize": "28px", "fontWeight": "800", "color": "white"}),
                                  html.Div("Questions",      style={"fontSize": "12px", "color": "rgba(255,255,255,.6)"})]), width=3),
                dbc.Col(html.Div([html.Div("—", id="acc-metric-sec",   style={"fontSize": "28px", "fontWeight": "800", "color": "white"}),
                                  html.Div("Sections",       style={"fontSize": "12px", "color": "rgba(255,255,255,.6)"})]), width=3),
            ], className="g-2"),
        ]),

        # Feature cards
        html.P("Accès rapide aux modules",
               style={"fontSize": "11px", "fontWeight": "600", "textTransform": "uppercase",
                      "letterSpacing": ".07em", "color": "#6b7785", "marginBottom": "14px", "marginTop": "8px"}),
        dbc.Row([
            dbc.Col(_card("btn-acc-gestion",      "🗂", "Gestion",
                           "Créez et gérez vos questionnaires. Vue d'ensemble de tous vos projets d'enquête.", "blue"), width=4, className="mb-3"),
            dbc.Col(_card("btn-acc-construction", "🔧", "Construction",
                           "Ajoutez sections et questions : Likert, choix multiple, texte libre, date et plus.", "teal"), width=4, className="mb-3"),
            dbc.Col(_card("btn-acc-remplir",      "📝", "Saisie",
                           "Formulaire de collecte interactif. Remplissez ou importez les réponses de terrain.", "green"), width=4, className="mb-3"),
            dbc.Col(_card("btn-acc-reponses",     "📋", "Réponses",
                           "Consultez, modifiez, filtrez et exportez les réponses collectées. Export Excel.", "amber"), width=4, className="mb-3"),
            dbc.Col(_card("btn-acc-analytics",    "📊", "Analytics",
                           "Tableaux croisés, tests statistiques, profils comparatifs, corrélations.", "purple"), width=4, className="mb-3"),
            dbc.Col(_card("btn-acc-import",       "📥", "Import & Analyse",
                           "Importez un fichier Google Forms ou KoboToolbox et analysez-le directement.", "red"), width=4, className="mb-3"),
        ], className="g-2"),

        # Guide démarrage
        html.Div(className="card", children=[
            html.Span("Comment démarrer", className="badge-step"),
            dbc.Row([
                dbc.Col(html.Div(className="d-flex gap-3 align-items-start", children=[
                    html.Div("1", style={"minWidth": "32px", "height": "32px", "borderRadius": "50%",
                                         "background": "#16324f", "color": "white", "display": "flex",
                                         "alignItems": "center", "justifyContent": "center", "fontWeight": "700"}),
                    html.Div([html.H6("Créer un questionnaire", className="mb-1"),
                              html.P("Onglet Gestion → Créer → donnez un nom et une description à votre enquête.", className="hint mb-0")]),
                ]), width=4),
                dbc.Col(html.Div(className="d-flex gap-3 align-items-start", children=[
                    html.Div("2", style={"minWidth": "32px", "height": "32px", "borderRadius": "50%",
                                         "background": "#16324f", "color": "white", "display": "flex",
                                         "alignItems": "center", "justifyContent": "center", "fontWeight": "700"}),
                    html.Div([html.H6("Construire la structure", className="mb-1"),
                              html.P("Onglet Construction → ajoutez des sections puis des questions de différents types.", className="hint mb-0")]),
                ]), width=4),
                dbc.Col(html.Div(className="d-flex gap-3 align-items-start", children=[
                    html.Div("3", style={"minWidth": "32px", "height": "32px", "borderRadius": "50%",
                                         "background": "#16324f", "color": "white", "display": "flex",
                                         "alignItems": "center", "justifyContent": "center", "fontWeight": "700"}),
                    html.Div([html.H6("Analyser les résultats", className="mb-1"),
                              html.P("Saisissez des réponses puis explorez l'onglet Analytics pour les graphes et tests.", className="hint mb-0")]),
                ]), width=4),
            ], className="g-3"),
            html.Hr(style={"borderColor": "#dde3ea", "margin": "16px 0"}),
            html.P(["💡 Vous avez un fichier Excel ou CSV existant ? Utilisez l'onglet ",
                    html.Strong("Import"), " pour le charger et l'analyser sans aucune configuration."],
                   className="hint text-center mb-0"),
        ]),
    ])


# ── Onglet Gestion ────────────────────────────────────────────────────────────

def tab_gestion() -> html.Div:
    return html.Div([
        # Créer
        html.Div(className="card", children=[
            html.H4("Créer un questionnaire"),
            dbc.Row([
                dbc.Col(dbc.Input(id="input-nom-quest", placeholder="Ex: Enquête satisfaction 2026", maxLength=200), width=4),
                dbc.Col(dbc.Input(id="input-desc-quest", placeholder="Objectif, cible, contexte…", maxLength=1000), width=6),
                dbc.Col(dbc.Button("Créer", id="btn-creer-quest", color="primary", className="w-100"), width=2),
            ], className="g-2 align-items-end"),
            html.Div(id="gestion-create-msg", className="mt-2"),
        ]),
        # Liste
        html.Div(className="card", children=[
            html.H4("Questionnaires disponibles"),
            html.P("Sélectionnez une ligne pour agir.", className="hint"),
            dash_table.DataTable(
                id="table-questionnaires",
                columns=[
                    {"name": "ID",          "id": "id"},
                    {"name": "Nom",         "id": "nom"},
                    {"name": "Description", "id": "description"},
                    {"name": "Sections",    "id": "nb_sections"},
                    {"name": "Questions",   "id": "nb_questions"},
                    {"name": "Créé le",     "id": "date_creation"},
                ],
                data=[],
                row_selectable="single",
                selected_rows=[],
                style_table={"overflowX": "auto"},
                style_cell={"textAlign": "left", "padding": "8px 12px", "fontFamily": "Segoe UI"},
                style_header={"backgroundColor": "#16324f", "color": "white", "fontWeight": "700"},
                style_data_conditional=[
                    {"if": {"state": "selected"}, "backgroundColor": "#eaf2f8", "border": "1px solid #245c7c"},
                ],
                page_size=15,
            ),
        ]),
        html.Div(className="card", children=[
            html.Div(className="form-actions", children=[
                dbc.Button("Construire", id="btn-goto-build",     color="info",      outline=True),
                dbc.Button("Remplir",    id="btn-goto-fill",      color="success",   outline=True),
                dbc.Button("Réponses",   id="btn-goto-reponses",  color="warning",   outline=True),
                dbc.Button("Analytics",  id="btn-goto-analytics", color="secondary", outline=True),
                dbc.Button("QR / Panier",id="btn-goto-panier",    color="info",      outline=True),
                dbc.Button("Supprimer",  id="btn-supprimer-quest",color="danger",    outline=True),
            ]),
        ]),
        dbc.Modal(id="modal-confirm-delete-quest", children=[
            dbc.ModalHeader(dbc.ModalTitle("Confirmer la suppression")),
            dbc.ModalBody("Cette action supprimera le questionnaire ET toutes ses réponses. Continuer ?"),
            dbc.ModalFooter([
                dbc.Button("Annuler",   id="btn-delete-quest-cancel",  color="secondary", className="me-2"),
                dbc.Button("Supprimer", id="btn-delete-quest-confirm", color="danger"),
            ]),
        ], is_open=False),
        html.Div(id="gestion-action-msg", className="mt-2"),
        dcc.Store(id="store-quest-to-delete"),
    ])


# ── Onglet Construction ───────────────────────────────────────────────────────

def tab_construction() -> html.Div:
    return html.Div([
        html.Div(className="card", children=[
            dbc.Row([
                dbc.Col(dcc.Dropdown(id="builder-quest-select", placeholder="Sélectionner un questionnaire…", clearable=False), width=5),
                dbc.Col(dbc.Input(id="builder-section-name", placeholder="Nouvelle section…", maxLength=200), width=4),
                dbc.Col(dbc.Button("Ajouter section", id="btn-add-section", color="primary", className="w-100"), width=3),
            ], className="g-2 align-items-end"),
            html.Div(id="builder-section-msg", className="mt-2"),
        ]),
        html.Div(className="card", children=[
            html.H4("Ajouter une question"),
            dbc.Row([
                dbc.Col(dcc.Dropdown(id="builder-section-target", placeholder="Section cible…", clearable=False), width=4),
                dbc.Col(dcc.Dropdown(id="builder-q-type", options=QUESTION_TYPES, value="text", clearable=False), width=3),
                dbc.Col(dcc.Dropdown(id="builder-q-role", options=ROLE_TYPES, value="other", clearable=False, placeholder="Rôle analytique"), width=3),
                dbc.Col(dbc.Checklist(id="builder-q-required", options=[{"label": "Obligatoire", "value": 1}], value=[]), width=2),
            ], className="g-2 align-items-center"),
            dbc.Textarea(id="builder-q-text", placeholder="Libellé de la question…", rows=2, maxLength=2000, className="mt-2"),
            dbc.Textarea(id="builder-q-options", placeholder="Options (une par ligne) — pour radio, checkbox, dropdown, Likert", rows=4, className="mt-2"),
            dbc.Button("Ajouter la question", id="btn-add-question", color="success", className="mt-2"),
            html.Div(id="builder-question-msg", className="mt-2"),
        ]),
        html.Div(id="builder-structure", className="mt-2"),
    ])


# ── Onglet Remplir ────────────────────────────────────────────────────────────

def tab_remplir() -> html.Div:
    return html.Div([
        html.Div(className="card", children=[
            dbc.Row([
                dbc.Col(dcc.Dropdown(id="fill-quest-select", placeholder="Sélectionner un questionnaire…", clearable=False), width=8),
                dbc.Col(html.Div(id="fill-quest-info"), width=4),
            ]),
        ]),
        html.Div(id="fill-form-body"),
        html.Div(className="card", children=[
            dbc.Button("Soumettre la réponse", id="btn-soumettre", color="success", size="lg"),
            html.Div(id="fill-submit-msg", className="mt-2"),
        ]),
        dcc.Store(id="store-fill-answers"),
    ])


# ── Onglet Réponses ───────────────────────────────────────────────────────────

def tab_reponses() -> html.Div:
    return html.Div([
        html.Div(className="card", children=[
            dbc.Row([
                dbc.Col(dcc.Dropdown(id="rep-quest-select", placeholder="Sélectionner un questionnaire…", clearable=False), width=5),
                dbc.Col(dcc.DatePickerRange(
                    id="rep-date-range",
                    display_format="DD/MM/YYYY",
                    start_date_placeholder_text="Début",
                    end_date_placeholder_text="Fin",
                ), width=4),
                dbc.Col(dbc.Button("Exporter Excel", id="btn-export-excel", color="primary", outline=True, className="w-100"), width=3),
            ], className="g-2 align-items-center"),
            dcc.Download(id="download-excel"),
        ]),
        html.Div(className="card", children=[
            html.H5("Tableau des réponses"),
            dash_table.DataTable(
                id="table-reponses",
                columns=[],
                data=[],
                row_selectable="single",
                selected_rows=[],
                style_table={"overflowX": "auto"},
                style_cell={"textAlign": "left", "padding": "8px 12px", "fontFamily": "Segoe UI",
                            "maxWidth": "300px", "overflow": "hidden", "textOverflow": "ellipsis"},
                style_header={"backgroundColor": "#16324f", "color": "white", "fontWeight": "700"},
                page_size=20,
            ),
        ]),
        # Carte GPS — visible seulement quand des coordonnées existent
        html.Div(id="rep-gps-card", className="card", style={"display": "none"}, children=[
            html.Span("Carte des points de collecte GPS", className="badge-step"),
            dcc.Graph(id="rep-gps-map", style={"height": "420px"},
                      config={"displayModeBar": True, "scrollZoom": True}),
        ]),
        html.Div(className="card", children=[
            html.Div(className="form-actions", children=[
                dbc.Button("Voir détail", id="btn-voir-reponse",     color="info",  outline=True),
                dbc.Button("Supprimer",  id="btn-supprimer-reponse", color="danger",outline=True),
            ]),
        ]),
        dbc.Modal(id="modal-confirm-delete-rep", children=[
            dbc.ModalHeader(dbc.ModalTitle("Confirmer la suppression")),
            dbc.ModalBody("Supprimer cette réponse définitivement ?"),
            dbc.ModalFooter([
                dbc.Button("Annuler",   id="btn-delete-rep-cancel",  color="secondary", className="me-2"),
                dbc.Button("Supprimer", id="btn-delete-rep-confirm", color="danger"),
            ]),
        ], is_open=False),
        dbc.Modal(id="modal-reponse-detail", size="xl", children=[
            dbc.ModalHeader(dbc.ModalTitle("Détail de la réponse")),
            dbc.ModalBody(id="modal-reponse-detail-body"),
            dbc.ModalFooter(dbc.Button("Fermer", id="btn-close-rep-detail", color="secondary")),
        ], is_open=False),
        html.Div(id="rep-action-msg", className="mt-2"),
        dcc.Store(id="store-rep-to-delete"),
    ])


# ── Onglet Analytics ──────────────────────────────────────────────────────────

def tab_analytics() -> html.Div:
    return html.Div([
        html.Div(className="card", children=[
            dbc.Row([
                dbc.Col(dcc.Dropdown(id="ana-quest-select", placeholder="Sélectionner un questionnaire…", clearable=False), width=5),
                dbc.Col(dcc.Dropdown(id="ana-group-var", placeholder="Variable de groupe (facultatif)", clearable=True), width=4),
                dbc.Col(dbc.RadioItems(
                    id="ana-alpha",
                    options=[{"label": "α 0.01", "value": 0.01}, {"label": "α 0.05", "value": 0.05}, {"label": "α 0.10", "value": 0.10}],
                    value=0.05, inline=True,
                ), width=3),
            ], className="g-2 align-items-center"),
        ]),
        dbc.Row([
            dbc.Col(html.Div(className="metric", children=[html.Div("—", id="ana-n",      className="metric-value"), html.Div("Réponses",    className="metric-label")]), width=3),
            dbc.Col(html.Div(className="metric", children=[html.Div("—", id="ana-score",  className="metric-value"), html.Div("Score moyen", className="metric-label")]), width=3),
            dbc.Col(html.Div(className="metric", children=[html.Div("—", id="ana-compl",  className="metric-value"), html.Div("Complétude",  className="metric-label")]), width=3),
            dbc.Col(html.Div(className="metric", children=[html.Div("—", id="ana-q-count",className="metric-value"), html.Div("Questions",   className="metric-label")]), width=3),
        ], className="mb-3 g-2"),
        dbc.Tabs(id="ana-subtabs", active_tab="desc", children=[
            dbc.Tab(label="Descriptif",   tab_id="desc",    children=_ana_tab_descriptif()),
            dbc.Tab(label="Tableaux",     tab_id="tables",  children=_ana_tab_tableaux()),
            dbc.Tab(label="Comparaisons", tab_id="compare", children=_ana_tab_comparaisons()),
            dbc.Tab(label="Profils",      tab_id="profils", children=_ana_tab_profils()),
            dbc.Tab(label="Avancé",       tab_id="avance",  children=_ana_tab_avance()),
        ]),
    ])


def _ana_tab_descriptif() -> html.Div:
    return html.Div([
        html.Div(className="card mt-3", children=[
            html.Span("Qualité des données", className="badge-step"),
            dash_table.DataTable(id="ana-quality-table", columns=[], data=[],
                style_table={"overflowX": "auto"},
                style_cell={"padding": "6px 10px", "fontFamily": "Segoe UI"},
                style_header={"backgroundColor": "#16324f", "color": "white"},
            ),
        ]),
        html.Div(className="card", children=[
            html.Span("Complétude par section", className="badge-step"),
            dash_table.DataTable(id="ana-completion-table", columns=[], data=[],
                style_table={"overflowX": "auto"},
                style_cell={"padding": "6px 10px"},
                style_header={"backgroundColor": "#245c7c", "color": "white"},
            ),
        ]),
        html.Div(className="card", children=[
            html.H5("Analyse univariée"),
            dbc.Row([
                dbc.Col(dcc.Dropdown(id="ana-plot-type", options=[
                    {"label": "Barres",      "value": "bar"},
                    {"label": "Secteur",     "value": "pie"},
                    {"label": "Histogramme", "value": "histogram"},
                ], value="bar", clearable=False), width=3),
                dbc.Col(dcc.Dropdown(id="ana-plot-var", placeholder="Variable…", clearable=False), width=9),
            ], className="g-2"),
            html.Div(id="ana-plot-msg", className="mt-2"),
            dcc.Graph(id="ana-single-plot", config={"displayModeBar": False}),
        ]),
        html.Div(className="card", children=[
            html.H5("Évolution temporelle des réponses"),
            dcc.Graph(id="ana-timeline-plot", config={"displayModeBar": False}),
        ]),
    ])


def _ana_tab_tableaux() -> html.Div:
    return html.Div([
        html.Div(className="card mt-3", children=[
            html.H5("Tableau croisé"),
            dbc.Row([
                dbc.Col(dcc.Dropdown(id="ana-cross-row", placeholder="Variable lignes…"), width=4),
                dbc.Col(dcc.Dropdown(id="ana-cross-col", placeholder="Variable colonnes…"), width=4),
                dbc.Col(dbc.RadioItems(id="ana-cross-mode", options=[
                    {"label": "Effectifs", "value": "count"},
                    {"label": "% ligne",   "value": "row_pct"},
                    {"label": "% col",     "value": "col_pct"},
                ], value="count", inline=True), width=4),
            ], className="g-2 align-items-center"),
            dash_table.DataTable(id="ana-crosstab", columns=[], data=[],
                style_table={"overflowX": "auto"},
                style_cell={"padding": "6px 10px"},
                style_header={"backgroundColor": "#245c7c", "color": "white"},
            ),
        ]),
    ])


def _ana_tab_comparaisons() -> html.Div:
    return html.Div([
        html.Div(className="card mt-3", children=[
            dbc.Row([
                dbc.Col(dcc.Dropdown(id="ana-cmp-row", placeholder="Variable 1…"), width=5),
                dbc.Col(dcc.Dropdown(id="ana-cmp-col", placeholder="Variable 2…"), width=5),
                dbc.Col(dcc.Dropdown(id="ana-cmp-plot-type", options=[
                    {"label": "Barres empilées", "value": "stacked"},
                    {"label": "Mosaïque",        "value": "mosaic"},
                ], value="stacked", clearable=False), width=2),
            ], className="g-2"),
        ]),
        dbc.Row([
            dbc.Col(html.Div(className="card", children=[
                html.H5("Graphique"),
                dcc.Graph(id="ana-bivariate-plot", config={"displayModeBar": False}),
            ]), width=7),
            dbc.Col(html.Div(className="card", children=[
                html.H5("Test statistique"),
                html.Pre(id="ana-test-result", style={"fontSize": "13px", "whiteSpace": "pre-wrap"}),
                html.Div(id="ana-test-interp", className="hint mt-2"),
            ]), width=5),
        ], className="g-2"),
    ])


def _ana_tab_profils() -> html.Div:
    return html.Div([
        html.Div(className="card mt-3", children=[
            dcc.Dropdown(id="ana-profile-group", placeholder="Variable de groupe…"),
        ]),
        html.Div(className="card", children=[
            html.H5("Synthèse par groupe"),
            dash_table.DataTable(id="ana-profile-summary", columns=[], data=[],
                style_table={"overflowX": "auto"},
                style_cell={"padding": "6px 10px"},
                style_header={"backgroundColor": "#245c7c", "color": "white"},
            ),
        ]),
        html.Div(className="card", children=[
            html.H5("Heatmap groupes × sections"),
            dcc.Graph(id="ana-profile-heatmap", style={"height": "500px"}, config={"displayModeBar": False}),
        ]),
        html.Div(className="card", children=[
            html.H5("Radar des groupes"),
            dcc.Graph(id="ana-profile-radar", style={"height": "550px"}, config={"displayModeBar": False}),
        ]),
    ])


def _ana_tab_avance() -> html.Div:
    return html.Div([
        dbc.Tabs(active_tab="corr", children=[

            # ── Corrélations ──────────────────────────────────────────────────
            dbc.Tab(label="Corrélations", tab_id="corr", children=[
                html.Div(className="card mt-3", children=[
                    html.P("Matrice de corrélation entre variables indicateurs (numériques ou Likert).", className="hint"),
                    dcc.Graph(id="ana-corr-heatmap", style={"height": "480px"}, config={"displayModeBar": False}),
                ]),
                html.Div(className="card", children=[
                    html.H5("Top corrélations"),
                    dash_table.DataTable(id="ana-corr-table", columns=[], data=[],
                        style_table={"overflowX": "auto"},
                        style_cell={"padding": "6px 10px"},
                        style_header={"backgroundColor": "#245c7c", "color": "white"},
                        page_size=15,
                    ),
                ]),
            ]),

            # ── Scores composites ─────────────────────────────────────────────
            dbc.Tab(label="Scores composites", tab_id="composite", children=[
                html.Div(className="card mt-3", children=[
                    html.P("Score moyen par groupe et par section (variables indicateurs uniquement).", className="hint"),
                    dbc.Row([
                        dbc.Col(dcc.Dropdown(id="ana-composite-group",
                                             placeholder="Variable de groupe…", clearable=False), width=5),
                        dbc.Col(dcc.Dropdown(id="ana-composite-sections",
                                             placeholder="Sections à inclure (toutes si vide)…",
                                             multi=True, clearable=True), width=7),
                    ], className="g-2"),
                ]),
                html.Div(className="card", children=[
                    html.H5("Tableau des scores"),
                    dash_table.DataTable(id="ana-composite-table", columns=[], data=[],
                        style_table={"overflowX": "auto"},
                        style_cell={"padding": "6px 10px"},
                        style_header={"backgroundColor": "#245c7c", "color": "white"},
                        page_size=20,
                    ),
                ]),
                html.Div(className="card", children=[
                    html.H5("Score composite par groupe"),
                    dcc.Graph(id="ana-composite-plot", style={"height": "380px"},
                              config={"displayModeBar": False}),
                ]),
            ]),

            # ── Régression logistique ─────────────────────────────────────────
            dbc.Tab(label="Régression logistique", tab_id="logit", children=[
                html.Div(className="card mt-3", children=[
                    html.P("Modèle logistique binaire — variable cible à exactement 2 modalités, min 20 obs.", className="hint"),
                    dbc.Row([
                        dbc.Col(dcc.Dropdown(id="ana-logit-outcome",
                                             placeholder="Variable cible (binaire)…", clearable=False), width=5),
                        dbc.Col(dcc.Dropdown(id="ana-logit-predictors",
                                             placeholder="Prédicteurs…", multi=True), width=7),
                    ], className="g-2"),
                    html.Pre(id="ana-logit-info",
                             style={"fontSize": "12px", "color": "#6b7785", "marginTop": "8px",
                                    "whiteSpace": "pre-wrap"}),
                ]),
                html.Div(className="card", children=[
                    html.H5("Odds Ratios (IC 95 %)"),
                    dash_table.DataTable(id="ana-logit-table", columns=[], data=[],
                        style_table={"overflowX": "auto"},
                        style_cell={"padding": "6px 10px"},
                        style_header={"backgroundColor": "#245c7c", "color": "white"},
                        style_data_conditional=[
                            {"if": {"filter_query": "{p-value} < 0.05"}, "color": "#057a55", "fontWeight": "700"},
                        ],
                        page_size=20,
                    ),
                ]),
            ]),

            # ── Exports ───────────────────────────────────────────────────────
            dbc.Tab(label="Exports", tab_id="exports", children=[
                html.Div(className="card mt-3", children=[
                    html.H5("Exports analytiques"),
                    html.P("Exporter la base analytique nettoyée pour exploitation externe.", className="hint"),
                    html.Div(className="form-actions", children=[
                        dbc.Button("Exporter dataset CSV", id="btn-export-dataset-csv", color="primary",   outline=True),
                        dbc.Button("Exporter scores CSV",  id="btn-export-scores-csv",  color="secondary", outline=True),
                    ]),
                    dcc.Download(id="download-dataset-csv"),
                    dcc.Download(id="download-scores-csv"),
                    html.Div(id="ana-export-msg", className="mt-2"),
                ]),
            ]),
        ]),
    ])


# ── Onglet Panier / Drive ─────────────────────────────────────────────────────

def tab_panier() -> html.Div:
    return html.Div([
        html.Div(className="card", children=[
            dbc.Row([
                dbc.Col([
                    html.H5("Compte coordinateur"),
                    html.Div(id="panier-email-status"),
                    html.Div(className="form-actions mt-2", children=[
                        dbc.Button("Modifier l'email", id="btn-panier-change-email", color="secondary", outline=True, size="sm"),
                    ]),
                ], width=6),
                dbc.Col([
                    html.H5("Statut API"),
                    html.Div(id="panier-api-status"),
                ], width=6),
            ]),
        ]),
        html.Div(className="card", children=[
            html.H5("Feuille de collecte (Panier)"),
            html.P(
                "Le panier est une feuille Google Sheet avec Apps Script qui reçoit "
                "les réponses mobiles même sans WiFi commun.",
                className="hint mb-3",
            ),
            dbc.Row([
                dbc.Col(dbc.Input(id="panier-url-input",
                                  placeholder="https://script.google.com/macros/s/…/exec",
                                  maxLength=500, type="url"), width=9),
                dbc.Col(dbc.Button("Enregistrer", id="btn-panier-save-url", color="primary", className="w-100"), width=3),
            ], className="g-2 align-items-end"),
            html.Div(id="panier-url-msg", className="mt-2"),
        ]),
        html.Div(className="card", children=[
            html.H5("QR Code terrain"),
            html.P("Générez un QR code à scanner depuis l'app mobile pour connecter le questionnaire.", className="hint"),
            dbc.Row([
                dbc.Col(dcc.Dropdown(id="panier-quest-select", placeholder="Sélectionner un questionnaire…"), width=8),
                dbc.Col(dbc.Button("Générer QR", id="btn-panier-gen-qr", color="success", className="w-100"), width=4),
            ], className="g-2 align-items-end"),
            html.Div(id="panier-qr-container", className="mt-3 text-center"),
            html.Div(id="panier-qr-msg", className="mt-2"),
        ]),
        html.Div(className="card", children=[
            html.H5("Synchronisation panier → base locale"),
            html.P("Importe les réponses reçues sur la feuille Google dans la base de données locale.", className="hint"),
            dbc.Row([
                dbc.Col(dcc.Dropdown(id="panier-sync-quest-select", placeholder="Questionnaire cible…"), width=7),
                dbc.Col(dbc.Button("Synchroniser", id="btn-panier-sync", color="info", className="w-100"), width=5),
            ], className="g-2 align-items-end"),
            html.Div(id="panier-sync-msg", className="mt-2"),
        ]),
        dbc.Modal(id="modal-change-email", children=[
            dbc.ModalHeader(dbc.ModalTitle("Modifier l'email coordinateur")),
            dbc.ModalBody([
                dbc.Input(id="panier-new-email", type="email", placeholder="nouveau@email.com", maxLength=254),
                html.Div(id="panier-email-error", className="alert-error mt-2", style={"display": "none"}),
            ]),
            dbc.ModalFooter([
                dbc.Button("Annuler",     id="btn-email-modal-cancel",  color="secondary", className="me-2"),
                dbc.Button("Enregistrer", id="btn-email-modal-confirm", color="primary"),
            ]),
        ], is_open=False),
    ])


# ── Onglet Import externe ─────────────────────────────────────────────────────

def tab_import() -> html.Div:
    return html.Div([
        html.Div(className="hero", children=[
            html.H3("Importer une enquête Google Forms / KoboToolbox"),
            html.P("Importez vos données et transformez-les en questionnaire analysable en 3 étapes."),
        ]),
        html.Div(className="card", children=[
            html.Span("Étape 1", className="badge-step"),
            html.H5("Sélectionnez votre fichier"),
            html.P("Formats supportés : Excel (.xlsx, .xls) ou CSV. Max 10 MB.", className="hint"),
            dcc.Upload(
                id="upload-import",
                children=html.Div(["Glissez un fichier ici ou ", html.A("parcourir")]),
                style={
                    "width": "100%", "height": "70px", "lineHeight": "70px",
                    "borderWidth": "2px", "borderStyle": "dashed",
                    "borderRadius": "10px", "textAlign": "center",
                    "borderColor": "#dde3ea", "cursor": "pointer",
                },
                multiple=False,
                accept=".xlsx,.xls,.csv",
            ),
            html.Div(id="upload-error", className="mt-2"),
        ]),
        html.Div(id="import-step2", children=[], style={"display": "none"}),
        html.Div(id="import-step3", children=[], style={"display": "none"}),
        html.Div(className="card", children=[
            html.H5("Questionnaires importés récemment"),
            dash_table.DataTable(
                id="import-history",
                columns=[
                    {"name": "ID",        "id": "id"},
                    {"name": "Nom",       "id": "nom"},
                    {"name": "Sections",  "id": "nb_sections"},
                    {"name": "Questions", "id": "nb_questions"},
                    {"name": "Créé le",   "id": "date_creation"},
                ],
                data=[],
                style_table={"overflowX": "auto"},
                style_cell={"padding": "6px 10px"},
                style_header={"backgroundColor": "#16324f", "color": "white"},
            ),
        ]),
        dcc.Store(id="store-import-data"),
        dcc.Store(id="store-import-meta"),
    ])


# ── Onglet Admin ──────────────────────────────────────────────────────────────

def tab_admin() -> html.Div:
    return html.Div([
        # Demandes en attente
        html.Div(className="card", children=[
            html.Span("Gestion des licences", className="badge-step"),
            html.H4("Demandes en attente de paiement"),
            html.P("Activez une licence dès réception du paiement Wave.",
                   className="hint mb-3"),
            dbc.Row([
                dbc.Col([
                    dbc.Button("🔄 Actualiser", id="btn-admin-refresh",
                               color="secondary", outline=True, size="sm"),
                    html.Span(id="admin-panier-status", className="hint ms-3"),
                ], width=6),
            ], className="mb-3"),
            html.Div(id="admin-pending-table"),
            html.Div(id="admin-activate-msg", className="mt-2"),
        ]),

        html.Hr(),

        # Génération manuelle de clé
        html.Div(className="card", children=[
            html.H4("Assigner une clé manuellement"),
            html.P("Pour les demandes hors formulaire (WhatsApp, email direct).", className="hint mb-3"),
            dbc.Row([
                dbc.Col(dbc.Input(id="admin-email-input", type="email",
                                  placeholder="client@email.com", maxLength=254), width=4),
                dbc.Col(dcc.Dropdown(id="admin-formule-input",
                                     options=[
                                         {"label": "Annuelle",   "value": "annuel"},
                                         {"label": "Permanente", "value": "permanent"},
                                     ],
                                     value="annuel", clearable=False), width=3),
                dbc.Col(dbc.Button("Générer & Envoyer", id="btn-admin-generate-key",
                                   color="primary", className="w-100"), width=3),
                dbc.Col(html.Div(id="admin-generated-key", className="hint mt-2 font-monospace"), width=2),
            ], className="g-2 align-items-end"),
            html.Div(id="admin-generate-msg", className="mt-2"),
        ]),

        # Store pour la clé en cours d'activation
        dcc.Store(id="store-admin-activate-cle"),
    ])


# ── Layout principal ──────────────────────────────────────────────────────────

def build_layout() -> html.Div:
    return html.Div(className="main-wrap", children=[
        # Stores globaux
        dcc.Store(id="store-selected-quest-id"),
        dcc.Store(id="store-user-email",    storage_type="local"),
        dcc.Store(id="store-panier-url",    storage_type="local"),
        dcc.Store(id="store-licence-key",   storage_type="local"),
        dcc.Store(id="store-freemium-seen", storage_type="session"),
        dcc.Interval(id="interval-refresh", interval=30_000, n_intervals=0),

        # Modals
        welcome_modal(),
        freemium_modal(),

        # Hero
        html.Div(className="hero", children=[
            html.H1("Lestrade Forms"),
            html.P("Construction de formulaires · Collecte terrain · Analytics avancés"),
        ]),

        # Tabs principaux
        dbc.Tabs(id="main-tabs", active_tab="accueil", children=[
            dbc.Tab(label="Accueil",        tab_id="accueil",      children=tab_accueil()),
            dbc.Tab(label="Gestion",        tab_id="gestion",      children=tab_gestion()),
            dbc.Tab(label="Construction",   tab_id="construction", children=tab_construction()),
            dbc.Tab(label="Remplir",        tab_id="remplir",      children=tab_remplir()),
            dbc.Tab(label="Réponses",       tab_id="reponses",     children=tab_reponses()),
            dbc.Tab(label="Analytics",      tab_id="analytics",    children=tab_analytics()),
            dbc.Tab(label="Panier / Drive", tab_id="panier",       id="tab-panier",
                    children=tab_panier(),
                    label_style={"color": "#6b7785"},
                    active_label_style={"color": "#e6a700"},
                    ),
            dbc.Tab(label="Import externe", tab_id="import",       children=tab_import()),
            dbc.Tab(label="Admin",          tab_id="admin",        id="tab-admin",
                    children=tab_admin(),
                    label_style={"display": "none"},
                    disabled=True,
                    ),
        ]),

        html.Div(className="ad-zone", id="ad-zone",
                 children="[ Zone publicitaire ]"),
    ])
