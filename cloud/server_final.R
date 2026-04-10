# ============================================================================
# server_final.R  - v2
# Architecture : setup_analytics_outputs(pfx) couvre les deux onglets
# ============================================================================

library(shiny); library(shinyjs); library(DT)
library(jsonlite); library(dplyr); library(RSQLite); library(DBI)
library(readxl); library(readr); library(stringi)

source("global_licence.R", local = TRUE)

server <- function(input, output, session) {

  # Cloud : pas d'IP locale ni d'API Plumber
  .local_ip <- "cloud"

  rv <- reactiveValues(
    refresh_quests   = 0L,
    refresh_reponses = 0L,
    selected_quest   = NULL,
    selected_rep_id  = NULL,
    ext_df           = NULL,
    ext_filename     = NULL,
    qr_tmp_path      = NULL,
    qr_uid           = NULL,
    qr_quest_id      = NULL,
    drive_connected  = FALSE,
    panier_sheet_url = NULL,
    # Licence
    licence_statut   = "inconnu",  # "premium"|"trial"|"expire"|"inconnu"
    licence_email    = "",
    licence_jours    = 0L,
    licence_message  = ""
  )

  # ── Vérification licence au démarrage ────────────────────────────────────
  observe({
    panier_url <- get_panier_url()
    lic <- verifier_licence(panier_url)
    rv$licence_statut  <- lic$statut
    rv$licence_email   <- lic$email %||% ""
    rv$licence_jours   <- as.integer(lic$jours_restants %||% 0)
    rv$licence_message <- lic$message %||% ""

    # Si pas encore enregistré → modal saisie email
    if (lic$statut == "inconnu") {
      showModal(modalDialog(
        title = "Bienvenue dans Lestrade Forms",
        size  = "s", easyClose = FALSE,
        div(
          div(class = "alert alert-info", style = "font-size:13px;",
              "Saisissez votre adresse email pour démarrer votre trial gratuit de ",
              tags$strong(paste0(TRIAL_DAYS, " jours")), "."),
          textInput("licence_email_input", "Adresse email",
                    placeholder = "vous@exemple.com", width = "100%"),
          uiOutput("licence_register_result")
        ),
        footer = tagList(
          actionButton("btn_licence_register", "Démarrer le trial",
                       class = "btn-primary", style = "width:100%;")
        )
      ))
    }

    # Si expiré → modal activation clé
    if (lic$statut == "expire") {
      showModal(modalDialog(
        title = "Trial expiré",
        size  = "s", easyClose = FALSE,
        div(
          div(class = "alert alert-danger", style = "font-size:13px;",
              "Votre trial de ", tags$strong(paste0(TRIAL_DAYS, " jours")),
              " est terminé. Activez une licence premium pour continuer."),
          p(class = "hint-text", "Contactez-nous pour obtenir votre clé de licence."),
          textInput("licence_cle_input", "Clé de licence",
                    placeholder = "LEST-XXXX-XXXX-XXXX-XXXX", width = "100%"),
          uiOutput("licence_activate_result")
        ),
        footer = tagList(
          actionButton("btn_licence_activate", "Activer la licence",
                       class = "btn-warning", style = "width:100%;")
        )
      ))
    }
  })

  # ── Enregistrement email ─────────────────────────────────────────────────
  output$licence_register_result <- renderUI({ NULL })

  observeEvent(input$btn_licence_register, {
    email <- trimws(input$licence_email_input)
    if (!grepl("^[^@]+@[^@]+\\.[^@]+$", email)) {
      output$licence_register_result <- renderUI({
        div(class = "alert alert-danger", style = "font-size:12px; margin-top:8px;",
            "Email invalide. Vérifiez le format.")
      })
      return()
    }
    panier_url <- get_panier_url()
    result     <- enregistrer_licence(email, panier_url)
    if (isTRUE(result$ok)) {
      rv$licence_statut  <- result$statut
      rv$licence_email   <- email
      rv$licence_jours   <- as.integer(result$jours_restants %||% TRIAL_DAYS)
      rv$licence_message <- result$message
      removeModal()
      showNotification(paste0("✓ ", result$message), type = "message", duration = 6)
    } else {
      output$licence_register_result <- renderUI({
        div(class = "alert alert-danger", style = "font-size:12px; margin-top:8px;",
            result$message)
      })
    }
  })

  # ── Activation clé ───────────────────────────────────────────────────────
  output$licence_activate_result <- renderUI({ NULL })

  observeEvent(input$btn_licence_activate, {
    cle        <- trimws(input$licence_cle_input)
    panier_url <- get_panier_url()
    result     <- activer_cle_licence(cle, panier_url)
    if (isTRUE(result$ok)) {
      rv$licence_statut  <- "premium"
      rv$licence_jours   <- 9999L
      rv$licence_message <- result$message
      removeModal()
      showNotification("✓ Licence premium activée !", type = "message", duration = 5)
    } else {
      output$licence_activate_result <- renderUI({
        div(class = "alert alert-danger", style = "font-size:12px; margin-top:8px;",
            result$message)
      })
    }
  })

  # ── Badge licence dans le header ─────────────────────────────────────────
  output$header_licence_badge <- renderUI({
    statut <- rv$licence_statut
    jours  <- rv$licence_jours
    label  <- switch(statut,
      premium = "✓ Premium",
      trial   = paste0("⏳ Trial — ", jours, "j"),
      expire  = "⚠ Expiré",
      "◌ Licence"
    )
    cls <- switch(statut, premium = "premium", trial = "trial", expire = "expire", "trial")
    tags$button(
      class   = paste("licence-badge", cls),
      onclick = "Shiny.setInputValue('btn_licence_modal', Math.random())",
      label
    )
  })

  # ── Bannière trial / expiration ───────────────────────────────────────────
  output$licence_banner <- renderUI({
    statut <- rv$licence_statut
    jours  <- rv$licence_jours
    if (statut == "premium" || statut == "inconnu") return(NULL)

    if (statut == "trial" && jours > 7) return(NULL)  # pas de bannière si > 7j restants

    texte <- if (statut == "expire") {
      "⚠ Trial expiré — activez une licence premium pour continuer à utiliser Lestrade Forms."
    } else {
      paste0("⏳ Il vous reste ", jours, " jour(s) de trial. Activez une licence pour continuer sans interruption.")
    }

    # Pousser le contenu vers le bas
    session$sendCustomMessage("addBodyClass", "has-licence-banner")

    div(class = paste("licence-banner", statut),
      span(texte),
      tags$button(
        class   = "licence-banner-btn",
        onclick = "Shiny.setInputValue('btn_licence_modal', Math.random())",
        if (statut == "expire") "Activer maintenant" else "Activer la licence"
      )
    )
  })

  # ── Modal depuis badge/bannière ───────────────────────────────────────────
  observeEvent(input$btn_licence_modal, {
    statut <- rv$licence_statut
    showModal(modalDialog(
      title = "Licence Lestrade Forms",
      size  = "s", easyClose = TRUE,
      div(
        if (statut == "premium") {
          div(class = "alert alert-success",
              tags$strong("✓ Licence premium active"),
              br(), tags$small(rv$licence_email))
        } else if (statut == "trial") {
          div(
            div(class = "alert alert-warning",
                tags$strong(paste0("⏳ Trial — ", rv$licence_jours, " jour(s) restant(s)")),
                br(), tags$small(rv$licence_email)),
            hr(),
            p(class = "hint-text", "Entrez votre clé pour passer en version premium :"),
            textInput("licence_cle_input2", "Clé de licence",
                      placeholder = "LEST-XXXX-XXXX-XXXX-XXXX", width = "100%"),
            uiOutput("licence_activate_result2")
          )
        } else {
          div(
            div(class = "alert alert-danger", "⚠ Trial expiré"),
            p(class = "hint-text", "Entrez votre clé pour activer la version premium :"),
            textInput("licence_cle_input2", "Clé de licence",
                      placeholder = "LEST-XXXX-XXXX-XXXX-XXXX", width = "100%"),
            uiOutput("licence_activate_result2")
          )
        }
      ),
      footer = if (statut != "premium") tagList(
        modalButton("Fermer"),
        actionButton("btn_licence_activate2", "Activer", class = "btn-warning")
      ) else modalButton("Fermer")
    ))
  })

  output$licence_activate_result2 <- renderUI({ NULL })

  observeEvent(input$btn_licence_activate2, {
    cle        <- trimws(input$licence_cle_input2 %||% "")
    panier_url <- get_panier_url()
    result     <- activer_cle_licence(cle, panier_url)
    if (isTRUE(result$ok)) {
      rv$licence_statut  <- "premium"
      rv$licence_jours   <- 9999L
      removeModal()
      showNotification("✓ Licence premium activée !", type = "message", duration = 5)
    } else {
      output$licence_activate_result2 <- renderUI({
        div(class = "alert alert-danger", style = "font-size:12px; margin-top:8px;",
            result$message)
      })
    }
  })

  # ── Connexion Google Drive Desktop ─────────────────────────────────────────
  DESKTOP_DRIVE_CACHE <- file.path(tools::R_user_dir("LestradeApp", "data"), ".secrets_desktop")
  dir.create(DESKTOP_DRIVE_CACHE, recursive = TRUE, showWarnings = FALSE)

  desktop_drive_connect <- function() {
    if (!requireNamespace("googledrive", quietly=TRUE))
      stop("Installez le package 'googledrive' : install.packages('googledrive')")
    # Désactiver OOB globalement — bloqué par Google depuis 2022
    options(
      gargle_oauth_cache = DESKTOP_DRIVE_CACHE,
      gargle_oob_default = FALSE
    )
    googledrive::drive_auth(
      cache  = DESKTOP_DRIVE_CACHE,
      scopes = c(
        "https://www.googleapis.com/auth/drive",
        "https://www.googleapis.com/auth/spreadsheets"
      )
    )
    TRUE
  }

  desktop_drive_is_ok <- function() {
    # Vérifier uniquement la présence du fichier token — pas d'appel googledrive
    # (évite le prompt interactif dans la console RStudio)
    tryCatch({
      files <- list.files(DESKTOP_DRIVE_CACHE, pattern = "\\.rds$|\\.json$|\\.cache$", full.names = TRUE)
      if (length(files) == 0) files <- list.files(DESKTOP_DRIVE_CACHE, full.names = TRUE)
      length(files) > 0
    }, error = function(e) FALSE)
  }

  # Vérifier au démarrage si un token existe déjà
  observe({
    rv$drive_connected <- tryCatch(desktop_drive_is_ok(), error = function(e) FALSE)
  })

  # ── Badge Google Drive dans l'en-tête ──────────────────────────────────────
  output$header_drive_badge <- renderUI({
    if (rv$drive_connected) {
      mail <- tryCatch({
        u <- googledrive::drive_user()
        u$emailAddress %||% u$displayName %||% "Connecté"
      }, error = function(e) "Connecté")
      tags$button(class="drive-badge connected",
        onclick="Shiny.setInputValue('btn_header_drive', Math.random(), {priority:'event'})",
        div(class="drive-dot on"), mail)
    } else {
      tags$button(class="drive-badge disconnected",
        onclick="Shiny.setInputValue('btn_header_drive', Math.random(), {priority:'event'})",
        div(class="drive-dot off"), "Connecter Google Drive")
    }
  })

  observeEvent(input$btn_header_drive, {
    if (!rv$drive_connected) {
      ok <- tryCatch({ desktop_drive_connect(); rv$drive_connected <- desktop_drive_is_ok(); TRUE },
                     error = function(e) { showNotification(e$message, type="error"); FALSE })
      if (ok) showNotification("✓ Google Drive connecté !", type="message")
    } else {
      showModal(modalDialog(
        title = "Google Drive",
        tryCatch({
          u <- googledrive::drive_user()
          tagList(p(tags$b("Email :"), u$emailAddress %||% ""), p(style="color:grey;font-size:12px;","Connecté"))
        }, error = function(e) p("Connecté")),
        footer = tagList(modalButton("Fermer"),
          actionButton("btn_drive_disconnect","Se déconnecter", class="btn-outline")),
        easyClose = TRUE
      ))
    }
  })

  observeEvent(input$btn_drive_disconnect, {
    tryCatch({ file.remove(list.files(DESKTOP_DRIVE_CACHE, full.names=TRUE)); rv$drive_connected <- FALSE }, error=function(e) NULL)
    removeModal()
    showNotification("Déconnecté de Google Drive.", type="warning")
  })

  # Bouton connecter Drive (depuis le modal QR)
  observeEvent(input$btn_desktop_connect_drive, {
    result <- tryCatch({
      desktop_drive_connect()
      rv$drive_connected <- desktop_drive_is_ok()
      TRUE
    }, error=function(e) {
      showNotification(paste("Erreur connexion Drive:", e$message), type="error", duration=8)
      FALSE
    })
    if (result) {
      showNotification("✓ Google Drive connecté !", type="message")
      # Relancer le modal QR pour mettre à jour le statut
      shinyjs::runjs("Shiny.setInputValue('btn_share_qr', Math.random(), {priority:'event'})")
    }
  })

  # ── helpers locaux ──────────────────────────────────────────────────────────
  parse_options <- function(txt) {
    if (is.null(txt) || trimws(txt)=="") return(character(0))
    p <- trimws(unlist(strsplit(txt,"\n|,")))
    unique(p[p!=""])
  }

  q_type_label <- function(tc) {
    idx <- match(tc, unname(QUESTION_TYPES))
    if (is.na(idx)) tc else names(QUESTION_TYPES)[idx]
  }

  invalid_id <- function(x) is.null(x)||length(x)==0||is.na(x)||x==0

  render_question_input <- function(q, input_id, value=NULL, edit_mode=FALSE) {
    lbl <- if (as.integer(q$obligatoire)==1 && !edit_mode)
      HTML(paste0(q$texte,' <span class="required-mark">*</span>')) else q$texte
    opts <- tryCatch(fromJSON(q$options %||% "{}"), error=function(e) character(0))
    switch(q$type,
      text      = textInput(input_id, lbl, value=value%||%""),
      textarea  = textAreaInput(input_id, lbl, value=value%||%"", rows=4),
      radio     = radioButtons(input_id, lbl, choices=opts, selected=value%||%character(0)),
      checkbox  = checkboxGroupInput(input_id, lbl, choices=opts, selected=value%||%character(0)),
      dropdown  = selectInput(input_id, lbl, choices=c("Sélectionner..."="",opts), selected=value%||%""),
      likert    = radioButtons(input_id, lbl, inline=TRUE, selected=value%||%character(0),
                    choices=c("Pas d'accord","Plutot pas","Neutre","Plutot d'accord","Tout a fait")),
      email     = textInput(input_id, lbl, value=value%||%"", placeholder="nom@exemple.org"),
      phone     = textInput(input_id, lbl, value=value%||%"", placeholder="+221770000000"),
      date      = dateInput(input_id, lbl,
                    value=if(!is.null(value)&&!is_empty_response_value(value)) as.Date(value) else NULL),
      textInput(input_id, lbl, value=value%||%"")
    )
  }

  # ── REACTIVES principaux ───────────────────────────────────────────────────
  questionnaires <- reactive({
    rv$refresh_quests; get_all_questionnaires()
  })

  builder_full <- reactive({
    rv$refresh_quests  # dépendance explicite pour forcer le recalcul
    req(!invalid_id(input$builder_questionnaire))
    get_questionnaire_full(as.numeric(input$builder_questionnaire))
  })

  response_bundle <- reactive({
    rv$refresh_reponses
    qid <- as.numeric(input$select_questionnaire_reponses)
    if (invalid_id(qid)) return(list(raw=data.frame(), wide=data.frame()))
    raw  <- get_reponses_by_questionnaire(qid)
    if (nrow(raw)==0) return(list(raw=raw, wide=data.frame()))
    req(!is.null(input$date_range_reponses))
    d_start <- as.POSIXct(paste(input$date_range_reponses[1],"00:00:00"))
    d_end   <- as.POSIXct(paste(input$date_range_reponses[2],"23:59:59"))
    raw$horodateur_dt <- as.POSIXct(raw$horodateur)
    raw <- raw[raw$horodateur_dt>=d_start & raw$horodateur_dt<=d_end,,drop=FALSE]
    wide <- if (nrow(raw)>0) {
      fw <- get_reponses_wide(qid)
      fw[fw$reponse_id %in% raw$id,,drop=FALSE]
    } else data.frame()
    list(raw=raw, wide=wide)
  })

  # Bundle INTERNE
  analytics_bundle <- reactive({
    qid <- as.numeric(input$select_questionnaire_analytics)
    if (invalid_id(qid)) return(list(data=data.frame(), meta=data.frame()))
    questions <- get_all_questions_by_questionnaire(qid)
    reponses  <- get_reponses_by_questionnaire(qid)
    if (nrow(questions)==0||nrow(reponses)==0) return(list(data=data.frame(), meta=data.frame()))
    df   <- parse_reponses_to_wide(qid)
    df$horodateur <- as.character(df$horodateur)
    df$date <- suppressWarnings(as.Date(df$horodateur))
    meta <- questions
    meta$col_id <- paste0("q_", meta$id)
    meta$label  <- paste0(meta$section_nom," / ",meta$texte)
    meta <- finalize_internal_meta(df, meta)
    prepare_analytics_bundle(df, meta)
  })

  # Bundle EXTERNE (session)
  ext_bundle <- reactive({
    df <- rv$ext_df
    if (is.null(df)||nrow(df)==0) return(list(data=data.frame(), meta=data.frame()))
    build_ext_bundle_auto(df)
  })

  # ── Mise à jour des listes de questionnaires ───────────────────────────────
  observe({
    q <- questionnaires()
    ch <- if (nrow(q)>0) setNames(as.list(q$id),q$nom) else list()
    ch0 <- c("Sélectionner..."=0, ch)
    for (id in c("builder_questionnaire","select_questionnaire_form",
                  "select_questionnaire_reponses","select_questionnaire_analytics"))
      updateSelectInput(session, id, choices=ch0, selected=isolate(input[[id]]))
  })

  observe({
    full <- tryCatch(builder_full(), error=function(e) NULL)
    sc <- if (!is.null(full)&&nrow(full$sections)>0)
      setNames(as.list(full$sections$id), full$sections$nom) else list()
    updateSelectInput(session,"builder_section_target",
                      choices  = c("Sélectionner..."=0, sc),
                      selected = isolate(input$builder_section_target))
  })

  # ── MÉTRIQUES DASHBOARD (landing + gestion) ────────────────────────────────
  # landing page (hero stats)
  output$metric_questionnaires <- renderText(nrow(questionnaires()))
  output$metric_sections <- renderText({
    q <- questionnaires(); if(nrow(q)==0) return(0)
    sum(vapply(q$id, count_sections_by_questionnaire, numeric(1)))
  })
  output$metric_questions <- renderText({
    q <- questionnaires(); if(nrow(q)==0) return(0)
    sum(vapply(q$id, count_questions_by_questionnaire, numeric(1)))
  })
  output$metric_reponses <- renderText({
    q <- questionnaires(); if(nrow(q)==0) return(0)
    sum(vapply(q$id, function(id) nrow(get_reponses_by_questionnaire(id)), numeric(1)))
  })

  # Gestion tab dash metrics
  output$dash_n_quests    <- renderText(nrow(questionnaires()))
  output$dash_n_sections  <- renderText({ q<-questionnaires(); if(nrow(q)==0) return(0); sum(vapply(q$id,count_sections_by_questionnaire,numeric(1))) })
  output$dash_n_questions <- renderText({ q<-questionnaires(); if(nrow(q)==0) return(0); sum(vapply(q$id,count_questions_by_questionnaire,numeric(1))) })
  output$dash_n_reponses  <- renderText({ q<-questionnaires(); if(nrow(q)==0) return(0); sum(vapply(q$id,function(id) nrow(get_reponses_by_questionnaire(id)),numeric(1))) })

  # ── GESTION ────────────────────────────────────────────────────────────────
  output$table_questionnaires <- renderDT({
    q <- questionnaires()
    if (nrow(q)==0) return(datatable(data.frame(Message="Aucun questionnaire"),options=list(dom="t"),rownames=FALSE))
    q$sections  <- vapply(q$id, count_sections_by_questionnaire, numeric(1))
    q$questions <- vapply(q$id, count_questions_by_questionnaire, numeric(1))
    q$reponses  <- vapply(q$id, function(id) nrow(get_reponses_by_questionnaire(id)), numeric(1))
    q$date_creation <- format(as.POSIXct(q$date_creation),"%d/%m/%Y %H:%M")
    # Bouton QR par ligne
    q$Partager <- sprintf(
      '<button class="btn-qr-row" onclick="Shiny.setInputValue(\'btn_share_qr_row\',%d,{priority:\'event\'})">📱 QR</button>',
      q$id)
    d <- q[,c("id","nom","description","sections","questions","reponses","date_creation","Partager")]
    colnames(d) <- c("ID","Nom","Description","Sections","Questions","Réponses","Création","Partager")
    datatable(d, selection="single", rownames=FALSE, escape=FALSE,
      options=list(pageLength=10, dom="ftp",
        columnDefs=list(
          list(targets=0, visible=FALSE),
          list(targets=7, orderable=FALSE, width="70px")
        )))
  }, server=FALSE)

  observeEvent(input$table_questionnaires_rows_selected, {
    q <- questionnaires(); idx <- input$table_questionnaires_rows_selected
    if (length(idx)>0&&idx<=nrow(q)) rv$selected_quest <- q$id[idx]
  })

  # Bouton QR dans la table (par ligne) → sélectionne puis ouvre le modal
  observeEvent(input$btn_share_qr_row, {
    rv$selected_quest <- as.integer(input$btn_share_qr_row)
    shinyjs::runjs("Shiny.setInputValue('btn_share_qr', Math.random(), {priority:'event'})")
  })

  output$publish_all_status_ui <- renderUI({ NULL })

  observeEvent(input$btn_publish_all_drive, {
    if (!rv$drive_connected) {
      showNotification("Connectez d'abord Google Drive (bouton QR > Connecter Drive).",
                       type="warning", duration=5)
      return()
    }
    quests <- get_all_questionnaires()
    if (nrow(quests) == 0) {
      showNotification("Aucun questionnaire à publier.", type="warning"); return()
    }
    showNotification(
      sprintf("Publication de %d questionnaire(s) sur Drive...", nrow(quests)),
      type="message", duration=4)

    n_ok <- 0L; n_err <- 0L
    for (i in seq_len(nrow(quests))) {
      tryCatch({
        upload_quest_to_drive(quests$id[i])
        n_ok <- n_ok + 1L
      }, error=function(e) { n_err <<- n_err + 1L })
    }
    msg <- sprintf("✓ %d publié(s)", n_ok)
    if (n_err > 0) msg <- paste0(msg, sprintf(" · %d erreur(s)", n_err))
    showNotification(msg, type=if(n_err==0)"message" else "warning", duration=6)
    output$publish_all_status_ui <- renderUI({
      div(style=paste0("font-size:12px;color:", if(n_err==0)"var(--teal)" else "var(--amber)", ";"),
          msg)
    })
  })

  observeEvent(input$btn_refresh_reponses, {
    rv$refresh_reponses <- rv$refresh_reponses + 1L
    showNotification("Réponses actualisées.", type="message", duration=2)
  })

  observeEvent(input$btn_refresh_gestion, {
    rv$refresh_quests <- rv$refresh_quests + 1L
    showNotification("Liste actualisée.", type="message", duration=2)
  })

  # ── QR CODE CONNEXION API — généré automatiquement au démarrage ───────────
  .api_qr_src <- local({
    url <- sprintf("lestrade://%s:8765", .local_ip)
    tmp <- tempfile(fileext = ".png")
    tryCatch({
      png(tmp, width = 200, height = 200, bg = "white")
      plot(qrcode::qr_code(url), col = c("white", "#003366"))
      dev.off()
      knitr::image_uri(tmp)
    }, error = function(e) NULL)
  })

  output$api_qr_ui <- renderUI({
    url <- sprintf("lestrade://%s:8765", .local_ip)
    if (is.null(.api_qr_src)) {
      span(style="color:red;font-size:12px;", "Erreur génération QR — installez le package qrcode")
    } else {
      div(style="display:flex;flex-direction:column;align-items:center;gap:8px;",
        div(style="background:white;padding:8px;border:2px solid #003366;border-radius:8px;",
          tags$img(src = .api_qr_src, width = "150px", height = "150px")
        ),
        span(style="font-size:11px;color:var(--text2);font-family:monospace;", url)
      )
    }
  })

  observeEvent(input$btn_show_api_qr, {
    # Le QR est déjà affiché — ce bouton sert juste à le révéler/masquer
    showNotification(
      sprintf("API active sur http://%s:8765", .local_ip),
      type = "message", duration = 4
    )
  })

  observeEvent(input$btn_creer, {
    nom <- trimws(input$input_nom)
    if (nom=="") { showNotification("Nom obligatoire.",type="error"); return() }
    id <- create_questionnaire(nom, trimws(input$input_desc))
    rv$refresh_quests <- rv$refresh_quests+1L
    rv$selected_quest <- id
    updateTextInput(session,"input_nom",value=""); updateTextInput(session,"input_desc",value="")
    updateSelectInput(session,"builder_questionnaire",selected=id)
    updateTabsetPanel(session,"main_tabs",selected="Construction")
    showNotification("Questionnaire créé.",type="message")
  })

  open_tab <- function(tab, sel_id) {
    if (is.null(rv$selected_quest)) { showNotification("Sélectionne un questionnaire.",type="warning"); return() }
    updateSelectInput(session,sel_id,selected=rv$selected_quest)
    updateTabsetPanel(session,"main_tabs",selected=tab)
  }
  observeEvent(input$btn_open_builder,  open_tab("Construction","builder_questionnaire"))
  observeEvent(input$btn_open_fill,     open_tab("Remplir","select_questionnaire_form"))
  observeEvent(input$btn_open_answers,  open_tab("Réponses","select_questionnaire_reponses"))
  observeEvent(input$btn_open_analytics,open_tab("Analytics","select_questionnaire_analytics"))

  # ── QR CODE — Partage questionnaire ───────────────────────────────────────
  observeEvent(input$btn_share_qr, {
    if (is.null(rv$selected_quest)) {
      showNotification("Sélectionne un questionnaire.", type="warning"); return()
    }
    for (pkg in c("qrcode","digest","base64enc")) {
      if (!requireNamespace(pkg, quietly=TRUE)) {
        showModal(modalDialog(title="Package manquant",
          p(paste("Installez :", pkg)),
          tags$pre(paste0("install.packages('",pkg,"')")),
          easyClose=TRUE, footer=modalButton("Fermer")))
        return()
      }
    }

    qid         <- rv$selected_quest
    panier_url  <- get_panier_url()
    panier_ok   <- !is.null(panier_url)

    # Mode panier si configuré → upload questionnaire + QR avec URL panier
    # Mode WiFi sinon → QR avec IP locale uniquement
    export <- tryCatch({
      if (panier_ok) {
        # Upload le questionnaire complet vers le panier (accessible hors WiFi)
        tryCatch(
          upload_quest_to_panier(qid, panier_url),
          error = function(e) showNotification(
            paste("⚠ Upload panier échoué:", e$message), type = "warning", duration = 6)
        )
        export_quest_to_qr_panier(qid, panier_url)
      } else {
        export_quest_to_qr(qid, server_ip = .local_ip, server_port = 8765)
      }
    }, error = function(e) { showNotification(paste("Erreur:", e$message), type = "error"); NULL })
    if (is.null(export)) return()

    # QR code
    tmp <- tempfile(fileext=".png")
    tryCatch({
      png(tmp, width=300, height=300, bg="white")
      plot(qrcode::qr_code(export$json, ecl="M"))
      dev.off()
    }, error=function(e) { dev.off() })

    img_b64 <- paste0("data:image/png;base64,",base64enc::base64encode(tmp))
    quest   <- get_questionnaire_by_id(qid)
    rv$qr_tmp_path <- tmp
    rv$qr_uid      <- export$uid
    rv$qr_quest_id <- qid

    drive_ok <- rv$drive_connected

    showModal(modalDialog(
      title = tags$span("📱 Partager — ", tags$strong(quest$nom)),
      size  = "m", easyClose=TRUE,

      # Mode actif + infos questionnaire
      div(class="status-banner",
        if (panier_ok)
          tags$span("📦 Mode panier — fonctionne sur tout réseau (WiFi, 4G, WhatsApp…)")
        else
          tags$span(sprintf("📶 Mode WiFi local — IP : %s:8765", .local_ip))
      ),
      div(class="status-banner", style="margin-top:4px;",
        sprintf("✓ %d question(s) · %d section(s) · QR %d chars",
                export$n_questions,
                nrow(get_sections_by_questionnaire(qid)),
                export$n_chars)),

      # QR + UID
      div(style="text-align:center;padding:16px 0;",
        tags$img(src=img_b64, width="240px", height="240px",
                 style="border:2px solid #DDE3EC;border-radius:10px;"),
        div(style="margin-top:10px;font-family:'IBM Plex Mono',monospace;font-size:13px;
                   color:#0D1F35;background:#F5F7FA;padding:7px 16px;border-radius:6px;
                   display:inline-block;letter-spacing:.05em;font-weight:600;",
            export$uid)
      ),

      # Instructions
      div(style="background:#F5F7FA;border-radius:8px;padding:14px 16px;font-size:13px;",
        tags$strong("Comment ça fonctionne :"), tags$br(), br(),
        tags$ol(style="margin:0;padding-left:18px;line-height:2;",
          tags$li(HTML("<b>Étape 1 (Desktop)</b> — Connectez Drive ci-dessous puis cliquez <em>Publier sur Drive</em>.")),
          tags$li(HTML("<b>Étape 2 (Mobile)</b> — Connectez le même compte Google dans Paramètres.")),
          tags$li(HTML("<b>Étape 3 (Mobile)</b> — Scannez ce QR code depuis l'onglet Scanner.")),
          tags$li(HTML("<b>Résultat</b> — Le questionnaire s'installe automatiquement."))
        )
      ),
      br(),

      # Statut Drive + bouton connexion si nécessaire
      if (!drive_ok)
        div(
          div(class="status-banner warning",
            "⚠ Google Drive non connecté — requis pour publier le questionnaire."),
          br(),
          actionButton("btn_desktop_connect_drive", "🔗 Connecter Google Drive",
                       class="btn-primary", style="width:100%;")
        )
      else
        div(class="status-banner",
          "☁ Google Drive connecté — prêt à publier."),

      footer = tagList(
        modalButton("Fermer"),
        downloadButton("download_qr_png", "⬇ QR Image", class="btn-outline"),
        if (drive_ok)
          actionButton("btn_publish_drive", "☁ Publier sur Drive", class="btn-primary")
      )
    ))
  })

  # Upload Drive depuis le modal
  observeEvent(input$btn_publish_drive, {
    qid <- rv$qr_quest_id; req(!is.null(qid))
    if (!rv$drive_connected) {
      showNotification("Connectez d'abord Google Drive.", type="warning"); return()
    }
    showNotification("⏳ Publication en cours...", type="message", duration=2)
    result <- tryCatch(
      upload_quest_to_drive(qid),
      error=function(e) {
        showNotification(paste("Erreur Drive:", e$message), type="error", duration=8)
        NULL
      }
    )
    if (!is.null(result)) {
      rv$drive_connected <- TRUE
      showNotification(
        "✓ Questionnaire publié ! Les mobiles peuvent maintenant le télécharger.",
        type="message", duration=6)
    }
  })

  output$download_qr_png <- downloadHandler(
    filename = function() paste0("qr_", rv$qr_uid %||% "lestrade", ".png"),
    content  = function(file) {
      req(!is.null(rv$qr_tmp_path), file.exists(rv$qr_tmp_path))
      file.copy(rv$qr_tmp_path, file)
    }
  )

  observeEvent(input$btn_supprimer_quest, {
    if (is.null(rv$selected_quest)) { showNotification("Sélectionne un questionnaire.",type="warning"); return() }
    showModal(modalDialog(title="Confirmer la suppression",
      p("Supprime le questionnaire, ses sections, questions et réponses."),
      footer=tagList(modalButton("Annuler"),actionButton("confirm_del_quest","Supprimer",class="btn-danger"))))
  })
  observeEvent(input$confirm_del_quest, {
    delete_questionnaire(rv$selected_quest)
    rv$refresh_quests <- rv$refresh_quests+1L; rv$selected_quest <- NULL
    removeModal(); showNotification("Questionnaire supprimé.",type="warning")
  })

  # ── CONSTRUCTION ───────────────────────────────────────────────────────────
  observeEvent(input$btn_add_section, {
    qid <- as.numeric(input$builder_questionnaire)
    nom <- trimws(input$builder_new_section)
    if (invalid_id(qid)) { showNotification("Sélectionne un questionnaire.",type="warning"); return() }
    if (nom=="")          { showNotification("Nom de section obligatoire.",type="warning"); return() }
    sid <- create_section(qid,nom)
    rv$refresh_quests <- rv$refresh_quests+1L
    updateTextInput(session,"builder_new_section",value="")
    updateSelectInput(session,"builder_section_target",selected=sid)
    showNotification("Section ajoutée.",type="message")
  })

  observeEvent(input$btn_add_question, {
    sid   <- as.numeric(input$builder_section_target)
    qtype <- input$builder_question_type
    qtxt  <- trimws(input$builder_question_text)
    opts  <- parse_options(input$builder_question_options)
    if (invalid_id(sid))  { showNotification("Choisis une section.",type="warning"); return() }
    if (qtxt=="")         { showNotification("Libellé obligatoire.",type="warning"); return() }
    if (qtype %in% c("radio","checkbox","dropdown") && length(opts)==0)
      { showNotification("Ce type nécessite des options.",type="warning"); return() }
    create_question(sid,qtype,qtxt,options=opts,obligatoire=input$builder_required)
    rv$refresh_quests <- rv$refresh_quests+1L
    updateTextAreaInput(session,"builder_question_text",value="")
    updateTextAreaInput(session,"builder_question_options",value="")
    updateCheckboxInput(session,"builder_required",value=FALSE)
    showNotification("Question ajoutée.",type="message")
  })

  observeEvent(input$delete_section_id, {
    sid <- as.integer(input$delete_section_id)
    if (!is.na(sid)&&sid>0) { delete_section(sid); rv$refresh_quests <- rv$refresh_quests+1L; showNotification("Section supprimée.",type="warning") }
  })
  observeEvent(input$delete_question_id, {
    qid <- as.integer(input$delete_question_id)
    if (!is.na(qid)&&qid>0) { delete_question(qid); rv$refresh_quests <- rv$refresh_quests+1L; showNotification("Question supprimée.",type="warning") }
  })

  output$builder_structure <- renderUI({
    full <- tryCatch(builder_full(), error=function(e) NULL)
    if (is.null(full)) return(div(class="card",p("Sélectionne un questionnaire.")))
    if (nrow(full$sections)==0) return(div(class="card",p("Aucune section.")))
    tagList(
      div(class="card",h3(full$questionnaire$nom),p(full$questionnaire$description%||%""),
          p(class="hint",paste(nrow(full$sections),"section(s),",nrow(full$questions),"question(s)"))),
      lapply(seq_len(nrow(full$sections)), function(i) {
        sec <- full$sections[i,]
        sec_q <- full$questions[full$questions$section_id==sec$id,,drop=FALSE]
        div(class="section-card",
          fluidRow(
            column(8,h4(sec$nom)),
            column(4,div(style="text-align:right;",
              tags$button(class="btn btn-danger btn-sm",
                onclick=sprintf("Shiny.setInputValue('delete_section_id',%s,{priority:'event'})",sec$id),
                "Supprimer section")))
          ),
          if (nrow(sec_q)==0) p(class="hint","Pas encore de questions.") else
            lapply(seq_len(nrow(sec_q)), function(j) {
              q   <- sec_q[j,]
              opts <- tryCatch(fromJSON(q$options%||%"{}"),error=function(e) character(0))
              div(class="question-item",
                fluidRow(
                  column(9, tags$strong(q$texte),tags$br(),
                    span(class="hint",paste("Type:",q_type_label(q$type),
                          "| Obligatoire:",ifelse(as.integer(q$obligatoire)==1,"Oui","Non"))),
                    if(length(opts)>0) p(class="hint",paste("Options:",paste(opts,collapse=", ")))),
                  column(3,div(style="text-align:right;",
                    tags$button(class="btn btn-warning btn-sm",
                      onclick=sprintf("Shiny.setInputValue('delete_question_id',%s,{priority:'event'})",q$id),
                      "Supprimer")))
                ))
            })
        )
      })
    )
  })

  # ── REMPLIR ────────────────────────────────────────────────────────────────
  output$form_header_info <- renderUI({
    qid <- as.numeric(input$select_questionnaire_form)
    if (invalid_id(qid)) return(p(class="hint","Sélectionne un questionnaire."))
    full <- get_questionnaire_full(qid)
    if (is.null(full)) return(NULL)
    div(class="hint",tags$strong(full$questionnaire$nom),tags$br(),
        span(full$questionnaire$description%||%""),tags$br(),
        span(paste(nrow(full$sections),"section(s),",nrow(full$questions),"question(s)")))
  })

  output$formulaire_questionnaire <- renderUI({
    qid <- as.numeric(input$select_questionnaire_form)
    if (invalid_id(qid)) return(div(class="card",p("Sélectionne un questionnaire.")))
    full <- get_questionnaire_full(qid)
    if (is.null(full)||nrow(full$sections)==0) return(div(class="card",p("Aucune section.")))
    if (nrow(full$questions)==0) return(div(class="card",p("Aucune question.")))
    tagList(lapply(seq_len(nrow(full$sections)), function(i) {
      sec <- full$sections[i,]
      sec_q <- full$questions[full$questions$section_id==sec$id,,drop=FALSE]
      div(class="card",h3(sec$nom),
        if (nrow(sec_q)==0) p(class="hint","Aucune question dans cette section.") else
          lapply(seq_len(nrow(sec_q)), function(j) render_question_input(sec_q[j,],paste0("q_",sec_q$id[j])))
      )
    }))
  })

  observeEvent(input$btn_soumettre, {
    qid  <- as.numeric(input$select_questionnaire_form)
    full <- get_questionnaire_full(qid)
    if (invalid_id(qid)||is.null(full)) { showNotification("Questionnaire invalide.",type="error"); return() }
    resp <- list(); missing <- character(0)
    for (i in seq_len(nrow(full$questions))) {
      q  <- full$questions[i,]; iid <- paste0("q_",q$id); val <- input[[iid]]
      if (as.integer(q$obligatoire)==1 && is_empty_response_value(val)) missing <- c(missing,q$texte)
      resp[[as.character(q$id)]] <- val
    }
    if (length(missing)>0) { showNotification("Questions obligatoires manquantes.",type="error"); return() }
    save_reponse(qid, toJSON(resp,auto_unbox=TRUE,null="null"))
    rv$refresh_reponses <- rv$refresh_reponses+1L
    showNotification("Réponse enregistrée.",type="message")
  })

  # ── RÉPONSES ───────────────────────────────────────────────────────────────
  output$table_reponses <- renderDT({
    bundle <- response_bundle(); wide <- bundle$wide
    if (nrow(wide)==0) return(datatable(data.frame(Message="Aucune réponse sur cette période"),options=list(dom="t"),rownames=FALSE))
    wide$horodateur <- format(as.POSIXct(wide$horodateur),"%d/%m/%Y %H:%M:%S")
    datatable(wide,selection="single",rownames=FALSE,options=list(scrollX=TRUE,pageLength=10,dom="ftp"))
  }, server=FALSE)

  observeEvent(input$table_reponses_rows_selected, {
    bundle <- response_bundle(); idx <- input$table_reponses_rows_selected
    if (length(idx)>0&&idx<=nrow(bundle$wide)) rv$selected_rep_id <- bundle$wide$reponse_id[idx]
  })

  get_selected_response <- reactive({
    bundle <- response_bundle()
    if (is.null(rv$selected_rep_id)||nrow(bundle$raw)==0) return(NULL)
    bundle$raw[bundle$raw$id==rv$selected_rep_id,,drop=FALSE]
  })

  observeEvent(input$btn_voir_reponse, {
    sel <- get_selected_response(); qid <- as.numeric(input$select_questionnaire_reponses)
    if (is.null(sel)||nrow(sel)==0) { showNotification("Sélectionne une réponse.",type="warning"); return() }
    qs  <- get_all_questions_by_questionnaire(qid)
    dat <- tryCatch(fromJSON(sel$donnees_json[1],simplifyVector=FALSE),error=function(e) list())
    items <- lapply(seq_len(nrow(qs)), function(i) {
      q <- qs[i,]; v <- format_response_value(dat[[as.character(q$id)]])
      div(style="margin-bottom:10px;",tags$strong(paste0(q$section_nom," / ",q$texte)),tags$br(),span(ifelse(v=="","(vide)",v)))
    })
    showModal(modalDialog(title=paste("Réponse #",sel$id[1]),items,easyClose=TRUE,size="l"))
  })

  observeEvent(input$btn_modifier_reponse, {
    sel  <- get_selected_response(); qid <- as.numeric(input$select_questionnaire_reponses)
    full <- get_questionnaire_full(qid)
    if (is.null(sel)||nrow(sel)==0||is.null(full)) { showNotification("Sélectionne une réponse.",type="warning"); return() }
    dat <- tryCatch(fromJSON(sel$donnees_json[1],simplifyVector=FALSE),error=function(e) list())
    content <- lapply(seq_len(nrow(full$sections)), function(i) {
      sec <- full$sections[i,]; sec_q <- full$questions[full$questions$section_id==sec$id,,drop=FALSE]
      div(class="section-card",h4(sec$nom),
          lapply(seq_len(nrow(sec_q)), function(j) {
            q <- sec_q[j,]; render_question_input(q,paste0("edit_q_",q$id),dat[[as.character(q$id)]],edit_mode=TRUE)
          }))
    })
    showModal(modalDialog(title=paste("Modifier réponse #",sel$id[1]),content,size="l",easyClose=TRUE,
      footer=tagList(modalButton("Annuler"),actionButton("btn_save_reponse","Sauvegarder",class="btn-success"))))
  })

  observeEvent(input$btn_save_reponse, {
    sel <- get_selected_response(); qid <- as.numeric(input$select_questionnaire_reponses)
    full <- get_questionnaire_full(qid)
    if (is.null(sel)||nrow(sel)==0||is.null(full)) return()
    updated <- list()
    for (i in seq_len(nrow(full$questions))) {
      q <- full$questions[i,]; updated[[as.character(q$id)]] <- input[[paste0("edit_q_",q$id)]]
    }
    update_reponse(sel$id[1], toJSON(updated,auto_unbox=TRUE,null="null"))
    rv$refresh_reponses <- rv$refresh_reponses+1L
    removeModal(); showNotification("Réponse mise à jour.",type="message")
  })

  observeEvent(input$btn_supprimer_reponse, {
    if (is.null(rv$selected_rep_id)) { showNotification("Sélectionne une réponse.",type="warning"); return() }
    showModal(modalDialog(title="Supprimer la réponse",p("Action irréversible."),
      footer=tagList(modalButton("Annuler"),actionButton("confirm_del_rep","Supprimer",class="btn-danger"))))
  })
  observeEvent(input$confirm_del_rep, {
    sel <- get_selected_response()
    if (!is.null(sel)&&nrow(sel)>0) { delete_reponse(sel$id[1]); rv$refresh_reponses <- rv$refresh_reponses+1L; rv$selected_rep_id <- NULL }
    removeModal(); showNotification("Réponse supprimée.",type="warning")
  })

  output$download_reponses_excel <- downloadHandler(
    filename = function() {
      qid  <- as.numeric(input$select_questionnaire_reponses)
      q    <- get_questionnaire_by_id(qid)
      paste0("reponses_",gsub("[^A-Za-z0-9_-]","_",q$nom[1]%||%"export"),"_",Sys.Date(),".xlsx")
    },
    content = function(file) {
      qid  <- as.numeric(input$select_questionnaire_reponses)
      bundle <- response_bundle()
      wb <- openxlsx::createWorkbook()
      openxlsx::addWorksheet(wb,"reponses"); openxlsx::writeData(wb,"reponses",bundle$wide)
      openxlsx::addWorksheet(wb,"taux_reponse"); openxlsx::writeData(wb,"taux_reponse",taux_reponse_par_question(qid))
      openxlsx::addWorksheet(wb,"abandons"); openxlsx::writeData(wb,"abandons",taux_abandon(qid)%||%data.frame())
      openxlsx::saveWorkbook(wb,file,overwrite=TRUE)
    }
  )

  # ── SYNC DESKTOP→DESKTOP PAR UID (QR code) ────────────────────────────────
  output$uid_sync_result_ui <- renderUI({ NULL })

  observeEvent(input$btn_sync_by_uid, {
    uid <- trimws(input$input_uid_sync)
    if (uid == "") {
      showNotification("Entrez l'identifiant du QR code.", type="warning"); return()
    }
    if (!rv$drive_connected) {
      showNotification("Connectez d'abord Google Drive (onglet Construction > QR).",
                       type="warning", duration=5); return()
    }

    # ── Étape 1 : questionnaire ──────────────────────────────────────────────
    showNotification("⏳ Étape 1/2 — Téléchargement du questionnaire...",
                     type="message", duration=4)
    quest_result <- tryCatch({
      json_str <- download_quest_from_drive(uid)
      new_id   <- import_quest_from_json(json_str)
      q        <- get_questionnaire_by_id(new_id)
      rv$refresh_quests <- rv$refresh_quests + 1L
      list(ok=TRUE, id=new_id, nom=q$nom %||% paste("Questionnaire", new_id))
    }, error=function(e) list(ok=FALSE, msg=e$message))

    if (!isTRUE(quest_result$ok)) {
      showNotification(paste("✗ Questionnaire introuvable :", quest_result$msg),
                       type="error", duration=8)
      output$uid_sync_result_ui <- renderUI({
        div(class="panel-block",style="background:#FFF0F0;border-color:var(--red);margin-top:10px;",
          div(style="color:var(--red);font-size:13px;",
            tags$strong("✗ Échec — "), quest_result$msg))
      })
      return()
    }

    # ── Étape 2 : réponses depuis la Sheet ───────────────────────────────────
    showNotification("⏳ Étape 2/2 — Récupération des réponses...",
                     type="message", duration=4)
    rep_result <- tryCatch({
      found <- googlesheets4::gs4_find("Lestrade_Forms_Reponses")
      if (is.null(found) || nrow(found) == 0)
        return(list(ok=TRUE, n=0, msg="Sheet Drive introuvable — réponses non importées."))

      sheet_id <- as.character(found$id[1])
      df <- googlesheets4::read_sheet(sheet_id, sheet="reponses")
      if (nrow(df) == 0) return(list(ok=TRUE, n=0, msg="Sheet vide."))

      # Filtrer par nom du questionnaire importé
      df_filt <- df[trimws(df$questionnaire_nom) == trimws(quest_result$nom), ]
      if (nrow(df_filt) == 0)
        return(list(ok=TRUE, n=0, msg=sprintf("Aucune réponse pour '%s' dans la Sheet.", quest_result$nom)))

      # Importer dans questionnaires.db (anti-doublon par horodateur normalisé)
      norm_horo <- function(h) {
        # Normalise "2024-01-15T10:30:45" et "2024-01-15 10:30:45" → même chaîne
        trimws(gsub("T", " ", as.character(h)))
      }
      existing <- get_reponses_by_questionnaire(quest_result$id)
      existing_horos <- norm_horo(existing$horodateur)
      n_import <- 0L
      for (i in seq_len(nrow(df_filt))) {
        row <- df_filt[i, ]
        h <- norm_horo(row$horodateur)
        if (h %in% existing_horos) next
        save_reponse(quest_result$id, as.character(row$donnees_json))
        existing_horos <- c(existing_horos, h)  # mise à jour locale
        n_import <- n_import + 1L
      }
      rv$refresh_reponses <- rv$refresh_reponses + 1L
      list(ok=TRUE, n=n_import, total=nrow(df_filt), msg=NULL)
    }, error=function(e) list(ok=FALSE, msg=e$message))

    # ── Résumé final ─────────────────────────────────────────────────────────
    output$uid_sync_result_ui <- renderUI({
      rep_txt <- if (isTRUE(rep_result$ok)) {
        if (!is.null(rep_result$msg))
          rep_result$msg
        else
          sprintf("%d nouvelle(s) réponse(s) importée(s) sur %d dans la Sheet.",
                  rep_result$n, rep_result$total)
      } else {
        paste("Réponses — erreur :", rep_result$msg)
      }
      div(class="panel-block",
          style="background:#F0FBF9;border-color:var(--teal);margin-top:10px;",
        div(style="font-size:13px;",
          tags$strong(style="color:var(--teal);",
            sprintf("✓ '%s' synchronisé", quest_result$nom)),
          tags$br(),
          span(style="color:var(--text2);", rep_txt)
        )
      )
    })
    showNotification(
      sprintf("✓ '%s' — %s", quest_result$nom,
              if(isTRUE(rep_result$ok) && is.null(rep_result$msg))
                sprintf("%d réponse(s) importée(s)", rep_result$n)
              else "réponses : voir résumé"),
      type="message", duration=6)
  })

  # ── PANIER APPS SCRIPT ────────────────────────────────────────────────────

  output$panier_status_ui <- renderUI({
    url <- get_panier_url()
    if (is.null(url)) {
      span(style="color:#888;font-size:13px;", "Panier non configuré — cliquez sur ⚙ Configurer.")
    } else {
      span(style="color:#0D6EFD;font-size:13px;font-family:monospace;",
           "✓ ", tags$code(substr(url, 1, 60), if(nchar(url)>60) "..." else ""))
    }
  })

  output$panier_import_result_ui <- renderUI({ NULL })

  # Création automatique du panier (Sheet + Apps Script)
  observeEvent(input$btn_panier_create, {
    if (!rv$drive_connected) {
      showNotification("Connectez-vous d'abord à Google Drive (badge en haut).", type = "warning")
      return()
    }
    showModal(modalDialog(
      title = "✨ Configurer le panier",
      size  = "s",
      div(
        p("Cette opération va :"),
        tags$ol(
          tags$li("Créer automatiquement le Google Sheet ", tags$strong("Lestrade_Panier")),
          tags$li("Vous guider pour déployer le Apps Script (2 min, une seule fois)")
        ),
        p(class = "hint-text",
          "Le déploiement Apps Script nécessite une action manuelle — ",
          "Google bloque son automatisation pour les apps non vérifiées.")
      ),
      footer = tagList(
        modalButton("Annuler"),
        actionButton("btn_panier_create_confirm", "✨ Créer le Sheet", class = "btn-success")
      )
    ))
  })

  observeEvent(input$btn_panier_create_confirm, {
    removeModal()
    withProgress(message = "Création du Google Sheet...", value = 0.5, {
      result <- tryCatch(
        create_panier_automatique(),
        error = function(e) list(ok = FALSE, error = e$message)
      )
    })

    if (!isTRUE(result$ok)) {
      showNotification(paste("Erreur :", result$error), type = "error", duration = 10)
      return()
    }

    # Sauvegarder l'URL du Sheet pour le bouton "Ouvrir"
    rv$panier_sheet_url <- result$sheet_url

    gs_code <- tryCatch(
      paste(readLines(
        file.path(dirname(DB_PATH), "lestrade_panier.gs"), warn = FALSE
      ), collapse = "\n"),
      error = function(e) "# Erreur : fichier lestrade_panier.gs introuvable"
    )

    showModal(modalDialog(
      title = "✅ Sheet créé — 1 étape manuelle",
      size  = "l", easyClose = FALSE,
      div(
        div(class = "alert alert-success",
            "✓ Google Sheet ", tags$strong("Lestrade_Panier"), " créé dans votre Drive."),
        p(tags$strong("Maintenant déployez le Apps Script (une seule fois) :")),
        tags$ol(
          tags$li(
            "Ouvrez le Sheet dans votre navigateur :",
            br(),
            actionButton("btn_open_sheet_browser", "🌐 Ouvrir le Sheet",
                         class = "btn-primary btn-sm", style = "margin:4px 0;"),
            br(),
            tags$small("ou copiez cette URL : "),
            tags$code(style = "font-size:11px; word-break:break-all;", result$sheet_url)
          ),
          tags$li("Extensions → ", tags$strong("Apps Script")),
          tags$li(
            "Effacez le code existant, puis cliquez ", tags$strong("Copier le code"), " :",
            br(),
            div(style = "position:relative; margin-top:8px;",
              tags$textarea(
                id    = "gs_code_textarea",
                readonly = NA,
                style = paste0(
                  "width:100%; height:180px; font-family:monospace; font-size:11px;",
                  "background:#f8f9fa; border:1px solid #dee2e6; border-radius:4px;",
                  "padding:8px; resize:vertical; color:#333;"
                ),
                gs_code
              ),
              br(),
              tags$button(
                "📋 Copier le code",
                onclick = paste0(
                  "var t=document.getElementById('gs_code_textarea');",
                  "t.select(); t.setSelectionRange(0,99999);",
                  "document.execCommand('copy');",
                  "this.textContent='✅ Copié !';",
                  "var btn=this; setTimeout(function(){btn.textContent='📋 Copier le code';},2000);"
                ),
                class = "btn btn-sm btn-success",
                style = "margin-top:6px;"
              )
            )
          ),
          tags$li("Sauvegardez (", tags$kbd("Ctrl+S"), ")"),
          tags$li(
            "Cliquez ", tags$strong("Déployer → Nouveau déploiement"), br(),
            "· Type : ", tags$strong("Application Web"), br(),
            "· Exécuter en tant que : ", tags$strong("Moi"), br(),
            "· Qui a accès : ", tags$strong("Tout le monde"), br(),
            "→ ", tags$strong("Déployer"), " → Autorisez → ", tags$strong("copiez l'URL /exec")
          ),
          tags$li(
            "Revenez ici → ", tags$strong("⚙ URL manuelle"), " → collez l'URL → Enregistrer"
          )
        )
      ),
      footer = modalButton("J'ai compris")
    ))
  })

  # Ouvrir le Sheet — cloud : lien JS au lieu de browseURL
  observeEvent(input$btn_open_sheet_browser, {
    url <- rv$panier_sheet_url
    if (!is.null(url) && nzchar(url)) {
      session$sendCustomMessage("openUrl", url)
    }
  })

  # Configuration du panier
  observeEvent(input$btn_panier_config, {
    current_url <- get_panier_url() %||% ""
    showModal(modalDialog(
      title = "⚙ Configurer le panier Google Sheet",
      size  = "m",
      div(
        p(class="hint-text",
          "Collez l'URL de déploiement du Apps Script (elle doit terminer par ",
          tags$code("/exec"), ")."),
        div(class="alert alert-info", style="font-size:12px;",
          "✔ URL correcte : ", tags$code("https://script.google.com/macros/s/AKfycb.../exec"), br(),
          "✘ URL incorrecte : ", tags$code("https://script.google.com/d/.../edit")
        ),
        textInput("panier_url_input", "URL du Apps Script Web App",
                  value = current_url, width = "100%",
                  placeholder = "https://script.google.com/macros/s/.../exec"),
        uiOutput("panier_test_result_ui")
      ),
      footer = tagList(
        modalButton("Annuler"),
        actionButton("btn_panier_test_url",  "🔍 Tester",      class = "btn-info"),
        actionButton("btn_panier_save_url",  "💾 Enregistrer", class = "btn-primary")
      )
    ))
  })

  output$panier_test_result_ui <- renderUI({ NULL })

  observeEvent(input$btn_panier_test_url, {
    url <- trimws(input$panier_url_input)
    if (!nzchar(url)) {
      output$panier_test_result_ui <- renderUI(
        div(class="alert alert-warning", style="margin-top:8px;", "Entrez une URL d'abord."))
      return()
    }
    output$panier_test_result_ui <- renderUI(
      div(style="margin-top:8px;color:#888;", "Test en cours..."))
    result <- panier_check(url)
    if (result$ok) {
      output$panier_test_result_ui <- renderUI(
        div(class="alert alert-success", style="margin-top:8px;",
            sprintf("✓ Panier accessible — %d réponse(s) en attente.", result$nb)))
    } else {
      output$panier_test_result_ui <- renderUI(
        div(class="alert alert-danger", style="margin-top:8px;white-space:pre-wrap;",
            result$msg))
    }
  })

  observeEvent(input$btn_panier_save_url, {
    url <- trimws(input$panier_url_input)
    if (!nzchar(url) || !startsWith(url, "https://")) {
      showNotification("URL invalide — doit commencer par https://", type = "error")
      return()
    }
    save_panier_url(url)
    removeModal()
    showNotification("✓ URL panier enregistrée", type = "message")
  })

  # Import depuis le panier
  observeEvent(input$btn_panier_import, {
    url <- get_panier_url()
    if (is.null(url)) {
      showNotification("Configurez d'abord le panier (⚙ Configurer).", type = "warning")
      return()
    }
    withProgress(message = "Import du panier en cours...", value = 0.5, {
      result <- tryCatch(
        panier_import(url = url, clear_after = TRUE),
        error = function(e) list(error = e$message)
      )
    })
    if (!is.null(result$error)) {
      output$panier_import_result_ui <- renderUI(
        div(class="alert alert-danger", style="margin-top:8px;",
            "Erreur : ", result$error))
    } else {
      rv$refresh_reponses <- (rv$refresh_reponses %||% 0) + 1
      output$panier_import_result_ui <- renderUI(
        div(class="alert alert-success", style="margin-top:8px;",
            sprintf("✓ %d réponse(s) importée(s), %d ignorée(s) (doublons)",
                    result$imported, result$skipped)))
    }
  })

  # ── IMPORT DEPUIS DRIVE ────────────────────────────────────────────────────
  output$drive_sync_status_ui <- renderUI({
    if (rv$drive_connected)
      div(class="badge-tag", style="background:#D1F0EC;color:#0A8075;border-color:#0A8075;",
          "☁ Drive connecté")
    else
      div(class="badge-tag", style="background:#FFF8E7;color:#7A5000;border-color:#E8A020;",
          "⚠ Drive non connecté — connectez via l'onglet Construction > QR Code")
  })

  output$drive_import_result_ui <- renderUI({ NULL })

  observeEvent(input$btn_import_from_drive, {
    if (!rv$drive_connected) {
      showNotification("Connectez d'abord Google Drive (onglet Construction > bouton QR).",
                       type="warning", duration=5)
      return()
    }
    showNotification("Recherche de la Google Sheet...", type="message", duration=3)
    result <- tryCatch({
      # Chercher la sheet Lestrade_Forms_Reponses
      found <- googlesheets4::gs4_find("Lestrade_Forms_Reponses")
      if (is.null(found) || nrow(found) == 0)
        stop("Sheet 'Lestrade_Forms_Reponses' introuvable sur Drive.")

      sheet_id <- as.character(found$id[1])
      df <- googlesheets4::read_sheet(sheet_id, sheet = "reponses")
      if (nrow(df) == 0) stop("Aucune réponse dans la Sheet Drive.")

      # Importer chaque ligne comme réponse dans questionnaires.db
      norm_horo <- function(h) trimws(gsub("T", " ", as.character(h)))
      # Pré-charger les horodateurs existants par questionnaire (évite N requêtes)
      existing_horos_cache <- list()
      n_import <- 0L
      for (i in seq_len(nrow(df))) {
        row <- df[i, ]
        qid <- as.integer(row$questionnaire_id)
        if (is.na(qid) || is.null(row$donnees_json)) next
        q <- get_questionnaire_by_id(qid)
        if (is.null(q)) next
        # Cache par qid
        qkey <- as.character(qid)
        if (is.null(existing_horos_cache[[qkey]])) {
          ex <- get_reponses_by_questionnaire(qid)
          existing_horos_cache[[qkey]] <- norm_horo(ex$horodateur)
        }
        h <- norm_horo(row$horodateur)
        if (h %in% existing_horos_cache[[qkey]]) next
        save_reponse(qid, as.character(row$donnees_json))
        existing_horos_cache[[qkey]] <- c(existing_horos_cache[[qkey]], h)
        n_import <- n_import + 1L
      }
      rv$refresh_reponses <- rv$refresh_reponses + 1L
      list(ok = TRUE, n = n_import, total = nrow(df))
    }, error = function(e) list(ok = FALSE, msg = e$message))

    if (isTRUE(result$ok)) {
      showNotification(
        sprintf("✓ %d nouvelle(s) réponse(s) importée(s) depuis Drive (%d au total dans la Sheet).",
                result$n, result$total),
        type = "message", duration = 6)
      output$drive_import_result_ui <- renderUI({
        div(style="font-size:12px;color:#0A8075;margin-top:4px;",
            sprintf("✓ %d importée(s)", result$n))
      })
    } else {
      showNotification(paste("Erreur Drive :", result$msg), type="error", duration=8)
      output$drive_import_result_ui <- renderUI({
        div(style="font-size:12px;color:#C0392B;margin-top:4px;", "✗ Erreur")
      })
    }
  })

  # ── IMPORT EXTERNE ─────────────────────────────────────────────────────────
  import_sheets_rv <- reactive({
    f <- input$import_file; if (is.null(f)) return(character(0))
    if (tolower(tools::file_ext(f$name)) %in% c("xlsx","xls"))
      tryCatch(readxl::excel_sheets(f$datapath),error=function(e) character(0))
    else character(0)
  })

  output$import_sheet_ui <- renderUI({
    f <- input$import_file; if (is.null(f)) return(NULL)
    sheets <- import_sheets_rv()
    if (length(sheets)>0) selectInput("import_sheet","Feuille Excel",choices=sheets)
    else NULL
  })

  import_raw_preview <- reactive({
    f <- input$import_file; if (is.null(f)) return(NULL)
    tryCatch(
      read_external_file(f$datapath,
        sheet      = if (length(import_sheets_rv())>0) input$import_sheet else NULL,
        has_header = isTRUE(input$import_header)),
      error=function(e) { showNotification(paste("Erreur:",e$message),type="error"); NULL })
  })

  output$import_file_loaded <- reactive({ !is.null(import_raw_preview())&&nrow(import_raw_preview())>0 })
  outputOptions(output,"import_file_loaded",suspendWhenHidden=FALSE)

  output$import_preview <- renderDT({
    df <- import_raw_preview()
    if (is.null(df)||nrow(df)==0) return(datatable(data.frame(Message="Aperçu indisponible."),options=list(dom="t"),rownames=FALSE))
    datatable(as.data.frame(head(df,50)),rownames=FALSE,options=list(scrollX=TRUE,pageLength=10))
  })

  output$import_detection_table <- renderDT({
    df <- import_raw_preview()
    if (is.null(df)||nrow(df)==0) return(datatable(data.frame(Message="Chargez un fichier."),options=list(dom="t"),rownames=FALSE))
    bundle <- build_ext_bundle_auto(df)
    meta   <- bundle$meta
    if (nrow(meta)==0) return(datatable(data.frame(Message="Aucune colonne détectée."),options=list(dom="t"),rownames=FALSE))
    d <- data.frame(
      Colonne    = meta$label,
      Type       = meta$type,
      Modalites  = meta$n_unique,
      Groupable  = ifelse(meta$is_groupable,"✓",""),
      Indicateur = ifelse(meta$is_indicator,"✓",""),
      stringsAsFactors=FALSE
    )
    datatable(d,rownames=FALSE,options=list(scrollX=TRUE,pageLength=15,dom="ftp"))
  })

  output$import_row_count  <- renderText({ df<-import_raw_preview(); if(is.null(df)) "—" else as.character(nrow(df)) })
  output$import_col_count  <- renderText({ df<-import_raw_preview(); if(is.null(df)) "—" else as.character(ncol(df)) })

  charger_analyse_action <- function() {
    df <- import_raw_preview()
    if (is.null(df)||nrow(df)==0) { showNotification("Aucun fichier valide.",type="warning"); return() }
    rv$ext_df       <- df
    rv$ext_filename <- input$import_file$name
    updateTabsetPanel(session,"main_tabs",selected="Analyse externe")
    showNotification(paste0("Fichier chargé : ",input$import_file$name," (",nrow(df)," lignes)"),type="message",duration=4)
  }
  observeEvent(input$btn_charger_analyse,  charger_analyse_action())
  observeEvent(input$btn_charger_analyse2, charger_analyse_action())

  observeEvent(input$btn_effacer_fichier, {
    rv$ext_df <- NULL; rv$ext_filename <- NULL
    showNotification("Fichier supprimé de la session.",type="warning")
  })

  observeEvent(input$btn_sauvegarder_en_base, {
    bundle <- ext_bundle()
    if (nrow(bundle$data)==0||nrow(bundle$meta)==0) { showNotification("Aucun bundle exploitable.",type="error"); return() }
    nom <- trimws(input$ext_save_name%||%"")
    if (nom=="") { showNotification("Entrez un nom pour le questionnaire.",type="warning"); return() }
    result <- tryCatch(
      save_external_as_questionnaire(bundle, nom, input$ext_save_desc%||%""),
      error=function(e) e)
    if (inherits(result,"error")) {
      showNotification(paste("Échec:",conditionMessage(result)),type="error"); return()
    }
    rv$refresh_quests <- rv$refresh_quests+1L
    updateSelectInput(session,"select_questionnaire_analytics",selected=result)
    showNotification("Fichier sauvegardé comme questionnaire interne.",type="message")
    removeModal()
  })

  observeEvent(input$btn_ouvrir_save_modal, {
    showModal(modalDialog(title="Sauvegarder en base",
      textInput("ext_save_name","Nom du questionnaire",placeholder="Ex: Enquête 2026"),
      textInput("ext_save_desc","Description","Importé depuis fichier externe"),
      footer=tagList(modalButton("Annuler"),actionButton("btn_sauvegarder_en_base","Sauvegarder",class="btn-success"))))
  })

  output$ext_status_ui <- renderUI({
    if (is.null(rv$ext_df)||nrow(rv$ext_df)==0) {
      div(class="hint",p("Aucun fichier chargé. Allez dans l'onglet Import."))
    } else {
      div(style="padding:8px 0;",
        tags$strong(rv$ext_filename),
        span(class="hint",paste0(" — ",nrow(rv$ext_df)," lignes")),
        tags$br(),
        div(class="form-actions",style="margin-top:8px;",
          actionButton("btn_effacer_fichier","✕ Supprimer le fichier",class="btn-danger btn-sm"),
          actionButton("btn_ouvrir_save_modal","💾 Sauvegarder en base",class="btn-default btn-sm")
        )
      )
    }
  })

  # ══════════════════════════════════════════════════════════════════════════
  # ANALYTICS — fonction générique (couvre interne ET externe)
  # pfx="" pour Analytics, pfx="ext_" pour Analyse externe
  # ══════════════════════════════════════════════════════════════════════════
  setup_analytics <- function(bundle_fn, pfx) {

    iid  <- function(x) paste0(pfx, x)          # input id
    oid  <- function(x) paste0(pfx, x)          # output id

    # -- observer : mise à jour des selects ----------------------------------
    observe({
      bundle <- bundle_fn()
      meta   <- bundle$meta
      empty_choices <- c("Sélectionner..."="")

      if (is.null(meta)||nrow(meta)==0) {
        for (sel in c("analytics_table_row","analytics_table_col","analytics_table_split",
                      "analytics_compare_row","analytics_compare_col",
                      "analytics_profile_group","analytics_gtsummary_by",
                      "advanced_compare_group","advanced_compare_target",
                      "advanced_composite_group","advanced_logit_outcome"))
          updateSelectInput(session,iid(sel),choices=empty_choices)
        for (sel in c("analytics_gtsummary_vars","advanced_composite_sections",
                      "advanced_logit_predictors"))
          updateSelectInput(session,iid(sel),choices=c())
        updateSelectInput(session,iid("analytics_plot_var"),choices=empty_choices)
        return()
      }

      group_meta  <- meta[meta$is_groupable,,drop=FALSE]
      group_ch    <- c("Sélectionner..."="", make_meta_choices(group_meta))
      split_ch    <- c("Aucune"="", make_meta_choices(group_meta))
      all_ch      <- make_meta_choices(meta[meta$n_unique>0,,drop=FALSE])
      binary_meta <- meta[meta$n_unique==2&meta$is_groupable,,drop=FALSE]
      section_ch  <- setNames(as.list(unique(meta$section_nom)),unique(meta$section_nom))

      catalog  <- make_plot_catalog(bundle)
      plot_ch  <- c("Sélectionner..."="", setNames(as.list(catalog$id),catalog$label))

      score_ch <- if ("score_analytique" %in% names(bundle$data) && any(!is.na(bundle$data$score_analytique)))
        c(all_ch, "Score analytique"="score_analytique") else all_ch

      updateSelectInput(session,iid("analytics_table_row"),    choices=group_ch)
      updateSelectInput(session,iid("analytics_table_col"),    choices=group_ch)
      updateSelectInput(session,iid("analytics_table_split"),  choices=split_ch)
      updateSelectInput(session,iid("analytics_compare_row"),  choices=group_ch)
      updateSelectInput(session,iid("analytics_compare_col"),  choices=group_ch)
      updateSelectInput(session,iid("analytics_profile_group"),choices=group_ch)
      updateSelectInput(session,iid("analytics_gtsummary_by"), choices=group_ch)
      updateSelectInput(session,iid("analytics_gtsummary_vars"),choices=score_ch,
        selected=head(unname(unlist(score_ch)),8))
      updateSelectInput(session,iid("analytics_plot_var"),     choices=plot_ch,
        selected=if(length(plot_ch)>1) plot_ch[[2]] else "")
      updateSelectInput(session,iid("advanced_compare_group"), choices=group_ch)
      updateSelectInput(session,iid("advanced_compare_target"),choices=c("Sélectionner..."="",score_ch))
      updateSelectInput(session,iid("advanced_composite_group"),choices=group_ch)
      updateSelectInput(session,iid("advanced_composite_sections"),choices=section_ch)
      updateSelectInput(session,iid("advanced_logit_outcome"), choices=c("Sélectionner..."="",make_meta_choices(binary_meta)))
      updateSelectInput(session,iid("advanced_logit_predictors"),choices=group_ch[-1])
    })

    # -- métriques -----------------------------------------------------------
    output[[oid("analytics_n")]] <- renderText({ nrow(bundle_fn()$data) })
    output[[oid("analytics_score_moyen")]] <- renderText({
      df <- bundle_fn()$data
      if (nrow(df)==0||all(is.na(df$score_analytique))) return("—")
      round(mean(df$score_analytique,na.rm=TRUE),2)
    })
    output[[oid("analytics_score_max")]] <- renderText({
      df <- bundle_fn()$data
      if (nrow(df)==0||all(is.na(df$score_analytique))) return("—")
      max(df$score_analytique,na.rm=TRUE)
    })
    output[[oid("analytics_score_min")]] <- renderText({
      df <- bundle_fn()$data
      if (nrow(df)==0||all(is.na(df$score_analytique))) return("—")
      min(df$score_analytique,na.rm=TRUE)
    })

    # -- qualité des données -------------------------------------------------
    output[[oid("analytics_data_quality")]] <- renderDT({
      bundle <- bundle_fn(); df <- bundle$data; meta <- bundle$meta
      if (nrow(df)==0) return(datatable(data.frame(Message="Aucune donnée."),options=list(dom="t"),rownames=FALSE))
      value_cols   <- if(nrow(meta)>0) intersect(meta$col_id,names(df)) else character(0)
      expected     <- nrow(df)*length(value_cols)
      non_empty    <- if(length(value_cols)>0) sum(vapply(df[value_cols],function(col){
        sum(!is.na(col)&trimws(as.character(col))!="")},integer(1))) else 0L
      d <- data.frame(
        Indicateur=c("Réponses","Variables","Groupables","Scorables","Cellules renseignées","Taux global"),
        Valeur=c(nrow(df),nrow(meta),sum(meta$is_groupable,na.rm=TRUE),sum(meta$is_indicator,na.rm=TRUE),
                 non_empty, if(expected>0) paste0(round(non_empty/expected*100,1),"%") else "—"),
        stringsAsFactors=FALSE)
      datatable(d,rownames=FALSE,options=list(dom="t",paging=FALSE))
    })

    output[[oid("analytics_completion_table")]] <- renderDT({
      bundle <- bundle_fn()
      comp <- completion_from_bundle(bundle$data, bundle$meta)
      if (nrow(comp)==0) return(datatable(data.frame(Message="Pas de sections."),options=list(dom="t"),rownames=FALSE))
      comp <- comp[order(-comp$taux),,drop=FALSE]
      names(comp) <- c("Section","Taux de complétude (%)")
      datatable(comp,rownames=FALSE,options=list(dom="t",pageLength=10))
    })

    # -- résumé IA -----------------------------------------------------------
    output[[oid("analytics_summary")]] <- renderUI({
      bundle <- bundle_fn(); df <- bundle$data; meta <- bundle$meta
      if (nrow(df)==0) return(p("Chargez des données."))
      score_mean <- if(all(is.na(df$score_analytique))) NA_real_ else round(mean(df$score_analytique,na.rm=TRUE),1)
      indic_meta <- meta[meta$is_indicator,,drop=FALSE]
      rates <- if(nrow(indic_meta)>0) bind_rows(lapply(seq_len(nrow(indic_meta)),function(i){
        col  <- indic_meta$col_id[i]
        vals <- if(col %in% names(df)) vapply(df[[col]],score_value_generic,numeric(1)) else numeric(0)
        vals <- vals[!is.na(vals)]
        if(length(vals)==0) return(NULL)
        data.frame(label=indic_meta$label[i],rate=round(mean(vals)*100,1))
      })) else data.frame()
      strengths  <- if(nrow(rates)>0) head(rates[order(-rates$rate),,drop=FALSE],3) else data.frame()
      weaknesses <- if(nrow(rates)>0) head(rates[order(rates$rate),,drop=FALSE],3)  else data.frame()
      comp <- completion_from_bundle(df,meta)
      tagList(
        fluidRow(
          column(6, h4("Points forts",style="color:#27AE60;"),
            if(!is.na(score_mean)) p(sprintf("Score moyen : %.1f/10",score_mean)),
            if(nrow(strengths)>0) tags$ul(lapply(seq_len(nrow(strengths)),function(i)
              tags$li(sprintf("%s : %.1f%%",strengths$label[i],strengths$rate[i]))))),
          column(6, h4("Points d'attention",style="color:#C8102E;"),
            if(nrow(weaknesses)>0) tags$ul(lapply(seq_len(nrow(weaknesses)),function(i)
              tags$li(sprintf("%s : %.1f%%",weaknesses$label[i],weaknesses$rate[i])))),
            if(nrow(comp)>0) p(sprintf("Section la moins complète : %s (%.1f%%)",
              comp$section[which.min(comp$taux)],min(comp$taux,na.rm=TRUE))))
        ),
        p(style="margin-top:12px;",sprintf("Analyse sur %d réponses. Score moyen : %s.",
          nrow(df), if(is.na(score_mean)) "N/A" else paste0(score_mean,"/10")))
      )
    })

    # -- graphe unique -------------------------------------------------------
    output[[oid("analytics_plot_message")]] <- renderUI({
      bundle <- bundle_fn(); df <- bundle$data
      plot_var  <- input[[iid("analytics_plot_var")]]
      plot_type <- input[[iid("analytics_plot_type")]]
      if (nrow(df)==0||is.null(plot_var)||plot_var=="") return(p(class="hint","Choisissez une variable."))
      catalog <- make_plot_catalog(bundle)
      spec <- catalog[catalog$id==plot_var,,drop=FALSE]
      if (nrow(spec)==0) return(NULL)
      if (plot_type %in% c("histogram","boxplot") && spec$kind[1]!="numeric")
        return(div(class="hint","Ce type de graphe nécessite une variable numérique."))
      vals_chr <- trimws(as.character(if(plot_var=="score_analytique") df$score_analytique else df[[plot_var]]))
      if (plot_type=="pie" && length(unique(vals_chr[!is.na(vals_chr)]))>10)
        return(div(class="hint","Trop de modalités pour un graphe en secteur."))
      NULL
    })

    output[[oid("analytics_single_plot")]] <- renderPlotly({
      bundle <- bundle_fn(); df <- bundle$data
      plot_var  <- input[[iid("analytics_plot_var")]]; req(!is.null(plot_var),plot_var!="")
      plot_type <- input[[iid("analytics_plot_type")]]; req(!is.null(plot_type))
      catalog   <- make_plot_catalog(bundle)
      spec <- catalog[catalog$id==plot_var,,drop=FALSE]; req(nrow(spec)>0)
      kind <- spec$kind[1]
      vals <- if(plot_var=="score_analytique") df$score_analytique else df[[plot_var]]
      label <- spec$label[1]

      if (kind=="numeric") {
        num_vals <- suppressWarnings(as.numeric(as.character(vals))); num_vals <- num_vals[!is.na(num_vals)]; req(length(num_vals)>0)
        if (plot_type=="histogram")
          return(plotly::plot_ly(x=num_vals,type="histogram",marker=list(color="#245c7c")) %>%
            plotly::layout(xaxis=list(title=label),yaxis=list(title="Fréquence")))
        if (plot_type=="boxplot")
          return(plotly::plot_ly(y=num_vals,type="box",name=label,marker=list(color="#e6a700")) %>%
            plotly::layout(yaxis=list(title=label)))
        return(NULL)
      }
      cat_vals <- trimws(as.character(vals)); cat_vals <- cat_vals[!is.na(cat_vals)&cat_vals!=""]; req(length(cat_vals)>0)
      counts <- as.data.frame(table(cat_vals),stringsAsFactors=FALSE); names(counts) <- c("x","n")
      counts <- counts[order(-counts$n),,drop=FALSE]
      if (plot_type=="bar")
        return(plotly::plot_ly(counts,x=~reorder(x,n),y=~n,type="bar",marker=list(color="#245c7c")) %>%
          plotly::layout(xaxis=list(title=label,categoryorder="total ascending"),yaxis=list(title="Fréquence")))
      if (plot_type=="pie"&&nrow(counts)<=10)
        return(plotly::plot_ly(counts,labels=~x,values=~n,type="pie",textinfo="label+percent"))
      NULL
    })

    # -- tableau croisé ------------------------------------------------------
    output[[oid("analytics_crosstab")]] <- renderDT({
      bundle <- bundle_fn(); df <- bundle$data; meta <- bundle$meta
      row_var  <- input[[iid("analytics_table_row")]];  req(!is.null(row_var),row_var!="")
      col_var  <- input[[iid("analytics_table_col")]];  req(!is.null(col_var),col_var!="")
      split_var<- input[[iid("analytics_table_split")]]%||%""
      mode     <- input[[iid("analytics_table_mode")]]%||%"count"
      req(row_var %in% names(df), col_var %in% names(df))

      build_tbl <- function(dfs, split_lbl=NULL) {
        dfs <- dfs[!is.na(dfs[[row_var]])&dfs[[row_var]]!=""&!is.na(dfs[[col_var]])&dfs[[col_var]]!="",,drop=FALSE]
        if (nrow(dfs)==0) return(NULL)
        tab <- table(dfs[[row_var]],dfs[[col_var]]); if(any(dim(tab)==0)) return(NULL)
        vals <- switch(mode,
          row_pct    = round(prop.table(tab,1)*100,1),
          col_pct    = round(prop.table(tab,2)*100,1),
          global_pct = round(prop.table(tab)*100,1),
          unclass(tab))
        fmt <- if(mode=="count") function(v) as.character(v) else function(v) paste0(format(v,nsmall=1,trim=TRUE),"%")
        out <- as.data.frame.matrix(matrix(fmt(vals),nrow=nrow(vals),dimnames=dimnames(vals)),stringsAsFactors=FALSE)
        out <- data.frame(Modalite=rownames(out),out,row.names=NULL,check.names=FALSE)
        names(out)[1] <- get_meta_label(meta,row_var)
        if(!is.null(split_lbl)) out <- data.frame(`Sous-groupe`=split_lbl,out,check.names=FALSE)
        out
      }
      if (split_var!="" && split_var %in% names(df)) {
        svs <- unique(df[[split_var]]); svs <- svs[!is.na(svs)&svs!=""]
        tbls <- Filter(Negate(is.null),lapply(svs,function(sv) build_tbl(df[df[[split_var]]==sv,,drop=FALSE],sv)))
        out <- if(length(tbls)==0) data.frame(Message="Pas de données.") else bind_rows(tbls)
      } else {
        out <- build_tbl(df); if(is.null(out)) out <- data.frame(Message="Pas de données.")
      }
      datatable(out,rownames=FALSE,options=list(scrollX=TRUE,pageLength=20))
    })

    # -- gtsummary --- désactivé sur cloud (V8 non disponible sur shinyapps.io)
    output[[oid("analytics_gtsummary_message")]] <- renderUI({
      div(class="hint-text", style="padding:12px;",
          "⚠ Tableau de synthèse non disponible dans la version en ligne.",
          "Utilisez la version Desktop pour cette fonctionnalité.")
    })
    output[[oid("analytics_gtsummary_table")]] <- renderDT({
      req(FALSE)  # désactivé sur cloud
      bundle  <- bundle_fn(); df <- bundle$data; meta <- bundle$meta
      by_var  <- input[[iid("analytics_gtsummary_by")]];  req(!is.null(by_var),by_var!="")
      vars    <- input[[iid("analytics_gtsummary_vars")]]%||%character(0); req(length(vars)>0)
      vars <- setdiff(intersect(vars,names(df)),by_var); req(length(vars)>0)
      tbl_df <- df[,c(by_var,vars),drop=FALSE]
      for (col in names(tbl_df)) { v<-trimws(as.character(tbl_df[[col]])); v[v==""]=NA_character_; tbl_df[[col]]=v }
      tbl_df <- tbl_df[!is.na(tbl_df[[by_var]])&tbl_df[[by_var]]!="",,drop=FALSE]
      req(nrow(tbl_df)>=5, length(unique(tbl_df[[by_var]]))>=2)
      for (col in vars) {
        mr  <- meta[meta$col_id==col,,drop=FALSE]
        num <- suppressWarnings(as.numeric(tbl_df[[col]]))
        if (nrow(mr)>0&&mr$type[1] %in% c("radio","dropdown","likert","checkbox"))
          tbl_df[[col]] <- factor(tbl_df[[col]])
        else if (all(!is.na(num[!is.na(tbl_df[[col]])])))
          tbl_df[[col]] <- num
        else tbl_df[[col]] <- factor(tbl_df[[col]])
      }
      tbl_df[[by_var]] <- factor(tbl_df[[by_var]])
      tbl <- tryCatch(gtsummary::tbl_summary(tbl_df,by=tidyselect::all_of(by_var),
        include=tidyselect::all_of(vars),missing="ifany") %>% gtsummary::add_p(), error=function(e) NULL)
      req(!is.null(tbl))
      tbl_t <- tryCatch(gtsummary::as_tibble(tbl,col_labels=TRUE),error=function(e) NULL)
      req(!is.null(tbl_t),nrow(tbl_t)>0)
      datatable(tbl_t,rownames=FALSE,options=list(scrollX=TRUE,pageLength=20))
    })

    # -- bivariée + test ─────────────────────────────────────────────────────
    output[[oid("analytics_bivariate_container")]] <- renderUI({
      pt <- input[[iid("analytics_compare_plot_type")]]%||%"stacked"
      if (identical(pt,"mosaic"))      plotOutput(oid("analytics_bivariate_mosaic"),height="520px")
      else if (identical(pt,"association")) plotOutput(oid("analytics_bivariate_assoc"),height="520px")
      else plotlyOutput(oid("analytics_bivariate_plot"),height="520px")
    })

    output[[oid("analytics_bivariate_plot")]] <- renderPlotly({
      bundle  <- bundle_fn(); df <- bundle$data; meta <- bundle$meta
      row_var <- input[[iid("analytics_compare_row")]]; req(!is.null(row_var),row_var!="",row_var %in% names(df))
      col_var <- input[[iid("analytics_compare_col")]]; req(!is.null(col_var),col_var!="",col_var %in% names(df))
      pt      <- input[[iid("analytics_compare_plot_type")]]%||%"stacked"; req(!identical(pt,"mosaic"),!identical(pt,"association"))
      df_f <- df[!is.na(df[[row_var]])&df[[row_var]]!=""&!is.na(df[[col_var]])&df[[col_var]]!="",,drop=FALSE]
      req(nrow(df_f)>0)
      agg <- df_f %>% group_by(.data[[row_var]],.data[[col_var]]) %>% summarise(n=n(),.groups="drop") %>%
        group_by(.data[[row_var]]) %>% mutate(pct=round(n/sum(n)*100,1)) %>% ungroup()
      colnames(agg)[1:2] <- c("var_x","var_y")
      agg$var_x <- truncate_label(agg$var_x,28); agg$var_y <- truncate_label(agg$var_y,28)
      mods <- unique(agg$var_y); p <- plotly::plot_ly()
      for (i in seq_along(mods)) {
        d <- agg[agg$var_y==mods[i],,drop=FALSE]
        p <- plotly::add_bars(p,x=d$var_x,y=d$pct,name=mods[i],
          marker=list(color=COULEURS_PALETTE[(i-1)%%length(COULEURS_PALETTE)+1]))
      }
      p %>% plotly::layout(barmode="stack",yaxis=list(title="%",range=c(0,100)),
        xaxis=list(title=get_meta_label(meta,row_var)))
    })

    output[[oid("analytics_bivariate_mosaic")]] <- renderPlot({
      bundle  <- bundle_fn(); df <- bundle$data; meta <- bundle$meta
      row_var <- input[[iid("analytics_compare_row")]]; req(!is.null(row_var),row_var!="",row_var %in% names(df))
      col_var <- input[[iid("analytics_compare_col")]]; req(!is.null(col_var),col_var!="",col_var %in% names(df))
      req(identical(input[[iid("analytics_compare_plot_type")]]%||%"stacked","mosaic"))
      df_f <- df[!is.na(df[[row_var]])&df[[row_var]]!=""&!is.na(df[[col_var]])&df[[col_var]]!="",,drop=FALSE]
      req(nrow(df_f)>0)
      tab <- table(truncate_label(df_f[[row_var]],24), truncate_label(df_f[[col_var]],24))
      graphics::mosaicplot(tab,shade=TRUE,color=COULEURS_PALETTE,main="",
        xlab=get_meta_label(meta,row_var),ylab=get_meta_label(meta,col_var),las=2,cex.axis=0.8)
    })

    output[[oid("analytics_bivariate_assoc")]] <- renderPlot({
      bundle  <- bundle_fn(); df <- bundle$data; meta <- bundle$meta
      row_var <- input[[iid("analytics_compare_row")]]; req(!is.null(row_var),row_var!="",row_var %in% names(df))
      col_var <- input[[iid("analytics_compare_col")]]; req(!is.null(col_var),col_var!="",col_var %in% names(df))
      req(identical(input[[iid("analytics_compare_plot_type")]]%||%"stacked","association"))
      df_f <- df[!is.na(df[[row_var]])&df[[row_var]]!=""&!is.na(df[[col_var]])&df[[col_var]]!="",,drop=FALSE]
      req(nrow(df_f)>0)
      tab <- table(truncate_label(df_f[[row_var]],24),truncate_label(df_f[[col_var]],24))
      req(all(dim(tab)>=2))
      graphics::assocplot(tab,main="",xlab=get_meta_label(meta,row_var),ylab=get_meta_label(meta,col_var),col=c("#C8102E","#245c7c"))
    })

    output[[oid("analytics_test_results")]] <- renderPrint({
      bundle  <- bundle_fn(); df <- bundle$data; meta <- bundle$meta
      alpha   <- as.numeric(input[[iid("analytics_alpha")]]%||%0.05)
      row_var <- input[[iid("analytics_compare_row")]]; req(!is.null(row_var),row_var!="",row_var %in% names(df))
      col_var <- input[[iid("analytics_compare_col")]]; req(!is.null(col_var),col_var!="",col_var %in% names(df))
      df_f <- df[!is.na(df[[row_var]])&df[[row_var]]!=""&!is.na(df[[col_var]])&df[[col_var]]!="",,drop=FALSE]
      req(nrow(df_f)>=5)
      tab  <- table(df_f[[row_var]],df_f[[col_var]])
      cat("=== TEST D'ASSOCIATION ===\n")
      cat(sprintf("n = %d\n\n",nrow(df_f)))
      if (all(dim(tab)==c(2,2))&&any(tab<5)) {
        test <- fisher.test(tab); cat("Test : Fisher exact\n")
        cat(sprintf("p-value = %.5f\n",test$p.value))
      } else {
        test <- suppressWarnings(chisq.test(tab,correct=FALSE)); cat("Test : Khi-deux\n")
        cat(sprintf("X² = %.4f, ddl = %d, p-value = %.5f\n",unname(test$statistic),unname(test$parameter),test$p.value))
        n_tot <- sum(tab); min_dim <- min(dim(tab))-1
        if (min_dim>0) cat(sprintf("Cramer's V = %.4f\n",sqrt(unname(test$statistic)/(n_tot*min_dim))))
      }
      cat(sprintf("\nSeuil alpha = %.2f\n",alpha))
    })

    output[[oid("analytics_test_interpretation")]] <- renderUI({
      bundle  <- bundle_fn(); df <- bundle$data; meta <- bundle$meta
      alpha   <- as.numeric(input[[iid("analytics_alpha")]]%||%0.05)
      row_var <- input[[iid("analytics_compare_row")]]; req(!is.null(row_var),row_var!="",row_var %in% names(df))
      col_var <- input[[iid("analytics_compare_col")]]; req(!is.null(col_var),col_var!="",col_var %in% names(df))
      df_f <- df[!is.na(df[[row_var]])&df[[row_var]]!=""&!is.na(df[[col_var]])&df[[col_var]]!="",,drop=FALSE]
      req(nrow(df_f)>=5)
      tab  <- table(df_f[[row_var]],df_f[[col_var]])
      pval <- tryCatch({
        if(all(dim(tab)==c(2,2))&&any(tab<5)) fisher.test(tab)$p.value
        else suppressWarnings(chisq.test(tab,correct=FALSE)$p.value)
      }, error=function(e) NA_real_)
      req(!is.na(pval))
      rl <- get_meta_label(meta,row_var); cl <- get_meta_label(meta,col_var)
      if (pval<alpha)
        div(style="background:#D4EDDA;border:1px solid #27AE60;padding:10px;border-radius:6px;",
          tags$b("Association significative"),p(sprintf("'%s' est associé à '%s' (alpha=%.2f).",rl,cl,alpha)))
      else
        div(style="background:#F8D7DA;border:1px solid #C8102E;padding:10px;border-radius:6px;",
          tags$b("Association non significative"),p(sprintf("Pas d'association détectable entre '%s' et '%s' (alpha=%.2f).",rl,cl,alpha)))
    })

    # -- profils -------------------------------------------------------------
    output[[oid("analytics_profile_summary_table")]] <- renderDT({
      bundle  <- bundle_fn()
      grp     <- input[[iid("analytics_profile_group")]]%||%""
      profile <- build_profile_bundle(bundle$data,bundle$meta,grp)
      if (is.null(profile)) return(datatable(data.frame(Message="Sélectionne une variable de groupe."),options=list(dom="t"),rownames=FALSE))
      datatable(profile$summary,rownames=FALSE,options=list(dom="t",scrollX=TRUE))
    })
    output[[oid("analytics_profile_section_table")]] <- renderDT({
      bundle  <- bundle_fn()
      grp     <- input[[iid("analytics_profile_group")]]%||%""
      profile <- build_profile_bundle(bundle$data,bundle$meta,grp)
      if (is.null(profile)) return(datatable(data.frame(Message="Pas de scores."),options=list(dom="t"),rownames=FALSE))
      datatable(profile$section,rownames=FALSE,options=list(dom="t",scrollX=TRUE))
    })
    output[[oid("analytics_profile_heatmap")]] <- renderPlotly({
      bundle  <- bundle_fn()
      grp     <- input[[iid("analytics_profile_group")]]%||%""
      profile <- build_profile_bundle(bundle$data,bundle$meta,grp)
      mat <- get_profile_plot_matrix(profile,input[[iid("analytics_profile_view_mode")]]%||%"section")
      req(!is.null(mat),nrow(mat)>0,ncol(mat)>0)
      plotly::plot_ly(x=colnames(mat),y=rownames(mat),z=mat,type="heatmap",
        colors=colorRamp(c("#f7fbff","#6baed6","#08306b"))) %>%
        plotly::layout(xaxis=list(title=""),yaxis=list(title="Groupes"))
    })
    output[[oid("analytics_profile_radar")]] <- renderPlotly({
      bundle  <- bundle_fn()
      grp     <- input[[iid("analytics_profile_group")]]%||%""
      profile <- build_profile_bundle(bundle$data,bundle$meta,grp)
      mat <- get_profile_plot_matrix(profile,input[[iid("analytics_profile_view_mode")]]%||%"section")
      req(!is.null(mat),nrow(mat)>0,ncol(mat)>0)
      axes <- colnames(mat); p <- plotly::plot_ly(type="scatterpolar",fill="toself")
      for (i in seq_len(nrow(mat))) {
        vals <- suppressWarnings(as.numeric(mat[i,])); vals[is.na(vals)] <- 0
        p <- plotly::add_trace(p,r=c(vals,vals[1]),theta=c(truncate_label(axes,28),truncate_label(axes[1],28)),
          name=rownames(mat)[i],line=list(color=COULEURS_PALETTE[(i-1)%%length(COULEURS_PALETTE)+1]))
      }
      p %>% plotly::layout(polar=list(radialaxis=list(visible=TRUE,range=c(0,100),ticksuffix="%")))
    })
    output[[oid("analytics_profile_table")]] <- renderDT({
      bundle  <- bundle_fn()
      grp     <- input[[iid("analytics_profile_group")]]%||%""
      profile <- build_profile_bundle(bundle$data,bundle$meta,grp)
      if (is.null(profile)) return(datatable(data.frame(Message="Sélectionne un groupe."),options=list(dom="t"),rownames=FALSE))
      datatable(profile$detailed,rownames=FALSE,options=list(dom="t",scrollX=TRUE,pageLength=15))
    })

    # -- avancé : comparaison ------------------------------------------------
    output[[oid("advanced_compare_table")]] <- renderDT({
      bundle  <- bundle_fn(); df <- bundle$data; meta <- bundle$meta
      gvar <- input[[iid("advanced_compare_group")]];  req(!is.null(gvar),gvar!="",gvar %in% names(df))
      tvar <- input[[iid("advanced_compare_target")]]; req(!is.null(tvar),tvar!="",tvar %in% names(df))
      df_f <- df[!is.na(df[[gvar]])&df[[gvar]]!=""&!is.na(df[[tvar]])&df[[tvar]]!="",,drop=FALSE]
      req(nrow(df_f)>0)
      mr <- meta[meta$col_id==tvar,,drop=FALSE]
      kind <- if(tvar=="score_analytique") "numeric" else if(nrow(mr)>0) detect_plot_variable_kind(df[[tvar]],mr$type[1]) else detect_plot_variable_kind(df[[tvar]])
      if (identical(kind,"numeric")) {
        df_f$.num <- suppressWarnings(as.numeric(as.character(df_f[[tvar]]))); df_f <- df_f[!is.na(df_f$.num),,drop=FALSE]
        out <- df_f %>% group_by(.data[[gvar]]) %>% summarise(Effectif=n(),Moyenne=round(mean(.num),2),Médiane=round(median(.num),2),`Écart-type`=round(sd(.num),2),.groups="drop")
        names(out)[1] <- get_meta_label(meta,gvar)
      } else {
        out <- df_f %>% count(.data[[gvar]],.data[[tvar]],name="Effectif") %>%
          group_by(.data[[gvar]]) %>% mutate(`% groupe`=round(Effectif/sum(Effectif)*100,1)) %>% ungroup()
        names(out)[1:2] <- c(get_meta_label(meta,gvar),get_meta_label(meta,tvar))
      }
      datatable(out,rownames=FALSE,options=list(dom="t",scrollX=TRUE,pageLength=20))
    })
    output[[oid("advanced_compare_text")]] <- renderPrint({
      bundle  <- bundle_fn(); df <- bundle$data; meta <- bundle$meta
      gvar <- input[[iid("advanced_compare_group")]];  req(!is.null(gvar),gvar!="",gvar %in% names(df))
      tvar <- input[[iid("advanced_compare_target")]]; req(!is.null(tvar),tvar!="",tvar %in% names(df))
      df_f <- df[!is.na(df[[gvar]])&df[[gvar]]!=""&!is.na(df[[tvar]])&df[[tvar]]!="",,drop=FALSE]
      req(nrow(df_f)>=5)
      mr   <- meta[meta$col_id==tvar,,drop=FALSE]
      kind <- if(tvar=="score_analytique") "numeric" else if(nrow(mr)>0) detect_plot_variable_kind(df[[tvar]],mr$type[1]) else detect_plot_variable_kind(df[[tvar]])
      cat(sprintf("n exploitable : %d\n",nrow(df_f)))
      if (identical(kind,"numeric")) {
        df_f$.num <- suppressWarnings(as.numeric(as.character(df_f[[tvar]]))); df_f <- df_f[!is.na(df_f$.num),,drop=FALSE]
        test_df <- data.frame(g=factor(df_f[[gvar]]),t=df_f$.num)
        if (length(unique(test_df$g))==2) {
          res <- tryCatch(t.test(t~g,data=test_df),error=function(e) NULL)
          if(!is.null(res)) { cat("Test t de Student\n"); cat(sprintf("p-value = %.5f\n",res$p.value)) }
        } else {
          fit <- tryCatch(aov(t~g,data=test_df),error=function(e) NULL)
          if(!is.null(fit)) { cat("ANOVA\n"); cat(sprintf("p-value = %.5f\n",summary(fit)[[1]][["Pr(>F)"]][1])) }
        }
      } else {
        tab  <- table(df_f[[gvar]],df_f[[tvar]])
        test <- tryCatch(if(all(dim(tab)==c(2,2))&&any(tab<5)) fisher.test(tab) else suppressWarnings(chisq.test(tab,correct=FALSE)),error=function(e) NULL)
        if (!is.null(test)) cat(sprintf("p-value = %.5f\n",test$p.value))
      }
    })

    # -- avancé : composites -------------------------------------------------
    output[[oid("advanced_composite_table")]] <- renderDT({
      bundle <- bundle_fn()
      gvar   <- input[[iid("advanced_composite_group")]];    req(!is.null(gvar),gvar!="")
      secs   <- input[[iid("advanced_composite_sections")]]%||%character(0)
      prof   <- build_section_scores_by_group(bundle$data,bundle$meta,gvar,secs)
      if (is.null(prof)) return(datatable(data.frame(Message="Sélectionne un groupe et des sections."),options=list(dom="t"),rownames=FALSE))
      datatable(prof,rownames=FALSE,options=list(scrollX=TRUE,pageLength=12))
    })
    output[[oid("advanced_composite_plot")]] <- renderPlotly({
      bundle <- bundle_fn()
      gvar   <- input[[iid("advanced_composite_group")]]; req(!is.null(gvar),gvar!="")
      secs   <- input[[iid("advanced_composite_sections")]]%||%character(0)
      prof   <- build_section_scores_by_group(bundle$data,bundle$meta,gvar,secs); req(!is.null(prof),nrow(prof)>0)
      plotly::plot_ly(prof,x=~Groupe,y=~`Score composite (%)`,type="bar",marker=list(color="#245c7c")) %>%
        plotly::layout(yaxis=list(range=c(0,100)))
    })

    # -- avancé : régression logistique --------------------------------------
    output[[oid("advanced_logit_table")]] <- renderDT({
      req(requireNamespace("broom",quietly=TRUE))
      bundle <- bundle_fn(); df <- bundle$data; meta <- bundle$meta
      outcome <- input[[iid("advanced_logit_outcome")]];    req(!is.null(outcome),outcome!="",outcome %in% names(df))
      preds   <- input[[iid("advanced_logit_predictors")]]%||%character(0); req(length(preds)>0)
      preds <- setdiff(preds,outcome); req(length(preds)>0)
      mdl_df <- df[,c(outcome,preds),drop=FALSE]
      for (col in names(mdl_df)) { v<-trimws(as.character(mdl_df[[col]])); v[v==""]=NA_character_; mdl_df[[col]]=v }
      mdl_df <- mdl_df[complete.cases(mdl_df),,drop=FALSE]
      req(nrow(mdl_df)>=20,length(unique(mdl_df[[outcome]]))==2)
      mdl_df[[outcome]] <- factor(mdl_df[[outcome]])
      for (col in preds) mdl_df[[col]] <- factor(mdl_df[[col]])
      fit <- tryCatch(glm(as.formula(paste(outcome,"~",paste(preds,collapse="+"))),data=mdl_df,family=binomial()),error=function(e) NULL)
      req(!is.null(fit))
      td <- broom::tidy(fit,conf.int=TRUE,exponentiate=TRUE); td <- td[td$term!="(Intercept)",,drop=FALSE]
      req(nrow(td)>0)
      out <- data.frame(Terme=td$term,OR=round(td$estimate,3),`IC 2.5%`=round(td$conf.low,3),
        `IC 97.5%`=round(td$conf.high,3),`p-value`=signif(td$p.value,3),stringsAsFactors=FALSE)
      datatable(out,rownames=FALSE,options=list(scrollX=TRUE,pageLength=15))
    })
    output[[oid("advanced_logit_text")]] <- renderPrint({
      bundle <- bundle_fn(); df <- bundle$data
      outcome <- input[[iid("advanced_logit_outcome")]]%||%""; req(!is.null(outcome),outcome!="",outcome %in% names(df))
      preds   <- input[[iid("advanced_logit_predictors")]]%||%character(0); req(length(preds)>0)
      mdl_df  <- df[,c(outcome,setdiff(preds,outcome)),drop=FALSE]
      for (col in names(mdl_df)) { v<-trimws(as.character(mdl_df[[col]])); v[v==""]=NA_character_; mdl_df[[col]]=v }
      mdl_df <- mdl_df[complete.cases(mdl_df),,drop=FALSE]
      cat(sprintf("Observations exploitables : %d\n",nrow(mdl_df)))
      if (nrow(mdl_df)<20) { cat("Effectif insuffisant.\n"); return() }
      cat(sprintf("Groupes cible : %s\n",paste(unique(mdl_df[[outcome]]),collapse=" / ")))
    })

    # -- avancé : corrélation ------------------------------------------------
    output[[oid("advanced_corr_plot")]] <- renderPlotly({
      bundle <- bundle_fn(); sb <- build_indicator_score_matrix(bundle$data,bundle$meta); req(!is.null(sb),ncol(sb$matrix)>=2)
      corr   <- cor(sb$matrix,use="pairwise.complete.obs")
      lbls   <- truncate_label(unname(sb$labels[colnames(corr)]),28)
      plotly::plot_ly(x=lbls,y=lbls,z=corr,type="heatmap",zmin=-1,zmax=1,
        colors=colorRamp(c("#b2182b","#f7f7f7","#2166ac"))) %>%
        plotly::layout(xaxis=list(title=""),yaxis=list(title=""))
    })
    output[[oid("advanced_corr_table")]] <- renderDT({
      bundle <- bundle_fn(); sb <- build_indicator_score_matrix(bundle$data,bundle$meta)
      if (is.null(sb)||ncol(sb$matrix)<2)
        return(datatable(data.frame(Message="Pas assez d'indicateurs numériques."),options=list(dom="t"),rownames=FALSE))
      corr  <- cor(sb$matrix,use="pairwise.complete.obs")
      df_c  <- as.data.frame(as.table(corr),stringsAsFactors=FALSE); names(df_c) <- c("v1","v2","r")
      df_c  <- df_c[df_c$v1!=df_c$v2,,drop=FALSE]
      df_c$key <- apply(df_c[,c("v1","v2")],1,function(x) paste(sort(x),collapse="___"))
      df_c  <- df_c[!duplicated(df_c$key),,drop=FALSE]
      df_c$`Indicateur 1` <- unname(sb$labels[df_c$v1])
      df_c$`Indicateur 2` <- unname(sb$labels[df_c$v2])
      df_c$Corrélation <- round(df_c$r,3)
      df_c$Force <- cut(abs(df_c$r),breaks=c(-Inf,.2,.4,.6,.8,Inf),labels=c("Très faible","Faible","Modérée","Forte","Très forte"))
      out <- head(df_c[order(-abs(df_c$r)),c("Indicateur 1","Indicateur 2","Corrélation","Force")],30)
      datatable(out,rownames=FALSE,options=list(scrollX=TRUE,pageLength=15))
    })

    # -- exports -------------------------------------------------------------
    output[[oid("download_analytics_csv")]] <- downloadHandler(
      filename = function() paste0("dataset_analytique_",pfx,Sys.Date(),".csv"),
      content  = function(file) {
        bundle <- bundle_fn()
        write.csv(bundle$data,file,row.names=FALSE,na="")
      }
    )
    output[[oid("download_scores_csv")]] <- downloadHandler(
      filename = function() paste0("scores_sections_",pfx,Sys.Date(),".csv"),
      content  = function(file) {
        bundle <- bundle_fn()
        gvar   <- input[[iid("advanced_composite_group")]]%||%""
        secs   <- input[[iid("advanced_composite_sections")]]%||%character(0)
        out    <- build_section_scores_by_group(bundle$data,bundle$meta,gvar,secs)
        write.csv(out%||%data.frame(),file,row.names=FALSE,na="")
      }
    )
  } # fin setup_analytics

  # ── Instancier Analytics INTERNE (pfx="") et EXTERNE (pfx="ext_") ────────
  setup_analytics(analytics_bundle, pfx="")
  setup_analytics(ext_bundle,       pfx="ext_")

  # observer alpha global partagé avec ext_ (même widget dans les deux onglets)
  observe({
    alpha_val <- input$analytics_alpha%||%0.05
    updateRadioButtons(session,"ext_analytics_alpha",selected=alpha_val)
  })
  observe({
    alpha_val <- input$ext_analytics_alpha%||%0.05
    updateRadioButtons(session,"analytics_alpha",selected=alpha_val)
  })

} # fin server
