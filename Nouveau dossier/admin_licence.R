# ============================================================================
# admin_licence.R — Interface admin gestion des licences
# Lancer avec : shiny::runApp("admin_licence.R")
# Accès réservé au coordinateur / administrateur
# ============================================================================

library(shiny)
library(shinyjs)
library(DT)
library(jsonlite)
library(httr)

# Charger les fonctions licence
source(file.path(dirname(rstudioapi::getSourceEditorContext()$path), "global_licence.R"),
       local = TRUE)

# ── UI ────────────────────────────────────────────────────────────────────────
ui_admin <- fluidPage(
  useShinyjs(),
  title = "Lestrade — Admin Licences",
  tags$head(tags$style(HTML("
    body { font-family: 'IBM Plex Sans', sans-serif; background: #F5F7FA; padding: 24px; }
    .card { background: #fff; border: 1px solid #DDE3EC; border-radius: 12px; padding: 20px 24px; margin-bottom: 20px; box-shadow: 0 2px 8px rgba(0,0,0,.06); }
    h2 { color: #0D1F35; font-size: 1.3rem; margin-bottom: 4px; }
    .badge-premium { background: #d4edda; color: #155724; border-radius: 20px; padding: 3px 12px; font-size: 12px; font-weight: 600; }
    .badge-trial   { background: #fff3cd; color: #856404; border-radius: 20px; padding: 3px 12px; font-size: 12px; font-weight: 600; }
    .badge-expire  { background: #f8d7da; color: #721c24; border-radius: 20px; padding: 3px 12px; font-size: 12px; font-weight: 600; }
  "))),

  div(style = "max-width:960px; margin:0 auto;",
    h1(style = "color:#0D1F35; margin-bottom:4px;", "🔑 Admin — Gestion des licences"),
    p(style = "color:#8896A7; margin-bottom:20px;", "Interface réservée à l'administrateur Lestrade Forms"),

    # ── Configuration panier ──────────────────────────────────────────────────
    div(class = "card",
      h2("Configuration"),
      fluidRow(
        column(8,
          textInput("admin_panier_url", "URL Apps Script (panier)",
                    value = get_panier_url() %||% "",
                    placeholder = "https://script.google.com/macros/s/.../exec",
                    width = "100%")
        ),
        column(4,
          br(),
          actionButton("btn_admin_save_url", "Enregistrer l'URL", class = "btn btn-primary"),
          actionButton("btn_admin_test_url", "Tester", class = "btn btn-default", style = "margin-left:6px;")
        )
      ),
      uiOutput("admin_url_result")
    ),

    # ── Générer une clé ───────────────────────────────────────────────────────
    div(class = "card",
      h2("Générer et attribuer une clé"),
      fluidRow(
        column(6,
          textInput("admin_email_cle", "Email de l'utilisateur",
                    placeholder = "utilisateur@exemple.com", width = "100%")
        ),
        column(3,
          br(),
          actionButton("btn_admin_gen_cle", "🔑 Générer la clé", class = "btn btn-warning btn-block")
        ),
        column(3,
          br(),
          actionButton("btn_admin_assign_cle", "📤 Attribuer au serveur", class = "btn btn-success btn-block")
        )
      ),
      uiOutput("admin_cle_result")
    ),

    # ── Liste des licences ────────────────────────────────────────────────────
    div(class = "card",
      div(style = "display:flex; align-items:center; justify-content:space-between; margin-bottom:14px;",
        h2("Licences enregistrées"),
        actionButton("btn_admin_refresh", "↻ Actualiser", class = "btn btn-default btn-sm")
      ),
      DTOutput("admin_licences_table")
    )
  )
)

# ── Server ────────────────────────────────────────────────────────────────────
server_admin <- function(input, output, session) {

  rv <- reactiveValues(
    cle_generee = NULL,
    licences    = data.frame()
  )

  # Charger les licences au démarrage
  observe({
    rv$licences <- charger_licences_sheet()
  })

  # Sauvegarder URL panier
  observeEvent(input$btn_admin_save_url, {
    url <- trimws(input$admin_panier_url)
    save_panier_url(url)
    showNotification("URL enregistrée.", type = "message", duration = 3)
  })

  # Tester l'URL
  output$admin_url_result <- renderUI({ NULL })
  observeEvent(input$btn_admin_test_url, {
    url <- trimws(input$admin_panier_url)
    result <- tryCatch({
      resp <- GET(paste0(url, "?action=info"), timeout(10))
      parsed <- content(resp, as = "parsed", type = "application/json")
      if (!is.null(parsed$status) && parsed$status == "ok") {
        list(ok = TRUE, msg = paste0("✓ Connecté — v", parsed$version,
             " | ", parsed$nb_licences, " licence(s)"))
      } else {
        list(ok = FALSE, msg = "Réponse inattendue du serveur")
      }
    }, error = function(e) list(ok = FALSE, msg = conditionMessage(e)))

    output$admin_url_result <- renderUI({
      cls <- if (result$ok) "alert alert-success" else "alert alert-danger"
      div(class = cls, style = "margin-top:10px; font-size:13px;", result$msg)
    })
  })

  # Générer une clé
  output$admin_cle_result <- renderUI({ NULL })
  observeEvent(input$btn_admin_gen_cle, {
    email <- trimws(input$admin_email_cle)
    if (!grepl("^[^@]+@[^@]+\\.[^@]+$", email)) {
      output$admin_cle_result <- renderUI({
        div(class = "alert alert-danger", style = "margin-top:10px;", "Email invalide.")
      })
      return()
    }
    cle <- generer_cle_licence(email)
    rv$cle_generee <- cle
    output$admin_cle_result <- renderUI({
      div(class = "alert alert-info", style = "margin-top:10px;",
        tags$strong("Clé générée :"), br(),
        tags$code(style = "font-size:15px; letter-spacing:2px;", cle),
        br(), br(),
        tags$small(style = "color:#555;",
          "Cliquez 'Attribuer au serveur' pour l'enregistrer dans le Sheet, ",
          "puis communiquez cette clé à l'utilisateur (email, WhatsApp, etc.).")
      )
    })
  })

  # Attribuer la clé au serveur
  observeEvent(input$btn_admin_assign_cle, {
    email <- trimws(input$admin_email_cle)
    cle   <- rv$cle_generee
    url   <- trimws(input$admin_panier_url)

    if (is.null(cle) || cle == "") {
      showNotification("Générez d'abord une clé.", type = "warning"); return()
    }
    if (!grepl("^[^@]+@[^@]+\\.[^@]+$", email)) {
      showNotification("Email invalide.", type = "error"); return()
    }
    if (!nzchar(url)) {
      showNotification("URL panier non configurée.", type = "error"); return()
    }

    result <- licence_assign_key(email, cle, url)
    if (!is.null(result$status) && result$status == "ok") {
      showNotification(paste0("✓ Clé attribuée à ", email), type = "message", duration = 5)
      rv$cle_generee <- NULL
      output$admin_cle_result <- renderUI({
        div(class = "alert alert-success", style = "margin-top:10px;",
          tags$strong("✓ Clé attribuée avec succès !"), br(),
          "Email : ", tags$code(email), br(),
          "Clé : ", tags$code(cle)
        )
      })
      rv$licences <- charger_licences_sheet()
    } else {
      showNotification(paste0("Erreur : ", result$message %||% "Inconnu"), type = "error")
    }
  })

  # Actualiser la liste
  observeEvent(input$btn_admin_refresh, {
    rv$licences <- charger_licences_sheet()
  })

  # Tableau des licences
  output$admin_licences_table <- renderDT({
    df <- rv$licences
    if (nrow(df) == 0) return(data.frame(Message = "Aucune licence enregistrée"))
    datatable(df, rownames = FALSE, options = list(pageLength = 20, dom = "ftp"),
              colnames = c("Email", "Date inscription", "Statut", "Clé", "Date activation", "Jours trial"))
  })
}

# ── Fonction utilitaire : lire les licences depuis le Sheet ───────────────────
charger_licences_sheet <- function() {
  url <- get_panier_url()
  if (is.null(url) || !nzchar(url)) return(data.frame())
  tryCatch({
    resp   <- GET(paste0(url, "?action=list_licences"), timeout(10))
    parsed <- content(resp, as = "parsed", type = "application/json")
    if (!is.null(parsed$licences) && length(parsed$licences) > 0) {
      do.call(rbind, lapply(parsed$licences, function(r) {
        data.frame(
          email            = r$email %||% "",
          date_inscription = r$date_inscription %||% "",
          statut           = r$statut %||% "",
          cle              = r$cle %||% "",
          date_activation  = r$date_activation %||% "",
          jours_trial      = r$jours_trial %||% 30,
          stringsAsFactors = FALSE
        )
      }))
    } else data.frame()
  }, error = function(e) data.frame())
}

# ── Lancer l'app ──────────────────────────────────────────────────────────────
shinyApp(ui = ui_admin, server = server_admin)
