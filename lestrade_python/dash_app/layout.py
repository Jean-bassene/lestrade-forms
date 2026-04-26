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
    {"label": "GPS (auto)",       "value": "gps"},
]

ROLE_TYPES = [
    {"label": "Indicateur",         "value": "indicator"},
    {"label": "Variable de groupe", "value": "group"},
    {"label": "Texte libre",        "value": "text"},
    {"label": "Date",               "value": "date"},
    {"label": "Autre",              "value": "other"},
]


# ── Modale changement d'email ─────────────────────────────────────────────────

def change_email_modal() -> dbc.Modal:
    return dbc.Modal(
        id="modal-account",
        is_open=False,
        centered=True,
        children=[
            dbc.ModalHeader(dbc.ModalTitle("Mon compte")),
            dbc.ModalBody([
                html.P("Modifiez votre email ou déconnectez-vous.", className="hint mb-3"),
                dbc.Input(id="input-change-email", type="email",
                          placeholder="votre@email.com", maxLength=254, className="mb-2"),
                html.Div(id="change-email-error", style={"display": "none"},
                         className="alert-error mb-2"),
            ]),
            dbc.ModalFooter([
                dbc.Button("Se déconnecter", id="btn-change-email-logout",
                           color="danger", outline=True, className="me-auto"),
                dbc.Button("Annuler", id="btn-change-email-cancel",
                           color="secondary", outline=True, className="me-2"),
                dbc.Button("Enregistrer", id="btn-change-email-save",
                           color="primary"),
            ]),
        ],
    )


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
                    {"name": "Réponses",    "id": "nb_reponses"},
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
                dbc.Button("QR / Panier",  id="btn-goto-panier",      color="info",    outline=True),
                dbc.Button("Publier QR", id="btn-publish-quest",    color="primary", outline=True),
                dbc.Button("Supprimer",  id="btn-supprimer-quest",  color="danger",  outline=True),
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
        # QR inline — affiché dès qu'une ligne est sélectionnée
        html.Div(id="gestion-qr-panel", className="mt-2"),
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
                dbc.Col(dcc.Dropdown(id="rep-quest-select", placeholder="Sélectionner un questionnaire…", clearable=False), width=4),
                dbc.Col(dcc.DatePickerRange(
                    id="rep-date-range",
                    display_format="DD/MM/YYYY",
                    start_date_placeholder_text="Début",
                    end_date_placeholder_text="Fin",
                ), width=4),
                dbc.Col(dbc.Button("Actualiser", id="btn-refresh-reponses", color="secondary", outline=True, className="w-100"), width=2),
                dbc.Col(dbc.Button("Exporter Excel", id="btn-export-excel", color="primary", outline=True, className="w-100"), width=2),
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
                dbc.Col(dcc.Dropdown(id="ana-group-var", placeholder="Filtrer par variable…", clearable=True), width=3),
                dbc.Col(dcc.Dropdown(id="ana-group-filter-val", placeholder="Valeur…", clearable=True), width=2),
                dbc.Col(dbc.RadioItems(
                    id="ana-alpha",
                    options=[{"label": "α 0.01", "value": 0.01}, {"label": "α 0.05", "value": 0.05}, {"label": "α 0.10", "value": 0.10}],
                    value=0.05, inline=True,
                ), width=2),
            ], className="g-2 align-items-center"),
        ]),
        dbc.Row([
            dbc.Col(html.Div(className="metric", children=[html.Div("—", id="ana-n",      className="metric-value"), html.Div("Réponses",    className="metric-label")]), width=3),
            dbc.Col(html.Div(className="metric", children=[html.Div("—", id="ana-periode", className="metric-value"), html.Div("Période",     className="metric-label")]), width=3),
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
                page_size=15,
                style_table={"overflowX": "auto"},
                style_cell={"padding": "6px 10px", "fontFamily": "Segoe UI"},
                style_header={"backgroundColor": "#16324f", "color": "white"},
            ),
        ]),
        html.Div(className="card", children=[
            html.Span("Complétude par section", className="badge-step"),
            dash_table.DataTable(id="ana-completion-table", columns=[], data=[],
                page_size=10,
                style_table={"overflowX": "auto"},
                style_cell={"padding": "6px 10px"},
                style_header={"backgroundColor": "#245c7c", "color": "white"},
            ),
        ]),
        html.Div(className="card", children=[
            html.H5("Analyse univariée"),
            dbc.Row([
                dbc.Col(dcc.Dropdown(id="ana-plot-type", options=[
                    {"label": "Barres",          "value": "bar"},
                    {"label": "Secteur",         "value": "pie"},
                    {"label": "Histogramme",     "value": "histogram"},
                    {"label": "Boîte (boxplot)", "value": "boxplot"},
                ], value="bar", clearable=False), width=3),
                dbc.Col(dcc.Dropdown(id="ana-plot-var", placeholder="Variable…", clearable=False), width=9),
            ], className="g-2"),
            html.Div(id="ana-plot-msg", className="mt-2"),
            dcc.Graph(id="ana-single-plot", config={"displayModeBar": False}),
            html.Div(id="ana-stats-card", className="mt-2"),
            dash_table.DataTable(
                id="ana-stats-table", columns=[], data=[],
                style_table={"overflowX": "auto", "maxWidth": "720px"},
                style_cell={"padding": "6px 10px", "fontFamily": "Segoe UI"},
                style_header={"backgroundColor": "#245c7c", "color": "white"},
            ),
        ]),
        html.Div(className="card", children=[
            dbc.Row([
                dbc.Col(html.H5("Évolution temporelle"), width=8),
                dbc.Col(dbc.Input(id="ana-objectif-input", type="number",
                                  placeholder="Objectif collecte…", min=1, step=1,
                                  debounce=True, style={"fontSize": "13px"}), width=4),
            ], className="g-2 align-items-center mb-2"),
            dcc.Graph(id="ana-timeline-plot", config={"displayModeBar": False}),
        ]),
        html.Div(className="card", children=[
            dbc.Row([
                dbc.Col(html.H5("Carte GPS des réponses"), width=6),
                dbc.Col(dcc.Dropdown(id="ana-map-color-var",
                                     placeholder="Colorier par variable…",
                                     clearable=True), width=6),
            ], className="g-2 align-items-center mb-2"),
            html.Div(id="ana-map-card"),
            dcc.Graph(id="ana-analytics-map", style={"height": "450px"},
                      config={"displayModeBar": True, "scrollZoom": True}),
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

            # ── Qualité terrain ───────────────────────────────────────────────
            dbc.Tab(label="Qualité terrain", tab_id="qual_terrain", children=[
                html.Div(className="card mt-3", children=[
                    html.P("Détecte les réponses suspectes : straight-lining Likert, soumissions trop rapides, points GPS aberrants.", className="hint"),
                    dbc.Row([
                        dbc.Col(dcc.Dropdown(id="ana-qual-enqueteur-var",
                                             placeholder="Variable enquêteur / collecteur…",
                                             clearable=True), width=5),
                        dbc.Col(dbc.Input(id="ana-qual-min-duration", type="number",
                                          placeholder="Durée min. entre soumissions (min)…",
                                          min=1, step=1, debounce=True,
                                          style={"fontSize": "13px"}), width=4),
                        dbc.Col(dbc.Button("Analyser", id="btn-qual-analyse",
                                           color="warning", outline=True), width=3),
                    ], className="g-2 align-items-center"),
                ]),
                dbc.Row([
                    dbc.Col(html.Div(className="metric", children=[
                        html.Div("—", id="qual-n-suspects", className="metric-value"),
                        html.Div("Suspects", className="metric-label"),
                    ]), width=3),
                    dbc.Col(html.Div(className="metric", children=[
                        html.Div("—", id="qual-n-sl", className="metric-value"),
                        html.Div("Straight-lining", className="metric-label"),
                    ]), width=3),
                    dbc.Col(html.Div(className="metric", children=[
                        html.Div("—", id="qual-n-fast", className="metric-value"),
                        html.Div("Trop rapides", className="metric-label"),
                    ]), width=3),
                    dbc.Col(html.Div(className="metric", children=[
                        html.Div("—", id="qual-n-geo", className="metric-value"),
                        html.Div("GPS aberrants", className="metric-label"),
                    ]), width=3),
                ], className="g-2 mb-3"),
                html.Div(className="card", children=[
                    html.H5("Réponses signalées"),
                    dash_table.DataTable(
                        id="ana-qual-table", columns=[], data=[],
                        style_table={"overflowX": "auto"},
                        style_cell={"padding": "6px 10px", "fontFamily": "Segoe UI"},
                        style_header={"backgroundColor": "#d97706", "color": "white"},
                        style_data_conditional=[
                            {"if": {"filter_query": "{Signaux} > 2"},
                             "backgroundColor": "#fee2e2", "fontWeight": "700"},
                            {"if": {"filter_query": "{Signaux} = 2"},
                             "backgroundColor": "#fef3c7"},
                        ],
                        page_size=25,
                    ),
                ]),
                html.Div(className="card", children=[
                    html.H5("Signaux par enquêteur"),
                    dcc.Graph(id="ana-qual-plot", style={"height": "350px"},
                              config={"displayModeBar": False}),
                ]),
            ]),

            # ── IA & Textes ───────────────────────────────────────────────────
            dbc.Tab(label="✨ IA & Textes", tab_id="ia_textes", children=[
                html.Div(className="card mt-3", children=[
                    dbc.Row([
                        dbc.Col([
                            html.H5("Analyse intelligente des données"),
                            html.P("Résumé automatique, recommandations d'analyse, et analyse des réponses texte libres.", className="hint"),
                        ], width=8),
                        dbc.Col(
                            dbc.Button("✨ Analyser avec Claude", id="btn-ia-analyse",
                                       color="primary", size="lg",
                                       style={"background": "linear-gradient(135deg,#003366,#5b21b6)",
                                              "border": "none"}),
                            width=4,
                            className="d-flex align-items-center justify-content-end",
                        ),
                    ]),
                    html.Div(id="ia-api-key-warn", className="mt-2"),
                ]),
                dcc.Loading(type="circle", color="#003366", children=[
                    html.Div(id="ia-summary-card"),
                ]),
                html.Div(className="card mt-3", children=[
                    html.H5("Analyse d'une question texte libre"),
                    dbc.Row([
                        dbc.Col(dcc.Dropdown(id="ia-text-var",
                                             placeholder="Sélectionner une question texte…",
                                             clearable=True), width=8),
                        dbc.Col(dbc.Button("Analyser", id="btn-ia-text-analyse",
                                           color="secondary", outline=True, size="sm"), width=4),
                    ], className="g-2 align-items-center"),
                    dcc.Loading(type="dot", color="#5b21b6", children=[
                        html.Div(id="ia-text-result", className="mt-3"),
                    ]),
                ]),
            ]),

            # ── Exports ───────────────────────────────────────────────────────
            dbc.Tab(label="Exports", tab_id="exports", children=[
                html.Div(className="card mt-3", children=[
                    html.H5("Exports analytiques"),
                    html.P("Exporter la base analytique nettoyée pour exploitation externe.", className="hint"),
                    html.Div(className="form-actions", children=[
                        dbc.Button("Exporter dataset CSV",   id="btn-export-dataset-csv",    color="primary",   outline=True),
                        dbc.Button("Exporter scores CSV",    id="btn-export-scores-csv",     color="secondary", outline=True),
                        dbc.Button("Exporter dataset Excel", id="btn-export-analytics-xlsx", color="success",   outline=True),
                    ]),
                    dcc.Download(id="download-dataset-csv"),
                    dcc.Download(id="download-scores-csv"),
                    dcc.Download(id="download-analytics-xlsx"),
                    html.Div(id="ana-export-msg", className="mt-2"),
                ]),
            ]),
        ]),
    ])


# ── Onglet Panier / Drive ─────────────────────────────────────────────────────

def tab_panier() -> html.Div:
    return html.Div([
        # ── Compte + statut ───────────────────────────────────────────────────
        html.Div(className="card", children=[
            dbc.Row([
                dbc.Col([
                    html.H5("Compte coordinateur"),
                    html.Div(id="panier-email-status"),
                    html.Div(className="form-actions mt-2", children=[
                        dbc.Button("Modifier l'email", id="btn-panier-change-email",
                                   color="secondary", outline=True, size="sm"),
                    ]),
                ], width=6),
                dbc.Col([
                    html.H5("Panier centralisé"),
                    html.Div(id="panier-central-status"),
                ], width=3),
                dbc.Col([
                    html.H5("API locale"),
                    html.Div(id="panier-api-status"),
                ], width=3),
            ]),
        ]),

        # ── QR Code terrain ───────────────────────────────────────────────────
        html.Div(className="card", children=[
            html.H5("QR Code terrain"),
            html.P(
                "Générez un QR code à scanner depuis l'app mobile. "
                "Les réponses seront envoyées automatiquement vers le panier partagé.",
                className="hint",
            ),
            dbc.Row([
                dbc.Col(dcc.Dropdown(id="panier-quest-select",
                                     placeholder="Sélectionner un questionnaire…"), width=8),
                dbc.Col(dbc.Button("Générer QR", id="btn-panier-gen-qr",
                                   color="success", className="w-100"), width=4),
            ], className="g-2 align-items-end"),
            html.Div(id="panier-qr-container", className="mt-3 text-center"),
            html.Div(id="panier-qr-msg", className="mt-2"),
        ]),

        # ── Synchronisation panier → base locale ──────────────────────────────
        html.Div(className="card", children=[
            html.H5("Synchroniser vers la base locale"),
            html.P(
                "Importe vos réponses du panier partagé dans la base de données locale "
                "pour analyse et export.",
                className="hint",
            ),
            dbc.Row([
                dbc.Col(dcc.Dropdown(id="panier-sync-quest-select",
                                     placeholder="Questionnaire cible…"), width=7),
                dbc.Col(dbc.Button("Synchroniser", id="btn-panier-sync",
                                   color="info", className="w-100"), width=5),
            ], className="g-2 align-items-end"),
            dbc.Checkbox(id="panier-auto-clear", value=True, className="mt-2",
                         label="Vider le panier après sync (recommandé — le mobile peut renvoyer)"),
            html.Div(id="panier-sync-msg", className="mt-2"),
        ]),

        # ── Télécharger depuis le panier ──────────────────────────────────────
        html.Div(className="card", children=[
            html.H5("Télécharger mes réponses"),
            html.P(
                "Téléchargez directement vos réponses depuis le panier partagé "
                "sans synchronisation préalable.",
                className="hint",
            ),
            dbc.Row([
                dbc.Col(dcc.Dropdown(id="panier-dl-quest-select",
                                     placeholder="Questionnaire (facultatif — tout si vide)",
                                     clearable=True), width=5),
                dbc.Col(dbc.RadioItems(
                    id="panier-dl-format",
                    options=[
                        {"label": "Excel (.xlsx)", "value": "xlsx"},
                        {"label": "CSV",           "value": "csv"},
                    ],
                    value="xlsx",
                    inline=True,
                ), width=4),
                dbc.Col(dbc.Button("Télécharger", id="btn-panier-download",
                                   color="primary", className="w-100"), width=3),
            ], className="g-2 align-items-center"),
            html.Div(id="panier-dl-msg", className="mt-2"),
            dcc.Download(id="download-panier"),
        ]),

        # ── Modal changement email ────────────────────────────────────────────
        dbc.Modal(id="modal-change-email", children=[
            dbc.ModalHeader(dbc.ModalTitle("Modifier l'email coordinateur")),
            dbc.ModalBody([
                dbc.Input(id="panier-new-email", type="email",
                          placeholder="nouveau@email.com", maxLength=254),
                html.Div(id="panier-email-error", className="alert-error mt-2",
                         style={"display": "none"}),
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

        # ── Écran de connexion (visible si non authentifié) ───────────────────
        html.Div(id="admin-lock-area", children=[
            html.Div(className="card", style={"maxWidth": "420px", "margin": "48px auto"}, children=[
                html.Div(className="badge-step mb-3", children="Accès administrateur"),
                html.P("Entrez le mot de passe admin pour continuer.", className="hint mb-3"),
                dbc.Input(id="admin-pass-input", type="password",
                          placeholder="Mot de passe…", maxLength=100, className="mb-2"),
                html.Div(id="admin-pass-error", style={"display": "none"},
                         className="alert-error mb-2"),
                dbc.Button("Connexion", id="btn-admin-login",
                           color="primary", className="w-100"),
            ]),
        ]),

        # ── Contenu admin (visible après authentification) ────────────────────
        html.Div(id="admin-content-area", style={"display": "none"}, children=[

            # ── Demandes de licence ───────────────────────────────────────────
            html.Div(className="card", children=[
                html.Div(className="d-flex align-items-center gap-3 mb-3", children=[
                    html.Span("Gestion des licences", className="badge-step"),
                    html.Span(id="admin-req-count", className="hint", style={"fontSize": "13px"}),
                    dbc.Button("🔄 Actualiser", id="btn-admin-refresh",
                               color="secondary", outline=True, size="sm", className="ms-auto"),
                ]),
                html.P(
                    "Validez une demande après réception du paiement. "
                    "La clé est générée automatiquement et envoyée par email au client.",
                    className="hint mb-3",
                ),
                html.Div(id="admin-pending-table", style={"overflowX": "auto"}),
                html.Div(id="admin-activate-msg"),
            ]),

            html.Hr(),

            # ── Génération manuelle ───────────────────────────────────────────
            html.Div(className="card", children=[
                html.H5("Générer une clé manuellement"),
                html.P("Pour les demandes hors formulaire (WhatsApp, email direct, ONG partenaire).",
                       className="hint mb-3"),
                dbc.Row([
                    dbc.Col(dbc.Input(id="admin-email-input", type="email",
                                      placeholder="client@email.com", maxLength=254), width=4),
                    dbc.Col(dcc.Dropdown(id="admin-formule-input",
                                         options=[
                                             {"label": "Pro Mensuel — $15/mois", "value": "mensuel"},
                                             {"label": "Pro Annuel — $120/an",   "value": "annuel"},
                                         ],
                                         value="annuel", clearable=False), width=4),
                    dbc.Col(dbc.Button("Générer la clé", id="btn-admin-generate-key",
                                       color="primary", className="w-100"), width=3),
                ], className="g-2 align-items-end"),
                html.Div(id="admin-generated-key", className="mt-3"),
                html.Div(id="admin-generate-msg",  className="mt-2"),
            ]),

            html.Hr(),

            # ── Sauvegarde / Restauration ─────────────────────────────────────
            html.Div(className="card", children=[
                html.H5("Sauvegarde de la base"),
                html.P(
                    "Téléchargez une copie de votre base de données (.db) "
                    "ou restaurez-en une ancienne.",
                    className="hint mb-3",
                ),
                html.Div(className="d-flex gap-3 align-items-center flex-wrap", children=[
                    dbc.Button("⬇ Télécharger la base", id="btn-admin-backup",
                               color="info", outline=True),
                    dcc.Upload(
                        id="upload-admin-restore",
                        children=dbc.Button("⬆ Restaurer une base",
                                            color="warning", outline=True),
                        accept=".db",
                        multiple=False,
                    ),
                ]),
                dcc.Download(id="download-db-backup"),
                html.Div(id="admin-backup-msg", className="mt-2"),
            ]),

            html.Hr(),

            # ── Paramètres API ────────────────────────────────────────────────
            html.Div(className="card", children=[
                html.H5("Paramètres API"),
                html.P("Clé Anthropic pour les analyses IA (onglet Analytics).",
                       className="hint mb-3"),
                dbc.Row([
                    dbc.Col(dbc.Input(id="admin-anthropic-key", type="password",
                                      placeholder="sk-ant-api03-…", maxLength=200), width=7),
                    dbc.Col(dbc.Button("Enregistrer", id="btn-admin-save-anthropic",
                                       color="primary", className="w-100"), width=3),
                    dbc.Col(html.Div(id="admin-anthropic-status", className="hint mt-1",
                                     style={"fontSize": "12px"}), width=2),
                ], className="g-2 align-items-end"),
                html.Div(id="admin-anthropic-msg", className="mt-2"),
            ]),
        ]),
    ])


# ── Onglet Plan ──────────────────────────────────────────────────────────────

def tab_plan() -> html.Div:

    def _plan_card(badge, title, price, price_sub, features, btn_id, btn_label,
                   btn_color, highlighted=False, badge_color=None, badge_bg=None, equiv=None):
        border = "2px solid #245c7c" if highlighted else "1.5px solid #dde3ea"
        bg     = "#f8fbff" if highlighted else "white"
        b_col  = badge_color or ("#245c7c" if highlighted else "#6b7785")
        return html.Div(style={
            "border": border, "borderRadius": "14px", "padding": "24px",
            "textAlign": "center", "height": "100%", "background": bg,
            "boxShadow": "0 4px 18px rgba(36,92,124,.10)" if highlighted else "none",
        }, children=[
            html.Div(badge, style={
                "fontSize": "11px", "fontWeight": "700", "letterSpacing": ".08em",
                "color": b_col, "marginBottom": "8px",
                **({"background": badge_bg, "display": "inline-block",
                    "padding": "2px 10px", "borderRadius": "999px"} if badge_bg else {}),
            }),
            html.H3(title, style={"fontWeight": "800", "color": "#245c7c", "margin": "4px 0 2px"}),
            html.Div([
                html.Span(price, style={"fontSize": "28px", "fontWeight": "800", "color": "#16324f"}),
                html.Span(f" {price_sub}", style={"fontSize": "13px", "color": "#6b7785"}),
                html.Div(equiv, style={"fontSize": "11px", "color": "#9aa5b1", "marginTop": "3px"})
                if equiv else None,
            ], style={"margin": "8px 0 18px"}),
            html.Ul([html.Li(f) for f in features],
                    style={"textAlign": "left", "fontSize": "13px",
                           "paddingLeft": "18px", "marginBottom": "20px"}),
            dbc.Button(btn_label, id=btn_id, color=btn_color,
                       outline=not highlighted, className="w-100", size="sm"),
        ])

    return html.Div([
        # ── Bandeau promo lancement ───────────────────────────────────────────
        html.Div(style={
            "background": "linear-gradient(90deg, #16324f 0%, #1a4a6e 100%)",
            "borderRadius": "12px", "padding": "12px 20px",
            "display": "flex", "alignItems": "center", "gap": "12px",
            "marginBottom": "16px", "flexWrap": "wrap",
        }, children=[
            html.Span("🎁", style={"fontSize": "20px"}),
            html.Div([
                html.Strong("Offre de lancement — ", style={"color": "white"}),
                html.Span("-30% avec le code ", style={"color": "rgba(255,255,255,0.8)", "fontSize": "14px"}),
                html.Code("LESTRADE2026", style={
                    "background": "#e6a700", "color": "#1a1a1a",
                    "padding": "2px 8px", "borderRadius": "4px",
                    "fontWeight": "800", "fontSize": "13px",
                }),
                html.Span(" valable jusqu'au 31/12/2026",
                          style={"color": "rgba(255,255,255,0.6)", "fontSize": "12px", "marginLeft": "6px"}),
            ]),
        ]),

        # ── Statut actuel ─────────────────────────────────────────────────────
        html.Div(className="card mb-2 d-flex flex-row align-items-center gap-3", children=[
            html.Div("Votre plan actuel :", style={"fontWeight": "600", "color": "#16324f"}),
            html.Div(id="plan-status-badge", style={
                "display": "inline-block", "padding": "5px 16px",
                "borderRadius": "999px", "fontWeight": "700", "fontSize": "13px",
                "background": "#e0f0ff", "color": "#245c7c",
            }),
            html.Div(id="plan-status-detail", className="hint", style={"fontSize": "13px"}),
        ]),

        # ── Cartes tarifaires (3 colonnes) ────────────────────────────────────
        dbc.Row([
            dbc.Col(_plan_card(
                badge="GRATUIT", title="Free", price="$0", price_sub="/ toujours",
                equiv="(0 FCFA · 0 €)",
                features=[
                    "5 questionnaires max",
                    "Collecte terrain mobile",
                    "Analytics de base",
                    "Zone publicitaire affichée",
                ],
                btn_id="btn-plan-free", btn_label="Continuer en Free",
                btn_color="secondary", highlighted=False,
            ), width=4),
            dbc.Col(_plan_card(
                badge="MENSUEL", title="Pro", price="$15", price_sub="/ mois",
                equiv="(~10 000 FCFA · ~14 €)",
                features=[
                    "Questionnaires illimités",
                    "Sans publicité ✓",
                    "Analyses IA (clé API perso)",
                    "Carte GPS analytique",
                    "Export Excel",
                    "Support email",
                ],
                btn_id="btn-plan-monthly", btn_label="Choisir Mensuel",
                btn_color="primary", highlighted=False,
            ), width=4),
            dbc.Col(_plan_card(
                badge="⭐ MEILLEURE OFFRE", title="Pro", price="$120",
                price_sub="/ an  · économisez $60",
                equiv="(~75 000 FCFA · ~110 €)  soit $10/mois",
                features=[
                    "Questionnaires illimités",
                    "Sans publicité ✓",
                    "Analyses IA (clé API perso)",
                    "Carte GPS analytique",
                    "Export Excel",
                    "Support prioritaire",
                ],
                btn_id="btn-plan-annual", btn_label="Choisir Annuel",
                btn_color="primary", highlighted=True,
                badge_color="#92400e", badge_bg="#fef3c7",
            ), width=4),
        ], className="g-3 mb-4"),

        # ── Suivre une demande existante ──────────────────────────────────────
        html.Div(className="card mb-3", children=[
            html.H5("Suivre ma demande"),
            html.P("Saisissez l'email utilisé lors de votre demande pour vérifier son statut.",
                   className="hint mb-3"),
            dbc.Row([
                dbc.Col(dbc.Input(id="plan-status-email", type="email",
                                  placeholder="votre@email.com", maxLength=254), width=7),
                dbc.Col(dbc.Button("Vérifier", id="btn-plan-check-status",
                                   color="info", outline=True, className="w-100"), width=2),
            ], className="g-2 align-items-end"),
            html.Div(id="plan-status-result", className="mt-2"),
        ]),

        dbc.Row([
            # ── Demander une clé ──────────────────────────────────────────────
            dbc.Col(html.Div(className="card", children=[
                html.H5("Demander une licence"),
                html.P("Remplissez ce formulaire — vous recevrez votre clé par email.",
                       className="hint mb-3"),
                dbc.Row([
                    dbc.Col(dbc.Input(id="plan-request-nom", type="text",
                                      placeholder="Nom ou organisation…",
                                      maxLength=200), width=12, className="mb-2"),
                    dbc.Col(dbc.Input(id="plan-request-email", type="email",
                                      placeholder="votre@email.com", maxLength=254),
                            width=12, className="mb-2"),
                    dbc.Col(dcc.Dropdown(
                        id="plan-request-formule",
                        options=[
                            {"label": "Pro Mensuel — $15/mois (~10 000 FCFA)", "value": "mensuel"},
                            {"label": "Pro Annuel — $120/an (~75 000 FCFA) · économisez $60", "value": "annuel"},
                        ],
                        value="annuel", clearable=False,
                    ), width=12, className="mb-2"),
                    # ── Code promo ────────────────────────────────────────────
                    dbc.Col(html.Div(className="d-flex gap-2", children=[
                        dbc.Input(id="plan-promo-input",
                                  placeholder="Code promo (ex: LESTRADE2026)",
                                  maxLength=30, style={"fontSize": "13px"}),
                        dbc.Button("Appliquer", id="btn-plan-promo",
                                   color="warning", size="sm",
                                   style={"whiteSpace": "nowrap"}),
                    ]), width=12, className="mb-1"),
                    dbc.Col(html.Div(id="plan-promo-msg"), width=12, className="mb-2"),
                ]),
                dbc.Button("Envoyer la demande", id="btn-plan-request",
                           color="success", className="w-100"),
                html.Div(id="plan-request-msg", className="mt-2"),
            ]), width=6),

            # ── Activer une clé existante ─────────────────────────────────────
            dbc.Col(html.Div(className="card", children=[
                html.H5("Activer une clé existante"),
                html.P("Saisissez la clé reçue par email après confirmation de paiement.",
                       className="hint mb-3"),
                dbc.Input(id="plan-licence-key",
                          placeholder="LEST-XXXX-XXXX-XXXX-XXXX",
                          maxLength=64, className="mb-2"),
                html.Div(id="plan-activate-error", className="alert-error mb-2",
                         style={"display": "none"}),
                dbc.Button("Activer la licence", id="btn-plan-activate",
                           color="primary", className="w-100"),
                html.Div(id="plan-activate-msg", className="mt-2"),
            ]), width=6),
        ], className="g-3"),
    ])


# ── Layout principal ──────────────────────────────────────────────────────────

def build_layout() -> html.Div:
    return html.Div(className="main-wrap", children=[
        # Stores globaux
        dcc.Store(id="store-selected-quest-id"),
        dcc.Store(id="store-user-email",    storage_type="local"),
        dcc.Store(id="store-licence-key",   storage_type="local"),
        dcc.Store(id="store-freemium-seen", storage_type="session"),
        dcc.Store(id="store-promo-code",    storage_type="session"),
        dcc.Store(id="store-admin-auth",    storage_type="session"),
        dcc.Store(id="store-prev-tab",      storage_type="session"),
        dcc.Interval(id="interval-refresh", interval=30_000, n_intervals=0),

        # Modals
        welcome_modal(),
        freemium_modal(),
        change_email_modal(),

        # ── Header : brand intégré comme premier onglet désactivé ──────────────
        dbc.Tabs(id="main-tabs", active_tab="accueil", className="app-tabs", children=[
            # Brand (onglet désactivé, non cliquable — sert de logo dans la barre)
            dbc.Tab(
                label="Lestrade Forms",
                tab_id="_brand",
                disabled=True,
                tab_style={"minWidth": "210px", "pointerEvents": "none", "cursor": "default"},
                label_style={"fontSize": "17px", "fontWeight": "800", "color": "white",
                             "letterSpacing": "-0.02em", "lineHeight": "1.15"},
                children=[],
            ),
            dbc.Tab(label="Accueil",        tab_id="accueil",      children=tab_accueil()),
            dbc.Tab(label="Gestion",        tab_id="gestion",      children=tab_gestion()),
            dbc.Tab(label="Construction",   tab_id="construction", children=tab_construction()),
            dbc.Tab(label="Remplir",        tab_id="remplir",      children=tab_remplir()),
            dbc.Tab(label="Réponses",       tab_id="reponses",     children=tab_reponses()),
            dbc.Tab(label="Analytics",      tab_id="analytics",    children=tab_analytics()),
            dbc.Tab(label="Panier / Drive", tab_id="panier",       id="tab-panier",
                    children=tab_panier()),
            dbc.Tab(label="Import externe", tab_id="import",       children=tab_import()),
            dbc.Tab(label="Plan",           tab_id="plan",         children=tab_plan()),
            dbc.Tab(
                id="tab-user-email-display",
                label="👤 Non connecté",
                tab_id="_user",
                disabled=False,
                tab_style={"marginLeft": "auto", "cursor": "pointer"},
                label_style={"fontSize": "12px", "color": "rgba(255,255,255,0.7)",
                             "fontWeight": "400", "fontStyle": "italic"},
                children=[],
            ),
            dbc.Tab(label="Admin",          tab_id="admin",        id="tab-admin",
                    children=tab_admin(),
                    label_style={"display": "none"},
                    disabled=True),
        ]),

        html.Div(className="ad-zone", id="ad-zone", children=[
            html.Div(className="ad-inner", children=[
                html.Div(className="ad-brand", children=[
                    html.Span("Lestrade Forms", className="ad-logo"),
                    html.Span("Pro", className="ad-badge-pro"),
                ]),
                html.Div(className="ad-features", children=[
                    html.Span("✨ Analyses IA"),
                    html.Span("·", className="ad-sep"),
                    html.Span("🗺 Carte GPS"),
                    html.Span("·", className="ad-sep"),
                    html.Span("📥 Export Excel"),
                    html.Span("·", className="ad-sep"),
                    html.Span("Questionnaires illimités"),
                ]),
                html.Button("Passer au Pro →", id="btn-ad-upgrade", className="ad-cta"),
            ]),
        ]),
    ])
