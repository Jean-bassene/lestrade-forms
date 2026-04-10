# ============================================================================
# ui_final.R  - v3  |  Thème professionnel + Page d'accueil
# ============================================================================

library(shiny); library(shinyjs); library(DT); library(plotly)

# ── Panneau analytics générique (préfixe "" ou "ext_") ───────────────────────
analytics_panel_ui <- function(pfx = "") {
  id <- function(x) paste0(pfx, x)
  tagList(
    fluidRow(
      column(3, div(class="kpi-card", div(class="kpi-value", textOutput(id("analytics_n"))),          div(class="kpi-label","Réponses analysées"))),
      column(3, div(class="kpi-card", div(class="kpi-value", textOutput(id("analytics_score_moyen"))), div(class="kpi-label","Score moyen (/10)"))),
      column(3, div(class="kpi-card", div(class="kpi-value", textOutput(id("analytics_score_max"))),   div(class="kpi-label","Score max"))),
      column(3, div(class="kpi-card", div(class="kpi-value", textOutput(id("analytics_score_min"))),   div(class="kpi-label","Score min")))
    ),
    div(class="panel-block",
      radioButtons(id("analytics_alpha"), "Seuil de signification",
        choices = c("α = 0.01" = 0.01, "α = 0.05" = 0.05, "α = 0.10" = 0.10),
        selected = 0.05, inline = TRUE)
    ),
    tabsetPanel(id = id("analytics_subtabs"), type = "pills",

      # Descriptif ──────────────────────────────────────────────────────────
      tabPanel("Descriptif",
        div(class="panel-block insight-block",
          div(class="insight-icon","✦"), uiOutput(id("analytics_summary"))),
        fluidRow(
          column(6, div(class="panel-block", h4(class="panel-title","Qualité des données"),    DTOutput(id("analytics_data_quality")))),
          column(6, div(class="panel-block", h4(class="panel-title","Complétude par section"), DTOutput(id("analytics_completion_table"))))
        ),
        div(class="panel-block",
          h4(class="panel-title","Graphique descriptif"),
          fluidRow(
            column(4, selectInput(id("analytics_plot_type"),"Type",
              choices=c("Barres"="bar","Secteur"="pie","Histogramme"="histogram","Boxplot"="boxplot"),selected="bar")),
            column(8, selectInput(id("analytics_plot_var"),"Variable",choices=c("Sélectionner..."="")))
          ),
          uiOutput(id("analytics_plot_message")),
          plotlyOutput(id("analytics_single_plot"),height="400px")
        )
      ),

      # Tableaux ────────────────────────────────────────────────────────────
      tabPanel("Tableaux",
        div(class="panel-block",
          h4(class="panel-title","Tableau croisé"),
          fluidRow(
            column(4, selectInput(id("analytics_table_row"),  "Lignes",         choices=c("Sélectionner..."=""))),
            column(4, selectInput(id("analytics_table_col"),  "Colonnes",        choices=c("Sélectionner..."=""))),
            column(4, selectInput(id("analytics_table_split"),"Stratification",  choices=c("Aucune"="")))
          ),
          radioButtons(id("analytics_table_mode"),"Affichage",inline=TRUE,
            choices=c("Effectifs"="count","% ligne"="row_pct","% colonne"="col_pct","% global"="global_pct"),
            selected="count"),
          DTOutput(id("analytics_crosstab"))
        ),
        div(class="panel-block",
          h4(class="panel-title","Tableau de synthèse comparatif"),
          fluidRow(
            column(4, selectInput(id("analytics_gtsummary_by"),  "Variable de comparaison",choices=c("Sélectionner..."=""))),
            column(8, selectInput(id("analytics_gtsummary_vars"),"Variables à résumer",choices=c(),multiple=TRUE,selectize=FALSE,size=6))
          ),
          uiOutput(id("analytics_gtsummary_message")),
          DTOutput(id("analytics_gtsummary_table"))
        )
      ),

      # Comparaisons ────────────────────────────────────────────────────────
      tabPanel("Comparaisons",
        div(class="panel-block",
          fluidRow(
            column(4, selectInput(id("analytics_compare_row"),"Lignes",   choices=c("Sélectionner..."=""))),
            column(4, selectInput(id("analytics_compare_col"),"Colonnes", choices=c("Sélectionner..."=""))),
            column(4, selectInput(id("analytics_compare_plot_type"),"Graphe",
              choices=c("Barres empilées"="stacked","Mosaïque"="mosaic","Association"="association"),selected="stacked"))
          )
        ),
        fluidRow(
          column(7, div(class="panel-block", h4(class="panel-title","Visualisation"), uiOutput(id("analytics_bivariate_container")))),
          column(5, div(class="panel-block", h4(class="panel-title","Test statistique"),
            verbatimTextOutput(id("analytics_test_results")),
            uiOutput(id("analytics_test_interpretation"))))
        )
      ),

      # Profils ─────────────────────────────────────────────────────────────
      tabPanel("Profils",
        div(class="panel-block",
          fluidRow(
            column(6, selectInput(id("analytics_profile_group"),    "Variable de groupe",choices=c("Sélectionner..."=""))),
            column(6, selectInput(id("analytics_profile_view_mode"),"Vue",
              choices=c("Par section"="section","Par indicateur"="indicator"),selected="section"))
          )
        ),
        fluidRow(
          column(6, div(class="panel-block", h4(class="panel-title","Synthèse"),          DTOutput(id("analytics_profile_summary_table")))),
          column(6, div(class="panel-block", h4(class="panel-title","Scores sections"),   DTOutput(id("analytics_profile_section_table"))))
        ),
        div(class="panel-block", h4(class="panel-title","Heatmap groupes × sections"),
          plotlyOutput(id("analytics_profile_heatmap"),height="460px")),
        div(class="panel-block", h4(class="panel-title","Détail par indicateur"),
          DTOutput(id("analytics_profile_table"))),
        div(class="panel-block", h4(class="panel-title","Radar comparatif"),
          plotlyOutput(id("analytics_profile_radar"),height="500px"))
      ),

      # Avancé ──────────────────────────────────────────────────────────────
      tabPanel("Avancé",
        tabsetPanel(type="pills",
          tabPanel("Comparaisons avancées",
            div(class="panel-block",
              fluidRow(
                column(6, selectInput(id("advanced_compare_group"), "Groupe",  choices=c("Sélectionner..."=""))),
                column(6, selectInput(id("advanced_compare_target"),"Variable",choices=c("Sélectionner..."="")))
              )
            ),
            fluidRow(
              column(7, div(class="panel-block", DTOutput(id("advanced_compare_table")))),
              column(5, div(class="panel-block", verbatimTextOutput(id("advanced_compare_text"))))
            )
          ),
          tabPanel("Scores composites",
            div(class="panel-block",
              fluidRow(
                column(4, selectInput(id("advanced_composite_group"),   "Groupe",  choices=c("Sélectionner..."=""))),
                column(8, selectInput(id("advanced_composite_sections"),"Sections",choices=c(),multiple=TRUE,selectize=FALSE,size=5))
              )
            ),
            fluidRow(
              column(7, div(class="panel-block", DTOutput(id("advanced_composite_table")))),
              column(5, div(class="panel-block", plotlyOutput(id("advanced_composite_plot"),height="360px")))
            )
          ),
          tabPanel("Régression logistique",
            div(class="panel-block",
              fluidRow(
                column(4, selectInput(id("advanced_logit_outcome"),    "Variable binaire cible",choices=c("Sélectionner..."=""))),
                column(8, selectInput(id("advanced_logit_predictors"), "Variables explicatives",choices=c(),multiple=TRUE,selectize=FALSE,size=5))
              )
            ),
            fluidRow(
              column(7, div(class="panel-block", DTOutput(id("advanced_logit_table")))),
              column(5, div(class="panel-block", verbatimTextOutput(id("advanced_logit_text"))))
            )
          ),
          tabPanel("Corrélations",
            div(class="panel-block", plotlyOutput(id("advanced_corr_plot"),height="460px")),
            div(class="panel-block", DTOutput(id("advanced_corr_table")))
          ),
          tabPanel("Exports",
            div(class="panel-block",
              h4(class="panel-title","Télécharger les données"),
              p(class="hint-text","Exportez le jeu analytique nettoyé ou les scores par section."),
              div(class="action-row",
                downloadButton(id("download_analytics_csv"),"Dataset analytique (.csv)",class="btn-outline"),
                downloadButton(id("download_scores_csv"),   "Scores sections (.csv)",   class="btn-outline")
              )
            )
          )
        )
      )
    )
  )
}


# ── CSS complet ───────────────────────────────────────────────────────────────
APP_CSS <- "
@import url('https://fonts.googleapis.com/css2?family=Playfair+Display:wght@600;700&family=IBM+Plex+Sans:ital,wght@0,300;0,400;0,500;0,600;1,300&family=IBM+Plex+Mono:wght@400;500&display=swap');
:root {
  --navy:        #0D1F35;
  --navy-mid:    #163554;
  --navy-light:  #1E4976;
  --amber:       #E8A020;
  --amber-lt:    #FDF0D5;
  --amber-dk:    #C4831A;
  --teal:        #0A8075;
  --teal-lt:     #D1F0EC;
  --red:         #C0392B;
  --red-lt:      #FDECEA;
  --surface:     #F5F7FA;
  --surface-2:   #EEF1F6;
  --white:       #FFFFFF;
  --border:      #DDE3EC;
  --border-2:    #C8D1DF;
  --text-1:      #0D1F35;
  --text-2:      #4A5870;
  --text-3:      #8896A7;
  --shadow-sm:   0 2px 8px rgba(13,31,53,.07);
  --shadow-md:   0 6px 24px rgba(13,31,53,.10);
  --shadow-lg:   0 16px 48px rgba(13,31,53,.14);
  --r:           14px; --r-sm: 8px; --r-lg: 22px;
  --ease:        .22s cubic-bezier(.4,0,.2,1);
}
*,*::before,*::after{box-sizing:border-box;}
body{font-family:'IBM Plex Sans',sans-serif;background:var(--surface);color:var(--text-1);font-size:14px;line-height:1.6;margin:0;padding-top:60px;}
h1,h2,h3{font-family:'Playfair Display',serif;font-weight:700;line-height:1.2;margin:0 0 .5rem;}
h4{font-family:'IBM Plex Sans',sans-serif;font-weight:600;font-size:.95rem;margin:0 0 .4rem;}
h1{font-size:2.4rem;} h2{font-size:1.7rem;} h3{font-size:1.2rem;}
p{margin:0 0 .65rem;}
.app-header{
  position:fixed;top:0;left:0;right:0;z-index:999;
  height:60px;background:var(--navy);
  display:flex;align-items:center;padding:0 28px;gap:16px;
  box-shadow:0 2px 16px rgba(0,0,0,.28);
}
.brand{font-family:'Playfair Display',serif;font-size:1.1rem;font-weight:700;color:#fff;letter-spacing:-.01em;white-space:nowrap;}
.brand em{color:var(--amber);font-style:normal;}
.header-nav{display:flex;gap:4px;margin-left:auto;}
.hnav-btn{background:transparent;border:none;color:rgba(255,255,255,.65);padding:6px 13px;border-radius:6px;cursor:pointer;font-family:'IBM Plex Sans',sans-serif;font-size:12.5px;font-weight:500;transition:var(--ease);}
.hnav-btn:hover{background:rgba(255,255,255,.1);color:#fff;}
.drive-badge{display:flex;align-items:center;gap:7px;padding:5px 12px;border-radius:20px;font-size:12px;font-weight:500;cursor:pointer;border:none;white-space:nowrap;margin-left:8px;}
.drive-badge.connected{background:rgba(34,197,94,.15);color:#4ade80;border:1px solid rgba(34,197,94,.3);}
.drive-badge.disconnected{background:rgba(245,158,11,.15);color:#F59E0B;border:1px solid rgba(245,158,11,.3);}
.drive-dot{width:7px;height:7px;border-radius:50%;flex-shrink:0;}
.drive-dot.on{background:#4ade80;} .drive-dot.off{background:#F59E0B;}
#header_drive_badge{display:flex;align-items:center;}
#header_drive_badge .shiny-html-output{display:flex;align-items:center;}
.main-content{max-width:1420px;margin:0 auto;padding:28px 32px 56px;}
/* ── Tabs override ── */
.tab-content{padding:0;}
.nav-pills{display:flex;flex-wrap:wrap;gap:6px;margin-bottom:20px;border:none!important;}
.nav-pills>li>a{font-family:'IBM Plex Sans',sans-serif!important;font-size:12.5px!important;font-weight:500!important;color:var(--text-2)!important;border-radius:8px!important;padding:7px 15px!important;background:var(--surface-2)!important;border:1px solid var(--border)!important;transition:var(--ease)!important;}
.nav-pills>li.active>a,.nav-pills>li.active>a:hover{background:var(--navy)!important;color:#fff!important;border-color:var(--navy)!important;}
.nav-tabs{display:flex;flex-wrap:wrap;gap:0;border-bottom:2px solid var(--border)!important;margin-bottom:20px;}
.nav-tabs>li>a{font-family:'IBM Plex Sans',sans-serif!important;font-size:13px!important;font-weight:500!important;color:var(--text-2)!important;border:none!important;border-bottom:2px solid transparent!important;margin-bottom:-2px!important;padding:10px 18px!important;transition:var(--ease)!important;}
.nav-tabs>li.active>a,.nav-tabs>li.active>a:focus{color:var(--navy)!important;border-bottom-color:var(--amber)!important;background:transparent!important;}
/* ── Landing ── */
.landing-hero{background:linear-gradient(140deg,var(--navy) 0%,var(--navy-mid) 55%,#1a4f7a 100%);border-radius:var(--r-lg);padding:52px 48px;margin-bottom:32px;position:relative;overflow:hidden;box-shadow:var(--shadow-lg);animation:fadeUp .5s ease both;}
.landing-hero::before{content:'';position:absolute;top:-80px;right:-80px;width:400px;height:400px;border-radius:50%;background:radial-gradient(circle,rgba(232,160,32,.15) 0%,transparent 65%);pointer-events:none;}
.landing-hero::after{content:'';position:absolute;bottom:-100px;left:20%;width:300px;height:300px;border-radius:50%;background:radial-gradient(circle,rgba(255,255,255,.04) 0%,transparent 65%);pointer-events:none;}
.hero-eyebrow{display:inline-block;background:rgba(232,160,32,.18);color:var(--amber);border:1px solid rgba(232,160,32,.32);border-radius:999px;padding:4px 14px;font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:.08em;margin-bottom:16px;}
.landing-hero h1{font-size:2.8rem;color:#fff;margin-bottom:12px;line-height:1.12;}
.landing-hero h1 em{color:var(--amber);font-style:normal;}
.landing-hero p{color:rgba(255,255,255,.68);font-size:1.05rem;max-width:560px;margin-bottom:28px;font-weight:300;}
.hero-stats{display:flex;gap:40px;padding-top:26px;border-top:1px solid rgba(255,255,255,.1);}
.hstat-val{font-size:1.9rem;font-weight:700;color:#fff;font-family:'IBM Plex Mono',monospace;line-height:1;}
.hstat-lbl{font-size:10.5px;text-transform:uppercase;letter-spacing:.06em;color:rgba(255,255,255,.45);margin-top:3px;}
/* Feature grid */
.features-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:18px;margin-bottom:32px;}
.feature-card{background:var(--white);border:1px solid var(--border);border-radius:var(--r);padding:24px;cursor:pointer;transition:var(--ease);position:relative;overflow:hidden;}
.feature-card::after{content:'';position:absolute;top:0;left:0;right:0;height:3px;background:var(--border);transition:var(--ease);}
.feature-card:hover{box-shadow:var(--shadow-md);transform:translateY(-3px);border-color:var(--border-2);}
.feature-card:hover::after{background:var(--amber);}
.fc-icon{width:42px;height:42px;border-radius:10px;display:flex;align-items:center;justify-content:center;font-size:20px;margin-bottom:12px;}
.feature-card h3{font-family:'IBM Plex Sans',sans-serif;font-size:.9rem;font-weight:600;margin-bottom:5px;}
.feature-card p{font-size:12.5px;color:var(--text-2);margin:0;line-height:1.5;}
.fc-arrow{position:absolute;bottom:18px;right:18px;color:var(--text-3);font-size:17px;transition:var(--ease);}
.feature-card:hover .fc-arrow{color:var(--amber);transform:translate(3px,-3px);}
.fc-blue   .fc-icon{background:#EBF3FF;color:#1565C0;}
.fc-teal   .fc-icon{background:var(--teal-lt);color:var(--teal);}
.fc-amber  .fc-icon{background:var(--amber-lt);color:var(--amber-dk);}
.fc-purple .fc-icon{background:#F0EBFF;color:#6A3DC8;}
.fc-red    .fc-icon{background:var(--red-lt);color:var(--red);}
.fc-green  .fc-icon{background:#E6F7EE;color:#1A7F4B;}
/* Animation stagger */
@keyframes fadeUp{from{opacity:0;transform:translateY(18px);}to{opacity:1;transform:translateY(0);}}
.landing-hero{animation:fadeUp .48s ease both;}
.feature-card:nth-child(1){animation:fadeUp .42s .05s ease both;}
.feature-card:nth-child(2){animation:fadeUp .42s .10s ease both;}
.feature-card:nth-child(3){animation:fadeUp .42s .15s ease both;}
.feature-card:nth-child(4){animation:fadeUp .42s .20s ease both;}
.feature-card:nth-child(5){animation:fadeUp .42s .25s ease both;}
.feature-card:nth-child(6){animation:fadeUp .42s .30s ease both;}
/* KPI */
.kpi-card{background:var(--white);border:1px solid var(--border);border-radius:var(--r);padding:16px 18px;text-align:center;margin-bottom:20px;box-shadow:var(--shadow-sm);}
.kpi-value{font-size:1.9rem;font-weight:700;color:var(--navy);font-family:'IBM Plex Mono',monospace;line-height:1;}
.kpi-label{font-size:10.5px;text-transform:uppercase;letter-spacing:.05em;color:var(--text-3);margin-top:4px;}
/* Dash metrics */
.dash-metrics{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin-bottom:22px;}
.dash-metric{background:var(--white);border:1px solid var(--border);border-left:4px solid var(--amber);border-radius:var(--r);padding:14px 18px;box-shadow:var(--shadow-sm);}
.dash-metric .val{font-size:1.7rem;font-weight:700;color:var(--navy);font-family:'IBM Plex Mono',monospace;line-height:1;}
.dash-metric .lbl{font-size:10.5px;text-transform:uppercase;letter-spacing:.05em;color:var(--text-3);margin-top:3px;}
/* Panel */
.panel-block{background:var(--white);border:1px solid var(--border);border-radius:var(--r);padding:20px 22px;margin-bottom:18px;box-shadow:var(--shadow-sm);}
.panel-title{font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:.06em;color:var(--text-2);margin-bottom:14px;padding-bottom:10px;border-bottom:1px solid var(--surface-2);}
.insight-block{background:linear-gradient(135deg,#F0F5FF 0%,#FFFBEF 100%);border-color:#D1DCF0;display:flex;gap:14px;align-items:flex-start;}
.insight-icon{font-size:1.4rem;color:var(--amber);flex-shrink:0;margin-top:2px;}
/* Buttons */
.btn-primary{background:var(--navy)!important;color:#fff!important;border:none!important;border-radius:var(--r-sm)!important;font-family:'IBM Plex Sans',sans-serif!important;font-weight:500!important;font-size:13px!important;padding:8px 18px!important;transition:var(--ease)!important;box-shadow:var(--shadow-sm)!important;}
.btn-primary:hover{background:var(--navy-light)!important;box-shadow:var(--shadow-md)!important;}
.btn-success{background:var(--teal)!important;color:#fff!important;border:none!important;border-radius:var(--r-sm)!important;font-family:'IBM Plex Sans',sans-serif!important;font-weight:500!important;font-size:13px!important;padding:8px 18px!important;}
.btn-info{background:#1565C0!important;color:#fff!important;border:none!important;border-radius:var(--r-sm)!important;font-family:'IBM Plex Sans',sans-serif!important;font-weight:500!important;font-size:13px!important;padding:8px 18px!important;}
.btn-warning{background:var(--amber)!important;color:var(--navy)!important;border:none!important;border-radius:var(--r-sm)!important;font-family:'IBM Plex Sans',sans-serif!important;font-weight:600!important;font-size:13px!important;padding:8px 18px!important;}
.btn-danger{background:var(--red)!important;color:#fff!important;border:none!important;border-radius:var(--r-sm)!important;font-family:'IBM Plex Sans',sans-serif!important;font-weight:500!important;font-size:13px!important;padding:8px 18px!important;}
.btn-outline{background:transparent!important;color:var(--navy)!important;border:1.5px solid var(--border-2)!important;border-radius:var(--r-sm)!important;font-family:'IBM Plex Sans',sans-serif!important;font-weight:500!important;font-size:13px!important;padding:8px 18px!important;transition:var(--ease)!important;}
.btn-outline:hover{border-color:var(--navy)!important;background:var(--surface)!important;}
.btn-lg{padding:11px 26px!important;font-size:14px!important;}
.action-row{display:flex;gap:8px;flex-wrap:wrap;}
.btn-qr-row{background:var(--navy);color:#fff;border:none;border-radius:6px;padding:4px 10px;font-size:12px;font-weight:500;cursor:pointer;transition:var(--ease);}
.btn-qr-row:hover{background:var(--navy-light);}
/* Forms */
.form-control,.selectize-input,select.form-control{border:1.5px solid var(--border)!important;border-radius:var(--r-sm)!important;font-family:'IBM Plex Sans',sans-serif!important;font-size:13px!important;color:var(--text-1)!important;background:var(--white)!important;box-shadow:none!important;transition:var(--ease)!important;}
.form-control:focus,.selectize-input.focus{border-color:var(--navy-light)!important;outline:none!important;box-shadow:0 0 0 3px rgba(30,73,118,.10)!important;}
label{font-size:11.5px;font-weight:600;text-transform:uppercase;letter-spacing:.04em;color:var(--text-2);margin-bottom:5px;display:block;}
.radio label,.checkbox label{text-transform:none;font-weight:400;letter-spacing:0;font-size:13px;color:var(--text-1);}
/* Tables */
table.dataTable thead th{background:var(--surface)!important;color:var(--text-2)!important;font-size:11px!important;font-weight:600!important;text-transform:uppercase!important;letter-spacing:.05em!important;border-bottom:2px solid var(--border)!important;padding:10px 12px!important;}
table.dataTable tbody td{font-size:13px!important;padding:9px 12px!important;border-bottom:1px solid var(--surface-2)!important;}
table.dataTable tbody tr:hover{background:var(--amber-lt)!important;}
table.dataTable tbody tr.selected td{background:#EBF3FF!important;}
/* Builder */
.section-card{background:var(--white);border:1px solid var(--border);border-left:4px solid var(--amber);border-radius:var(--r);padding:18px 20px;margin:12px 0;box-shadow:var(--shadow-sm);}
.question-item{background:var(--surface);border:1px solid var(--border);border-radius:var(--r-sm);padding:10px 14px;margin-top:8px;}
/* Badges */
.badge-tag{display:inline-block;background:var(--amber-lt);color:var(--amber-dk);border:1px solid rgba(232,160,32,.28);border-radius:999px;padding:3px 12px;font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:.06em;margin-bottom:10px;}
.badge-navy{background:#EBF3FF;color:var(--navy-light);border-color:rgba(30,73,118,.18);}
/* Hints */
.hint-text{color:var(--text-3);font-size:12.5px;line-height:1.5;}
.required-mark{color:var(--red);font-weight:700;margin-left:2px;}
/* Import steps */
.import-step{display:flex;gap:16px;align-items:flex-start;margin-bottom:10px;}
.step-num{width:30px;height:30px;flex-shrink:0;border-radius:50%;background:var(--navy);color:#fff;font-weight:700;font-size:13px;display:flex;align-items:center;justify-content:center;}
/* Modal */
.modal-content{border-radius:var(--r)!important;border:none!important;box-shadow:var(--shadow-lg)!important;}
.modal-header{border-bottom:1px solid var(--border)!important;padding:14px 20px!important;}
.modal-header h4{font-family:'IBM Plex Sans',sans-serif!important;font-weight:600!important;}
.modal-body{padding:18px 20px!important;}
.modal-footer{border-top:1px solid var(--border)!important;padding:12px 20px!important;}
/* Notifications */
#shiny-notification-panel{bottom:20px!important;right:20px!important;top:auto!important;}
.shiny-notification{font-family:'IBM Plex Sans',sans-serif!important;border-radius:var(--r-sm)!important;border:none!important;box-shadow:var(--shadow-md)!important;font-size:13px!important;}
.shiny-notification-message{background:var(--navy)!important;color:#fff!important;}
.shiny-notification-warning{background:var(--amber)!important;color:var(--navy)!important;}
.shiny-notification-error{background:var(--red)!important;color:#fff!important;}
/* Status */
.status-ok{background:var(--teal-lt);border:1px solid rgba(10,128,117,.22);border-radius:var(--r-sm);padding:10px 14px;font-size:13px;color:var(--teal);font-weight:500;display:flex;align-items:center;gap:8px;margin-bottom:14px;}
::-webkit-scrollbar{width:6px;height:6px;}
::-webkit-scrollbar-track{background:var(--surface);}
::-webkit-scrollbar-thumb{background:var(--border-2);border-radius:3px;}
::-webkit-scrollbar-thumb:hover{background:var(--text-3);}
/* Import topbar */
.import-topbar{display:flex;align-items:center;gap:14px;background:var(--white);border:1px solid var(--border);border-radius:var(--r);padding:12px 20px;margin-bottom:18px;box-shadow:var(--shadow-sm);}
.import-topbar-left{display:flex;align-items:center;gap:10px;}
.import-topbar-title{font-weight:600;font-size:.9rem;color:var(--text-1);}
.import-topbar-badge{background:var(--teal-lt);color:var(--teal);border:1px solid rgba(10,128,117,.22);border-radius:999px;padding:2px 10px;font-size:11px;font-weight:600;}
/* Licence badge header */
.licence-badge{display:flex;align-items:center;gap:7px;padding:5px 12px;border-radius:20px;font-size:12px;font-weight:500;cursor:pointer;border:none;white-space:nowrap;margin-left:4px;}
.licence-badge.premium{background:rgba(34,197,94,.15);color:#4ade80;border:1px solid rgba(34,197,94,.3);}
.licence-badge.trial{background:rgba(245,158,11,.15);color:#F59E0B;border:1px solid rgba(245,158,11,.3);}
.licence-badge.expire{background:rgba(192,57,43,.15);color:#e74c3c;border:1px solid rgba(192,57,43,.3);}
/* Bannière licence */
.licence-banner{position:fixed;top:60px;left:0;right:0;z-index:998;display:flex;align-items:center;justify-content:space-between;padding:8px 28px;font-size:13px;font-weight:500;}
.licence-banner.trial{background:linear-gradient(90deg,#7c4a00,#c07a00);color:#fff;}
.licence-banner.expire{background:linear-gradient(90deg,var(--red),#922b21);color:#fff;}
.licence-banner-btn{background:rgba(255,255,255,.2);border:1px solid rgba(255,255,255,.4);color:#fff;border-radius:6px;padding:4px 14px;font-size:12px;font-weight:600;cursor:pointer;}
.licence-banner-btn:hover{background:rgba(255,255,255,.35);}
/* Quand bannière présente, pousser le contenu vers le bas */
body.has-licence-banner{padding-top:96px!important;}
@media(max-width:900px){.features-grid{grid-template-columns:repeat(2,1fr);}.dash-metrics{grid-template-columns:repeat(2,1fr);}.main-content{padding:16px 12px 36px;}.landing-hero{padding:30px 18px;}.landing-hero h1{font-size:1.9rem;}.hero-stats{gap:20px;flex-wrap:wrap;}}
@media(max-width:560px){.features-grid{grid-template-columns:1fr;}}
"


# ── JS navigation ─────────────────────────────────────────────────────────────
APP_JS <- "
// Handler bannière licence
Shiny.addCustomMessageHandler('addBodyClass', function(cls) {
  document.body.classList.add(cls);
});
Shiny.addCustomMessageHandler('removeBodyClass', function(cls) {
  document.body.classList.remove(cls);
});
// Cacher le nav natif du tabsetPanel principal
function hideMainNav(){
  var navs = document.querySelectorAll('ul.nav.nav-tabs, ul.nav.nav-pills, ul.nav');
  navs.forEach(function(n){
    if(n.querySelector('a[data-value=\"Accueil\"]')) n.style.cssText='display:none!important';
  });
}
document.addEventListener('DOMContentLoaded', function(){
  hideMainNav();
  setTimeout(hideMainNav, 300);
  setTimeout(hideMainNav, 1000);
});

$(document).on('click', '.feature-card[data-tab]', function(){
  $('a[data-value=\"' + $(this).data('tab') + '\"]').tab('show');
});
"


# ══════════════════════════════════════════════════════════════════════════════
# UI principale
# ══════════════════════════════════════════════════════════════════════════════
ui <- fluidPage(
  useShinyjs(),
  title = "Lestrade Forms · Enquêtes & Analyses",
  tags$head(
    tags$link(rel = "icon", type = "image/png", href = "favicon.png"),
    tags$style(HTML(APP_CSS)),
    tags$script(HTML(APP_JS))
  ),

  # ── Header fixe ───────────────────────────────────────────────────────────
  div(class = "app-header",
    div(class = "brand", "Lestrade", tags$em(" Forms")),
    div(class = "header-nav",
      tags$button(class="hnav-btn", onclick="$('a[data-value=\"Accueil\"]').tab('show')",         "Accueil"),
      tags$button(class="hnav-btn", onclick="$('a[data-value=\"Gestion\"]').tab('show')",          "Gestion"),
      tags$button(class="hnav-btn", onclick="$('a[data-value=\"Construction\"]').tab('show')",     "Construction"),
      tags$button(class="hnav-btn", onclick="$('a[data-value=\"Réponses\"]').tab('show')",         "Réponses"),
      tags$button(class="hnav-btn", onclick="$('a[data-value=\"Analytics\"]').tab('show')",        "Analytics"),
      tags$button(class="hnav-btn", onclick="$('a[data-value=\"Import\"]').tab('show')",           "Import"),
      tags$button(class="hnav-btn", onclick="$('a[data-value=\"Analyse externe\"]').tab('show')", "Analyse externe")
    ),
    # Badge licence (trial/premium/expiré)
    uiOutput("header_licence_badge"),
    uiOutput("header_drive_badge")
  ),

  # ── Bannière licence (compte à rebours ou expiration) ─────────────────────
  uiOutput("licence_banner"),

  div(class = "main-content",
    tabsetPanel(id = "main_tabs",

      # ══ ACCUEIL ════════════════════════════════════════════════════════════
      tabPanel("Accueil",

        # Hero
        div(class = "landing-hero",
          div(class="hero-eyebrow","Plateforme universelle de gestion d'enquêtes"),
          h1(HTML("Collectez. Analysez.<br><em>Décidez.</em>")),
          p("Construisez vos questionnaires, collectez des réponses terrain et produisez des analyses statistiques avancées — conçu pour toute organisation qui travaille avec des données d'enquête."),
          div(class="hero-stats",
            div(div(class="hstat-val",textOutput("metric_questionnaires")), div(class="hstat-lbl","Questionnaires")),
            div(div(class="hstat-val",textOutput("metric_reponses")),       div(class="hstat-lbl","Réponses")),
            div(div(class="hstat-val",textOutput("metric_questions")),      div(class="hstat-lbl","Questions")),
            div(div(class="hstat-val",textOutput("metric_sections")),       div(class="hstat-lbl","Sections"))
          )
        ),

        # Feature cards
        tags$p(style="font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:.07em;color:var(--text-3);margin-bottom:14px;",
               "Accès rapide aux modules"),
        div(class = "features-grid",
          div(class="feature-card fc-blue",  `data-tab`="Gestion",
            div(class="fc-icon","🗂"),  h3("Gestion"), p("Créez et gérez vos questionnaires. Vue d'ensemble de tous vos projets d'enquête."), div(class="fc-arrow","↗")),
          div(class="feature-card fc-teal",  `data-tab`="Construction",
            div(class="fc-icon","🔧"),  h3("Construction"), p("Ajoutez sections et questions : Likert, choix multiple, texte libre, date et plus."), div(class="fc-arrow","↗")),
          div(class="feature-card fc-green", `data-tab`="Remplir",
            div(class="fc-icon","📝"),  h3("Saisie"), p("Formulaire de collecte interactif. Remplissez ou importez les réponses de terrain."), div(class="fc-arrow","↗")),
          div(class="feature-card fc-amber", `data-tab`="Réponses",
            div(class="fc-icon","📋"),  h3("Réponses"), p("Consultez, modifiez, filtrez et exportez les réponses collectées. Export Excel."), div(class="fc-arrow","↗")),
          div(class="feature-card fc-purple",`data-tab`="Analytics",
            div(class="fc-icon","📊"),  h3("Analytics"), p("Tableaux croisés, tests statistiques, profils comparatifs, régression logistique."), div(class="fc-arrow","↗")),
          div(class="feature-card fc-red",   `data-tab`="Import",
            div(class="fc-icon","📥"),  h3("Import & Analyse externe"), p("Importez un fichier Google Forms ou KoboToolbox et analysez-le directement."), div(class="fc-arrow","↗"))
        ),

        # Guide de démarrage
        div(class="panel-block",
          div(class="badge-tag","Comment démarrer"),
          fluidRow(
            column(4,
              div(class="import-step",
                div(class="step-num","1"),
                div(h4("Créer un questionnaire"),
                    p(class="hint-text","Onglet Gestion → Créer → donnez un nom et une description à votre enquête."))
              )
            ),
            column(4,
              div(class="import-step",
                div(class="step-num","2"),
                div(h4("Construire la structure"),
                    p(class="hint-text","Onglet Construction → ajoutez des sections puis des questions de différents types."))
              )
            ),
            column(4,
              div(class="import-step",
                div(class="step-num","3"),
                div(h4("Analyser les résultats"),
                    p(class="hint-text","Saisissez des réponses puis explorez l'onglet Analytics pour les graphes et les tests."))
              )
            )
          ),
          tags$hr(style="border-color:var(--surface-2);margin:16px 0;"),
          p(class="hint-text", style="text-align:center;",
            "💡 Vous avez un fichier Excel ou CSV existant ? Utilisez l'onglet ",
            tags$strong("Import"), " pour le charger et l'analyser sans aucune configuration.")
        )
      ),

      # ══ GESTION ════════════════════════════════════════════════════════════
      tabPanel("Gestion",
        # ── QR de connexion API ──────────────────────────────────────────────
        div(class="panel-block", style="background:#F0F4FF;border-color:#003366;margin-bottom:16px;",
          div(style="display:flex;align-items:flex-start;gap:20px;flex-wrap:wrap;",
            uiOutput("api_qr_ui"),
            div(style="padding-top:8px;",
              tags$strong(style="color:#003366;font-size:15px;", "📱 Connexion Mobile"),
              tags$br(),
              span(style="color:var(--text2);font-size:13px;",
                "Faites scanner ce QR code par les enquêteurs."),
              tags$br(),
              span(style="color:var(--text2);font-size:13px;",
                "L'adresse du serveur sera configurée automatiquement."),
              tags$br(), tags$br(),
              actionButton("btn_show_api_qr", "🔄 Rafraîchir",
                           class="btn-outline", style="font-size:12px;")
            )
          )
        ),
        div(class="dash-metrics",
          div(class="dash-metric", div(class="val",textOutput("dash_n_quests")),   div(class="lbl","Questionnaires")),
          div(class="dash-metric", div(class="val",textOutput("dash_n_sections")), div(class="lbl","Sections")),
          div(class="dash-metric", div(class="val",textOutput("dash_n_questions")),div(class="lbl","Questions")),
          div(class="dash-metric", div(class="val",textOutput("dash_n_reponses")), div(class="lbl","Réponses"))
        ),
        div(class="panel-block",
          div(class="badge-tag","Nouveau"),
          h3(style="margin-bottom:14px;","Créer un questionnaire"),
          fluidRow(
            column(4, textInput("input_nom","Nom",placeholder="Ex : Enquête satisfaction 2026")),
            column(6, textInput("input_desc","Description",placeholder="Objectif, cible, contexte...")),
            column(2, br(), actionButton("btn_creer","Créer",class="btn-primary btn-lg",style="width:100%;"))
          )
        ),
        div(class="panel-block",
          div(style="display:flex;align-items:center;gap:10px;margin-bottom:6px;",
            div(class="badge-tag",style="margin-bottom:0;","Tous les questionnaires"),
            actionButton("btn_refresh_gestion","↻ Actualiser",
                         class="btn-outline", style="margin-left:auto;padding:5px 14px;font-size:12px;")
          ),
          p(class="hint-text","Sélectionnez une ligne pour activer les actions ci-dessous."),
          DTOutput("table_questionnaires"),
          br(),
          div(class="action-row",
            actionButton("btn_open_builder",   "🔧 Construire", class="btn-info"),
            actionButton("btn_open_fill",      "📝 Remplir",    class="btn-success"),
            actionButton("btn_open_answers",   "📋 Réponses",   class="btn-warning"),
            actionButton("btn_open_analytics", "📊 Analytics",  class="btn-primary"),
            actionButton("btn_share_qr",       "📱 QR Code",    class="btn-outline"),
            actionButton("btn_supprimer_quest","🗑 Supprimer",  class="btn-danger")
          ),
          br(),
          div(style="display:flex;align-items:center;gap:10px;",
            actionButton("btn_publish_all_drive", "☁ Publier tous sur Drive",
                         class="btn-outline"),
            uiOutput("publish_all_status_ui")
          )
        )
      ),

      # ══ CONSTRUCTION ═══════════════════════════════════════════════════════
      tabPanel("Construction",
        div(class="panel-block",
          div(class="badge-tag","Questionnaire & sections"),
          fluidRow(
            column(5, selectInput("builder_questionnaire","Questionnaire actif",choices=c("Sélectionner..."=0))),
            column(4, textInput("builder_new_section","Nom de la nouvelle section",placeholder="Ex : Informations générales")),
            column(3, br(), actionButton("btn_add_section","+ Ajouter section",class="btn-primary",style="width:100%;"))
          )
        ),
        div(class="panel-block",
          div(class="badge-tag","Nouvelle question"),
          fluidRow(
            column(4, selectInput("builder_section_target","Section cible",choices=c("Sélectionner..."=0))),
            column(4, selectInput("builder_question_type","Type",choices=QUESTION_TYPES,selected="text")),
            column(4, checkboxInput("builder_required","Question obligatoire",value=FALSE))
          ),
          textAreaInput("builder_question_text","Libellé",rows=2,placeholder="Ex : Quel est votre niveau de satisfaction ?"),
          textAreaInput("builder_question_options","Options de réponse (une par ligne)",rows=3),
          actionButton("btn_add_question","Ajouter la question",class="btn-success")
        ),
        uiOutput("builder_structure")
      ),

      # ══ REMPLIR ════════════════════════════════════════════════════════════
      tabPanel("Remplir",
        div(class="panel-block",
          fluidRow(
            column(6, selectInput("select_questionnaire_form","Questionnaire",choices=c("Sélectionner..."=0))),
            column(6, uiOutput("form_header_info"))
          )
        ),
        uiOutput("formulaire_questionnaire"),
        div(class="panel-block",
          actionButton("btn_soumettre","✔ Soumettre la réponse",class="btn-success btn-lg"))
      ),

      # ══ RÉPONSES ═══════════════════════════════════════════════════════════
      tabPanel("Réponses",
        div(class="panel-block",
          fluidRow(
            column(5, selectInput("select_questionnaire_reponses","Questionnaire",choices=c("Sélectionner..."=0))),
            column(4, dateRangeInput("date_range_reponses","Période",start=Sys.Date()-365,end=Sys.Date())),
            column(3, br(), downloadButton("download_reponses_excel","⬇ Excel",class="btn-primary"))
          )
        ),
        div(class="panel-block",
          div(class="badge-tag","Réponses collectées"),
          DTOutput("table_reponses"),
          br(),
          div(class="action-row",
            actionButton("btn_voir_reponse",     "👁  Voir",      class="btn-info"),
            actionButton("btn_modifier_reponse", "✏  Modifier",  class="btn-warning"),
            actionButton("btn_supprimer_reponse","🗑 Supprimer", class="btn-danger")
          )
        )
      ),

      # ══ ANALYTICS ══════════════════════════════════════════════════════════
      tabPanel("Analytics",
        div(class="panel-block",
          div(class="badge-tag","Source de données interne"),
          selectInput("select_questionnaire_analytics","Questionnaire",
            choices=c("Sélectionner..."=0), width="50%")
        ),
        analytics_panel_ui("")
      ),

      # ══ IMPORT ═════════════════════════════════════════════════════════════
      tabPanel("Import",

        # ── Bloc Panier Apps Script ───────────────────────────────────────────
        div(class="panel-block", style="margin-bottom:16px;",
          div(class="badge-tag", style="background:#0D6EFD;color:#fff;", "📦 Panier Apps Script"),
          fluidRow(
            column(8,
              p(class="hint-text", style="margin-bottom:8px;",
                "Importez les réponses envoyées par les agents via le panier Google Sheet.",
                "Fonctionne sur tout réseau (WiFi, 4G) sans connexion au même réseau."),
              uiOutput("panier_status_ui")
            ),
            column(4, style="text-align:right;",
              actionButton("btn_panier_import", "📦 Importer le panier",
                           class="btn-primary", style="margin-bottom:8px;width:100%;"),
              actionButton("btn_panier_create", "✨ Créer automatiquement",
                           class="btn-success", style="margin-bottom:8px;width:100%;"),
              actionButton("btn_panier_config", "⚙ URL manuelle",
                           class="btn-secondary btn-sm", style="width:100%;"),
              br(), br(),
              uiOutput("panier_import_result_ui")
            )
          )
        ),

        # ── Bloc sync Drive → Desktop ─────────────────────────────────────────
        div(class="panel-block", style="margin-bottom:16px;",
          div(class="badge-tag","Synchronisation Google Drive"),
          fluidRow(
            column(8,
              p(class="hint-text", style="margin-bottom:8px;",
                "Importez directement les réponses collectées sur mobile depuis la Google Sheet ",
                tags$code("Lestrade_Forms_Reponses"), "."),
              uiOutput("drive_sync_status_ui")
            ),
            column(4, style="text-align:right;",
              actionButton("btn_import_from_drive", "☁ Importer depuis Drive",
                           class="btn-info", style="margin-top:4px;"),
              br(), br(),
              uiOutput("drive_import_result_ui")
            )
          )
        ),

        # ── Récupérer questionnaire + réponses via UID du QR code ────────────
        div(class="panel-block", style="margin-bottom:16px;",
          div(class="badge-tag","Synchronisation Desktop → Desktop"),
          p(class="hint-text",
            "Scannez ou copiez l'identifiant affiché sur le QR code d'un autre Desktop.",
            "Le questionnaire et toutes ses réponses Drive seront importés ici."),
          fluidRow(
            column(7,
              textInput("input_uid_sync", label=NULL,
                        placeholder="LEST-0001-A3F2",
                        width="100%")
            ),
            column(5,
              actionButton("btn_sync_by_uid", "☁  Récupérer depuis Drive",
                           class="btn-info btn-lg", style="width:100%;"),
            )
          ),
          uiOutput("uid_sync_result_ui")
        ),

        # Barre d'action rapide — toujours visible en haut
        div(class="import-topbar",
          div(class="import-topbar-left",
            tags$span(class="import-topbar-title","Import de fichier local"),
            conditionalPanel("output.import_file_loaded == true",
              tags$span(class="import-topbar-badge","✓ Fichier prêt")
            )
          ),
          conditionalPanel("output.import_file_loaded == true",
            actionButton("btn_charger_analyse","📥 Charger pour analyse",
              class="btn-success", style="margin-left:auto;")
          )
        ),

        div(class="panel-block",
          div(class="badge-tag","Import de données externes"),
          h3(style="margin-bottom:6px;","Importer un fichier d'enquête"),
          p(class="hint-text","Google Forms, KoboToolbox, CSV ou Excel. La détection des types de colonnes est automatique."),
          tags$hr(style="border-color:var(--surface-2);margin:14px 0;"),

          div(class="import-step",style="margin-bottom:18px;",
            div(class="step-num","1"),
            div(style="width:100%;",
              h4("Sélectionner le fichier"),
              fluidRow(
                column(5, fileInput("import_file","Fichier (.xlsx, .xls, .csv)",
                  accept=c(".xlsx",".xls",".csv"))),
                column(4, uiOutput("import_sheet_ui")),
                column(3, br(), checkboxInput("import_header","1ère ligne = en-têtes",value=TRUE))
              ),
              fluidRow(
                column(3, div(class="kpi-card",div(class="kpi-value",textOutput("import_row_count")),div(class="kpi-label","Lignes"))),
                column(3, div(class="kpi-card",div(class="kpi-value",textOutput("import_col_count")),div(class="kpi-label","Colonnes")))
              )
            )
          )
        ),

        conditionalPanel("output.import_file_loaded == true",
          div(class="panel-block",
            div(class="import-step",
              div(class="step-num","2"),
              div(style="width:100%;",
                h4("Aperçu des données"),
                p(class="hint-text","50 premières lignes."),
                DTOutput("import_preview")
              )
            )
          ),
          div(class="panel-block",
            div(class="import-step",
              div(class="step-num","2b"),
              div(style="width:100%;",
                h4("Détection automatique des colonnes"),
                p(class="hint-text","Types détectés, modalités et rôle analytique suggéré pour chaque colonne."),
                DTOutput("import_detection_table")
              )
            )
          ),
          div(class="panel-block",
            div(class="import-step",
              div(class="step-num","3"),
              div(
                h4("Charger pour analyse"),
                p(class="hint-text","Le fichier sera conservé en mémoire pour cette session. Accédez à l'onglet ",
                  tags$strong("Analyse externe")," pour exploiter les données."),
                actionButton("btn_charger_analyse2","📥 Charger pour analyse",class="btn-success btn-lg")
              )
            )
          )
        )
      ),

      # ══ ANALYSE EXTERNE ════════════════════════════════════════════════════
      tabPanel("Analyse externe",
        div(class="panel-block",
          div(class="badge-tag badge-navy","Fichier chargé en session"),
          uiOutput("ext_status_ui")
        ),
        analytics_panel_ui("ext_")
      )

    ) # fin tabsetPanel
  ) # fin main-content
)
