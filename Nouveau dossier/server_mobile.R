# ============================================================================
# server_mobile.R  — Lestrade Forms Mobile
# Logique : collecte hors-ligne → SQLite local → sync Google Drive
# ============================================================================

library(shiny); library(shinyjs)
library(jsonlite); library(dplyr); library(RSQLite); library(DBI)

# ── Chemin de la base locale mobile ─────────────────────────────────────────
MOBILE_DB_PATH    <- "mobile_offline.db"
DRIVE_TOKEN_PATH  <- ".secrets_mobile"
DESKTOP_TOKEN_PATH <- ".secrets_desktop"
DRIVE_SHEET_KEY   <- "lestrade_forms_sheet_id.txt"

# ── Multi-comptes Drive ──────────────────────────────────────────────────────

# Retourne tous les emails des tokens en cache (Desktop + Mobile)
list_cached_accounts <- function() {
  files <- c(
    list.files(DESKTOP_TOKEN_PATH, full.names=TRUE),
    list.files(DRIVE_TOKEN_PATH,   full.names=TRUE)
  )
  # Le nom de fichier gargle = hash_email — extraire l'email
  emails <- sub("^[^_]+_", "", basename(files))
  emails <- emails[nchar(emails) > 3]
  unique(emails)
}

# Connexion avec un email précis (silencieuse si token en cache)
connect_drive_account <- function(email=NULL) {
  tryCatch({
    if (!requireNamespace("googlesheets4", quietly=TRUE) ||
        !requireNamespace("gargle",        quietly=TRUE))
      stop("Packages requis : install.packages(c('googledrive','googlesheets4','gargle'))")

    options(gargle_oob_default = FALSE)

    # Chercher le cache qui contient ce token
    cache <- if (length(list.files(DESKTOP_TOKEN_PATH)) > 0)
               DESKTOP_TOKEN_PATH else DRIVE_TOKEN_PATH
    options(gargle_oauth_cache = cache)

    # email=NULL ou TRUE → premier compte du cache ; email=adresse → compte spécifique
    target_email <- if (is.null(email)) TRUE else email
    googledrive::drive_auth(cache=cache, email=target_email)
    googlesheets4::gs4_auth(token=googledrive::drive_token())

    # Récupérer l'email réellement connecté
    actual_email <- tryCatch(
      googledrive::drive_user()$emailAddress,
      error=function(e) as.character(target_email)
    )
    list(ok=TRUE, email=actual_email)
  }, error=function(e) { message(e$message); list(ok=FALSE, email=NULL) })
}

# Ajouter un nouveau compte (ouvre le navigateur OAuth)
add_drive_account <- function() {
  tryCatch({
    options(gargle_oob_default=FALSE, gargle_oauth_cache=DRIVE_TOKEN_PATH)
    googledrive::drive_auth(cache=DRIVE_TOKEN_PATH, email=FALSE)  # email=FALSE → toujours navigateur
    googlesheets4::gs4_auth(token=googledrive::drive_token())
    actual_email <- tryCatch(
      googledrive::drive_user()$emailAddress,
      error=function(e) "Nouveau compte"
    )
    list(ok=TRUE, email=actual_email)
  }, error=function(e) list(ok=FALSE, msg=e$message))
}

# Déconnecter un compte (supprimer son token du cache)
remove_drive_account <- function(email) {
  tryCatch({
    files <- c(
      list.files(DESKTOP_TOKEN_PATH, full.names=TRUE),
      list.files(DRIVE_TOKEN_PATH,   full.names=TRUE)
    )
    to_del <- files[grepl(email, basename(files), fixed=TRUE)]
    file.remove(to_del)
    TRUE
  }, error=function(e) FALSE)
}

# Compatibilité avec l'ancien code
connect_drive <- function() {
  res <- connect_drive_account()
  isTRUE(res$ok)
}

drive_is_connected <- function() {
  tryCatch({
    if (!requireNamespace("googledrive", quietly=TRUE)) return(FALSE)
    has_desktop <- length(list.files(DESKTOP_TOKEN_PATH)) > 0
    has_mobile  <- length(list.files(DRIVE_TOKEN_PATH))   > 0
    if (!has_desktop && !has_mobile) return(FALSE)
    googledrive::drive_has_token()
  }, error=function(e) FALSE)
}
init_mobile_db <- function() {
  con <- dbConnect(SQLite(), MOBILE_DB_PATH)
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS reponses_offline (
      id               INTEGER PRIMARY KEY AUTOINCREMENT,
      questionnaire_id INTEGER NOT NULL,
      questionnaire_nom TEXT,
      enqueteur        TEXT,
      horodateur       DATETIME DEFAULT CURRENT_TIMESTAMP,
      donnees_json     TEXT NOT NULL,
      statut           TEXT DEFAULT 'pending',
      synced_at        DATETIME,
      drive_account    TEXT
    )
  ")
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS config (
      cle   TEXT PRIMARY KEY,
      valeur TEXT
    )
  ")
  # Migration : ajouter drive_account si absent (DB existante)
  cols <- dbGetQuery(con, "PRAGMA table_info(reponses_offline)")$name
  if (!"drive_account" %in% cols)
    dbExecute(con, "ALTER TABLE reponses_offline ADD COLUMN drive_account TEXT")
  dbDisconnect(con)
}

# ── CRUD offline ─────────────────────────────────────────────────────────────
save_offline_reponse <- function(quest_id, quest_nom, enqueteur, donnees_json, drive_account=NULL) {
  con <- dbConnect(SQLite(), MOBILE_DB_PATH)
  dbExecute(con, "
    INSERT INTO reponses_offline
      (questionnaire_id, questionnaire_nom, enqueteur, donnees_json, drive_account)
    VALUES (?, ?, ?, ?, ?)
  ", list(as.integer(quest_id), quest_nom, enqueteur, donnees_json,
          drive_account %||% NA_character_))
  dbDisconnect(con)
}

get_pending_reponses <- function(drive_account=NULL) {
  con <- dbConnect(SQLite(), MOBILE_DB_PATH)
  if (!is.null(drive_account)) {
    res <- dbGetQuery(con,
      "SELECT * FROM reponses_offline WHERE statut='pending' AND drive_account=? ORDER BY horodateur DESC",
      list(drive_account))
  } else {
    res <- dbGetQuery(con,
      "SELECT * FROM reponses_offline WHERE statut='pending' ORDER BY horodateur DESC")
  }
  dbDisconnect(con); res
}

get_all_offline_reponses <- function() {
  con <- dbConnect(SQLite(), MOBILE_DB_PATH)
  res <- dbGetQuery(con, "SELECT * FROM reponses_offline ORDER BY horodateur DESC LIMIT 50")
  dbDisconnect(con); res
}

mark_synced <- function(ids) {
  if (length(ids) == 0) return(invisible(NULL))
  con <- dbConnect(SQLite(), MOBILE_DB_PATH)
  dbExecute(con,
    sprintf("UPDATE reponses_offline SET statut='synced', synced_at=datetime('now') WHERE id IN (%s)",
            paste(ids, collapse=",")))
  dbDisconnect(con)
}

get_config <- function(cle) {
  con <- dbConnect(SQLite(), MOBILE_DB_PATH)
  res <- dbGetQuery(con, "SELECT valeur FROM config WHERE cle=?", list(cle))
  dbDisconnect(con)
  if (nrow(res) == 0) NULL else res$valeur[1]
}

set_config <- function(cle, valeur) {
  con <- dbConnect(SQLite(), MOBILE_DB_PATH)
  dbExecute(con, "INSERT OR REPLACE INTO config (cle, valeur) VALUES (?,?)", list(cle, valeur))
  dbDisconnect(con)
}


get_or_create_drive_sheet <- function() {
  # Cherche l'ID sauvegardé localement
  saved_id <- get_config("drive_sheet_id")
  if (!is.null(saved_id) && nchar(saved_id) > 10) {
    return(saved_id)
  }
  # Cherche une Sheet existante sur Drive
  existing <- tryCatch(
    googlesheets4::gs4_find("Lestrade_Forms_Reponses"),
    error = function(e) NULL
  )
  if (!is.null(existing) && nrow(existing) > 0) {
    id <- as.character(existing$id[1])
    set_config("drive_sheet_id", id)
    return(id)
  }
  # Crée une nouvelle Sheet
  ss <- googlesheets4::gs4_create(
    "Lestrade_Forms_Reponses",
    sheets = list(
      reponses = data.frame(
        id               = integer(),
        questionnaire_id = integer(),
        questionnaire_nom= character(),
        enqueteur        = character(),
        horodateur       = character(),
        donnees_json     = character(),
        stringsAsFactors = FALSE
      )
    )
  )
  id <- as.character(ss)
  set_config("drive_sheet_id", id)
  id
}

sync_pending_to_drive <- function(active_email=NULL) {
  # Filtrer les réponses du compte actif uniquement
  pending <- get_pending_reponses(drive_account=active_email)
  if (nrow(pending) == 0) return(list(ok=TRUE, n=0, message="Rien à synchroniser."))
  sheet_id <- get_or_create_drive_sheet()
  to_push  <- pending[, c("id","questionnaire_id","questionnaire_nom","enqueteur","horodateur","donnees_json")]
  tryCatch({
    googlesheets4::sheet_append(sheet_id, data=to_push, sheet="reponses")
    mark_synced(pending$id)
    list(ok=TRUE, n=nrow(pending),
         message=sprintf("%d réponse(s) synchronisée(s) avec Google Drive.", nrow(pending)))
  }, error=function(e) {
    list(ok=FALSE, n=0, message=paste("Erreur Drive:", e$message))
  })
}

# ── Détection réseau simple ───────────────────────────────────────────────────
check_network <- function() {
  tryCatch({
    con <- url("https://www.google.com", open="rb")
    close(con)
    TRUE
  }, error=function(e) FALSE, warning=function(w) FALSE)
}

# ============================================================================
# SERVER
# ============================================================================
server_mobile <- function(input, output, session) {

  init_mobile_db()

  # Lire le premier questionnaire disponible au démarrage
  .init_quest <- tryCatch({
    q <- get_all_questionnaires()
    if (nrow(q) > 0) as.integer(q$id[1]) else NULL
  }, error = function(e) NULL)

  rv <- reactiveValues(
    network_ok    = FALSE,
    drive_ok      = FALSE,
    active_email  = get_config("active_drive_account") %||% NULL,
    refresh_local = 0L,
    current_quest = .init_quest,
    enqueteur     = get_config("enqueteur_nom") %||% ""
  )

  # ── Vérification réseau — différée de 2s pour ne pas bloquer le 1er render ──
  # check_network() ouvre une connexion TCP bloquante (google.com).
  # Sans délai, Shiny est gelé avant d'afficher quoi que ce soit.
  network_timer <- reactiveVal(0L)

  shinyjs::delay(2000, { network_timer(1L) })

  observe({
    nt <- network_timer(); req(nt > 0)
    rv$network_ok <- check_network()
    shinyjs::delay(15000, { network_timer(network_timer() + 1L) })
  })

  # ── Auto-connexion Drive au démarrage — différée pour ne pas bloquer l'UI ──
  # connect_drive() fait des appels réseau bloquants (gargle/googledrive).
  # On attend 1500ms que l'UI soit affichée avant de tenter la connexion.
  shinyjs::delay(1500, {
    has_desktop <- length(list.files(DESKTOP_TOKEN_PATH)) > 0
    has_mobile  <- length(list.files(DRIVE_TOKEN_PATH))   > 0
    if (has_desktop || has_mobile) {
      # Restaurer le compte actif sauvegardé, sinon prendre le premier disponible
      saved_email <- isolate(rv$active_email)
      result      <- connect_drive_account(saved_email)
      if (isTRUE(result$ok)) {
        rv$drive_ok    <- TRUE
        rv$active_email <- result$email
        set_config("active_drive_account", result$email)
      }
    }
  })

  # ── Card statut accueil ──────────────────────────────────────────────────
  # ── Textes statut — plus de renderUI pour les éléments clés ────────────────
  output$mob_network_text <- renderText({
    if (rv$network_ok) "🟢 Connecté" else "🔴 Hors-ligne"
  })

  output$mob_drive_text <- renderText({
    if (rv$drive_ok) {
      email <- rv$active_email %||% "Drive"
      # Tronquer pour la pill : garder juste la partie avant @
      short <- sub("@.*$", "", email)
      paste0("☁ ", short)
    } else "☁ Non connecté"
  })

  output$mob_drive_status_text <- renderText({
    if (rv$drive_ok) "☁ Google Drive connecté" else "☁ Drive non connecté"
  })

  output$mob_pending_text <- renderText({
    rv$refresh_local
    n <- nrow(get_pending_reponses())
    if (n > 0) sprintf("⚠ %d réponse(s) en attente de synchronisation", n) else ""
  })

  output$mob_pending_alert <- renderUI({
    rv$refresh_local
    n <- nrow(get_pending_reponses())
    if (n > 0)
      div(class="mob-card",
        style="background:#FFF8E7;border-color:#E8A020;",
        div(style="font-size:13px;color:#7A5000;",
            sprintf("⚠ %d réponse(s) en attente — allez dans Réponses pour synchroniser.", n))
      )
    else NULL
  })


  # ── Liste des comptes dans Paramètres ───────────────────────────────────
  output$mob_accounts_list_ui <- renderUI({
    rv$drive_ok  # re-render si statut change
    accounts <- list_cached_accounts()
    active   <- isolate(rv$active_email)

    if (length(accounts) == 0)
      return(p(style="font-size:13px;color:var(--text3);padding:4px 0;",
               "Aucun compte connecté."))

    tagList(lapply(accounts, function(email) {
      is_active <- !is.null(active) && email == active
      div(style="display:flex;align-items:center;gap:10px;padding:8px 0;border-bottom:1px solid var(--bord);",
        div(style=paste0("width:10px;height:10px;border-radius:50%;flex-shrink:0;background:",
                         if(is_active) "var(--teal)" else "var(--bord);")),
        div(style="flex:1;",
          div(style=paste0("font-size:13px;font-weight:", if(is_active) "600" else "400", ";"),
              email),
          if(is_active) div(style="font-size:11px;color:var(--teal);","Compte actif")
        ),
        if (!is_active)
          tags$button(
            class="mob-account-btn",
            `data-email`=email,
            style=paste0("font-size:12px;padding:5px 12px;border:1.5px solid var(--navy);",
                        "border-radius:8px;background:transparent;color:var(--navy);cursor:pointer;"),
            "Activer"
          )
      )
    }))
  })

  # ── Ajouter un compte ────────────────────────────────────────────────────
  observeEvent(input$btn_mob_add_account, {
    showNotification("Ouverture du navigateur Google...", type="message", duration=3)
    result <- add_drive_account()
    if (isTRUE(result$ok)) {
      rv$active_email <- result$email
      rv$drive_ok     <- TRUE
      set_config("active_drive_account", result$email)
      showNotification(paste0("✓ Compte ajouté : ", result$email),
                       type="message", duration=4)
    } else {
      showNotification(paste("Erreur :", result$msg %||% "inconnue"),
                       type="error", duration=6)
    }
  })

  # ── Basculer vers un compte ──────────────────────────────────────────────
  observeEvent(input$mob_switch_account, {
    email <- input$mob_switch_account
    req(!is.null(email), nchar(email) > 3)
    result <- connect_drive_account(email)
    if (isTRUE(result$ok)) {
      rv$active_email <- result$email
      rv$drive_ok     <- TRUE
      set_config("active_drive_account", result$email)
      showNotification(paste0("✓ Basculé vers : ", result$email),
                       type="message", duration=3)
    } else {
      showNotification("Échec du changement de compte.", type="error", duration=4)
    }
  })

  # ── Retirer un compte ────────────────────────────────────────────────────
  observeEvent(input$btn_mob_remove_account, {
    email <- isolate(rv$active_email)
    if (is.null(email)) {
      showNotification("Aucun compte actif à retirer.", type="warning"); return()
    }
    remove_drive_account(email)
    # Basculer vers un autre compte si disponible
    remaining <- list_cached_accounts()
    if (length(remaining) > 0) {
      res <- connect_drive_account(remaining[1])
      rv$active_email <- if(isTRUE(res$ok)) res$email else NULL
      rv$drive_ok     <- isTRUE(res$ok)
    } else {
      rv$active_email <- NULL
      rv$drive_ok     <- FALSE
    }
    set_config("active_drive_account", rv$active_email %||% "")
    showNotification(paste0("Compte retiré : ", email), type="warning", duration=3)
  })

  # ── Bouton Drive onglet Réponses (connexion rapide si aucun compte actif) ─
  observeEvent(input$btn_mob_connect_drive2, ignoreNULL=TRUE, ignoreInit=FALSE, {
    active <- isolate(rv$active_email)
    result <- connect_drive_account(active)
    rv$drive_ok <- isTRUE(result$ok)
    if (isTRUE(result$ok)) {
      rv$active_email <- result$email
      showNotification(paste0("✓ Drive connecté : ", result$email),
                       type="message", duration=3)
    } else {
      showNotification("Ajoutez un compte dans Paramètres > Comptes Google Drive.",
                       type="warning", duration=5)
    }
  })

  output$mob_drive_status <- renderUI({
    if (rv$drive_ok)
      div(class="st-pill st-ok", paste0("☁ ", rv$active_email %||% "Drive connecté"))
    else
      div(class="st-pill st-off", "☁ Non connecté")
  })

  # ── Métriques rapides ────────────────────────────────────────────────────
  output$mob_n_local <- renderText({
    rv$refresh_local
    nrow(get_pending_reponses())
  })
  output$mob_n_synced <- renderText({
    rv$refresh_local
    con <- dbConnect(SQLite(), MOBILE_DB_PATH)
    n <- dbGetQuery(con, "SELECT COUNT(*) as n FROM reponses_offline WHERE statut='synced' AND date(synced_at)=date('now')")$n
    dbDisconnect(con); n
  })

  # ── Sélecteur de questionnaire — statique dans l'UI, mis à jour ici ──────
  # Peuple les choix (dépend de refresh_local pour détecter les nouveaux imports)
  observe({
    rv$refresh_local
    quests <- get_all_questionnaires()
    if (nrow(quests) == 0) {
      updateSelectInput(session, "mob_quest_id",
                        choices = c("Aucun questionnaire disponible" = ""))
      return()
    }
    choices <- setNames(as.list(quests$id), quests$nom)
    sel     <- isolate(rv$current_quest) %||% quests$id[1]
    updateSelectInput(session, "mob_quest_id", choices=choices, selected=sel)
  })

  # Synchroniser la sélection quand rv$current_quest change (ex: import QR/UID)
  observe({
    qid <- rv$current_quest
    req(!is.null(qid))
    updateSelectInput(session, "mob_quest_id", selected=qid)
  })

  observe({
    req(input$mob_quest_id, input$mob_quest_id != "")
    rv$current_quest <- as.integer(input$mob_quest_id)
  })

  # ── Header formulaire ────────────────────────────────────────────────────
  output$mob_form_header <- renderUI({
    qid <- rv$current_quest; req(!is.null(qid))
    q <- get_questionnaire_by_id(qid)
    req(!is.null(q))
    div(
      div(style="font-weight:700;font-size:1rem;color:#0D1F35;", q$nom),
      div(style="font-size:12px;color:#8896A7;margin-top:2px;", q$description %||% "")
    )
  })

  # ── Formulaire de collecte ───────────────────────────────────────────────
  # Ne dépend QUE de rv$current_quest — isolate() sur tout le reste
  # pour éviter un re-render complet à chaque sauvegarde.
  output$mob_formulaire <- renderUI({
    rv$refresh_local  # signal de navigation
    qid <- isolate(rv$current_quest); req(!is.null(qid), qid != "")

    # Lire la DB hors réactivité (isolate) — seul qid déclenche le re-render
    full     <- isolate(get_questionnaire_full(qid))
    enq_val  <- isolate(rv$enqueteur)

    req(!is.null(full), nrow(full$sections) > 0, nrow(full$questions) > 0)

    # Parser les options JSON → toujours un vecteur character
    parse_opts <- function(o) {
      if (is.null(o) || is.na(o) || trimws(o) == "" || trimws(o) %in% c("{}", "[]"))
        return(character(0))
      raw <- tryCatch(
        fromJSON(as.character(o), simplifyVector = TRUE),
        error = function(e) character(0)
      )
      if (is.null(raw) || length(raw) == 0) character(0) else as.character(unlist(raw))
    }

    tagList(
      div(class="mob-card",
        textInput("mob_enqueteur_input", label="Nom de l'enquêteur",
                  placeholder="Votre nom", value=enq_val)
      ),
      lapply(seq_len(nrow(full$sections)), function(i) {
        sec   <- full$sections[i, ]
        sec_q <- full$questions[full$questions$section_id == sec$id, , drop=FALSE]
        if (nrow(sec_q) == 0) return(NULL)

        div(class="mob-card",
          div(class="mob-card-title", sec$nom),
          lapply(seq_len(nrow(sec_q)), function(j) {
            q    <- sec_q[j, ]
            iid  <- paste0("mob_q_", q$id)
            # Parser directement depuis la valeur de la ligne — pas de lookup d'index
            opts <- parse_opts(q$options)
            lbl  <- if (as.integer(q$obligatoire) == 1)
              div(q$texte, tags$span("*", style="color:#C0392B;margin-left:2px;"))
            else q$texte

            tryCatch(
              switch(q$type,
                text     = textInput(iid, label=lbl, placeholder="Votre réponse"),
                textarea = textAreaInput(iid, label=lbl, placeholder="Votre réponse", rows=3),
                radio    = if (length(opts) > 0)
                             radioButtons(iid, label=lbl, choices=opts, selected=character(0))
                           else textInput(iid, label=lbl, placeholder="(options manquantes)"),
                checkbox = if (length(opts) > 0)
                             checkboxGroupInput(iid, label=lbl, choices=opts)
                           else textInput(iid, label=lbl, placeholder="(options manquantes)"),
                dropdown = selectInput(iid, label=lbl,
                             choices=c("Sélectionner..."="", setNames(as.list(opts), opts))),
                likert   = radioButtons(iid, label=lbl, inline=TRUE, selected=character(0),
                             choices=c("Pas d'accord","Plutôt pas","Neutre","Plutôt d'accord","Tout à fait")),
                email    = textInput(iid, label=lbl, placeholder="nom@exemple.org"),
                phone    = textInput(iid, label=lbl, placeholder="+221770000000"),
                date     = dateInput(iid, label=lbl, value=Sys.Date(), format="dd/mm/yyyy"),
                textInput(iid, label=lbl, placeholder="Votre réponse")
              ),
              error = function(e) div(style="color:red;font-size:12px;",
                paste("Erreur question", q$id, ":", e$message))
            )
          })
        )
      })
    )
  })

  # ── Démarrer collecte depuis accueil ────────────────────────────────────
  observeEvent(input$btn_mob_start, ignoreNULL=TRUE, ignoreInit=FALSE, {
    session$sendCustomMessage('goTab', 'formulaire')
  })

  # ── Forcer le re-render du formulaire quand on navigue vers l'onglet ─────
  # active_tab est mis à jour par goTab() en JS à chaque navigation
  observeEvent(input$active_tab, {
    if (isTRUE(input$active_tab == "formulaire")) {
      rv$refresh_local <- rv$refresh_local + 1L
    }
  })

  # ── Sauvegarder réponse ──────────────────────────────────────────────────
  save_current_form <- function(show_toast = TRUE) {
    qid  <- rv$current_quest; req(!is.null(qid))
    full <- get_questionnaire_full(qid)
    req(!is.null(full))

    enqueteur <- trimws(input$mob_enqueteur_input %||% "")
    if (enqueteur != "") {
      rv$enqueteur <- enqueteur
      set_config("enqueteur_nom", enqueteur)
    }

    # Collecter les réponses
    resp  <- list()
    manquants <- character(0)
    for (i in seq_len(nrow(full$questions))) {
      q   <- full$questions[i,]
      iid <- paste0("mob_q_", q$id)
      val <- input[[iid]]
      if (as.integer(q$obligatoire)==1 && is_empty_response_value(val))
        manquants <- c(manquants, q$texte)
      resp[[as.character(q$id)]] <- val
    }

    if (length(manquants) > 0) {
      showNotification(
        paste("Champs obligatoires manquants :", paste(manquants, collapse=", ")),
        type="error", duration=5)
      return(invisible(FALSE))
    }

    q_info <- get_questionnaire_by_id(qid)
    save_offline_reponse(
      quest_id     = qid,
      quest_nom    = q_info$nom %||% paste("Questionnaire", qid),
      enqueteur    = enqueteur,
      donnees_json = toJSON(resp, auto_unbox=TRUE, null="null"),
      drive_account = isolate(rv$active_email)
    )

    rv$refresh_local <- rv$refresh_local + 1L

    if (show_toast) {
      showNotification("✓ Réponse enregistrée localement", type="message", duration=3)
    }

    # Si sync auto activée et réseau ok → sync immédiatement
    if (isTRUE(input$mob_auto_sync) && rv$network_ok && rv$drive_ok) {
      do_sync()
    }

    # Revenir à l'accueil
    session$sendCustomMessage('goTab', 'accueil')
    invisible(TRUE)
  }

  observeEvent(input$btn_mob_submit,    save_current_form(show_toast=TRUE))
  observeEvent(input$btn_mob_save_draft,{
    save_current_form(show_toast=FALSE)
    showNotification("Brouillon sauvegardé.", type="message", duration=3)
  })

  # ── Liste des réponses locales ───────────────────────────────────────────
  output$mob_reponses_list <- renderUI({
    rv$refresh_local
    reps <- get_all_offline_reponses()
    if (nrow(reps) == 0) {
      return(div(class="mob-card",
        div(style="text-align:center;color:#8896A7;padding:16px;",
          p("Aucune réponse enregistrée.", style="margin-top:8px;")
        )
      ))
    }
    div(class="mob-card",
      lapply(seq_len(min(nrow(reps), 20)), function(i) {
        r <- reps[i,]
        dot_class <- if (r$statut=="synced") "rep-dot dot-synced" else "rep-dot dot-pending"
        horo <- tryCatch(format(as.POSIXct(r$horodateur), "%d/%m %H:%M"), error=function(e) r$horodateur)
        div(class="rep-item",
          div(class=dot_class),
          div(style="flex:1;",
            div(style="font-size:13px;font-weight:500;", r$questionnaire_nom),
            div(class="rep-meta",
              sprintf("%s · %s · %s", horo, r$enqueteur %||% "—",
                      if(r$statut=="synced") "✓ Sync" else "⏳ En attente"))
          )
        )
      })
    )
  })

  # ── Connexion Drive depuis Scanner (si questionnaire non trouvé local) ────
  observeEvent(input$btn_mob_connect_drive_scan, {
    result <- add_drive_account()
    if (isTRUE(result$ok)) {
      rv$drive_ok     <- TRUE
      rv$active_email <- result$email
      set_config("active_drive_account", result$email)
      showNotification(paste0("✓ Connecté : ", result$email), type="message", duration=3)
    } else {
      showNotification("Ajoutez un compte dans Paramètres > Comptes Google Drive.",
                       type="warning", duration=5)
    }
  })

  # ── Sync vers Drive ──────────────────────────────────────────────────────
  do_sync <- function() {
    if (!rv$drive_ok) {
      showNotification("Connectez d'abord votre Google Drive (Paramètres > Comptes).",
                       type="warning", duration=4)
      return()
    }
    if (!rv$network_ok) {
      showNotification("Pas de connexion réseau.", type="message", duration=3)
      return()
    }
    active <- isolate(rv$active_email)
    result <- sync_pending_to_drive(active_email=active)
    rv$refresh_local <- rv$refresh_local + 1L
    showNotification(result$message,
      type=if(isTRUE(result$ok)) "message" else "error", duration=5)
  }
  observeEvent(input$btn_mob_sync, do_sync())

  # ── Statut Drive dans l'onglet réponses ──────────────────────────────────
  output$mob_drive_status <- renderUI({
    if (rv$drive_ok) {
      div(class="st-pill st-ok", "☁ Google Drive connecté")
    } else {
      div(class="st-pill st-off", "☁ Non connecté")
    }
  })

  # ── Paramètres enquêteur ─────────────────────────────────────────────────
  output$mob_enqueteur_name_ui <- renderUI({
    textInput("mob_param_enqueteur", label=NULL,
              value=rv$enqueteur, placeholder="Votre nom")
  })
  observeEvent(input$mob_param_enqueteur, {
    nom <- trimws(input$mob_param_enqueteur %||% "")
    if (nom != "") {
      rv$enqueteur <- nom
      set_config("enqueteur_nom", nom)
    }
  })


  # ── Scanner QR — traitement du contenu décodé ──────────────────────────────
  # ── Lister les questionnaires disponibles sur Drive ──────────────────────
  output$mob_drive_quests_list_ui <- renderUI({ NULL })

  observeEvent(input$btn_list_drive_quests, {
    if (!rv$drive_ok) {
      showNotification("Connectez d'abord un compte Drive (Paramètres).",
                       type="warning", duration=4)
      return()
    }
    showNotification("Recherche sur Drive...", type="message", duration=3)

    result <- tryCatch({
      found <- googledrive::drive_find(
        pattern = "lestrade_quest_",
        n_max   = 100
      )
      if (nrow(found) == 0) return(list())
      # Extraire UID depuis le nom de fichier
      lapply(seq_len(nrow(found)), function(i) {
        uid <- sub("^lestrade_quest_(.+)\\.json$", "\\1", found$name[i])
        # Lire juste le nom du questionnaire depuis le JSON Drive (léger)
        nom <- tryCatch({
          tmp <- tempfile(fileext=".json")
          googledrive::drive_download(googledrive::as_id(found$id[i]),
                                      path=tmp, overwrite=TRUE)
          raw <- paste(readLines(tmp, warn=FALSE), collapse="")
          file.remove(tmp)
          # simplifyVector=TRUE : j$quest est une liste nommée, j$quest$nom est character
          j <- fromJSON(raw, simplifyVector=TRUE)
          n <- j$quest$nom
          if (!is.null(n) && length(n) > 0 && nchar(trimws(as.character(n)[1])) > 0)
            as.character(n)[1]
          else
            uid
        }, error=function(e) uid)
        list(uid=uid, nom=nom)
      })
    }, error=function(e) {
      showNotification(paste("Erreur Drive :", e$message), type="error", duration=6)
      list()
    })

    output$mob_drive_quests_list_ui <- renderUI({
      if (length(result) == 0)
        return(p(style="font-size:13px;color:var(--text3);margin-top:10px;",
                 "Aucun questionnaire Lestrade Forms trouvé."))

      # Vérifier lesquels sont déjà importés localement
      con   <- dbConnect(SQLite(), DB_PATH)
      descs <- dbGetQuery(con, "SELECT description FROM questionnaires")$description
      dbDisconnect(con)

      tagList(
        p(style="font-size:12px;color:var(--text3);margin:10px 0 6px;",
          sprintf("%d questionnaire(s) trouvé(s)", length(result))),
        lapply(result, function(q) {
          already <- any(grepl(q$uid, descs, fixed=TRUE))
          div(style=paste0("display:flex;align-items:center;gap:10px;",
                           "padding:9px 0;border-bottom:1px solid var(--bord);"),
            div(style="flex:1;",
              div(style="font-size:13px;font-weight:500;", q$nom),
              div(style="font-size:11px;color:var(--text3);", q$uid)
            ),
            if (already)
              div(class="st-pill st-ok", style="font-size:11px;", "✓ Importé")
            else
              tags$button(
                class="btn-import-drive-quest",
                `data-uid`=q$uid,
                style=paste0("font-size:12px;padding:6px 14px;border:1.5px solid var(--teal);",
                             "border-radius:8px;background:transparent;",
                             "color:var(--teal);cursor:pointer;white-space:nowrap;"),
                "Importer"
              )
          )
        })
      )
    })
  })

  # Bouton Importer depuis la liste Drive
  observeEvent(input$mob_import_drive_quest, {
    uid <- input$mob_import_drive_quest
    req(!is.null(uid), nchar(uid) > 3)
    fake_json <- toJSON(list(v="1.0", uid=uid, nom="Questionnaire"), auto_unbox=TRUE)
    process_qr_payload(as.character(fake_json))
    # Rafraîchir la liste après import
    shinyjs::delay(1000, {
      shinyjs::runjs("Shiny.setInputValue('btn_list_drive_quests', Math.random(), {priority:'event'});")
    })
  })

  process_qr_payload <- function(json_str) {
    # Décoder le payload léger du QR
    meta <- tryCatch(
      fromJSON(json_str, simplifyVector=FALSE),
      error=function(e) stop(paste("QR invalide:", e$message))
    )

    uid <- meta$uid %||% NULL
    nom <- meta$nom %||% "Questionnaire"

    if (is.null(uid) || !startsWith(uid, "LEST-"))
      stop("Ce QR code n'est pas un questionnaire Lestrade Forms.")

    # Vérifier si déjà importé localement
    con <- dbConnect(SQLite(), DB_PATH)
    ex <- dbGetQuery(con, "SELECT id FROM questionnaires WHERE description LIKE ?",
                     list(paste0("%[uid:",uid,"]%")))
    dbDisconnect(con)

    if (nrow(ex) > 0) {
      # Déjà présent — juste naviguer vers le formulaire
      rv$current_quest <- as.integer(ex$id[1])
      output$mob_scan_result <- renderUI({
        div(class="scan-ok",
          tags$strong("✓ Questionnaire déjà disponible !"), tags$br(),
          span(style="font-size:13px;", nom)
        )
      })
      session$sendCustomMessage('goTab', 'formulaire')
      showNotification(paste0("'",nom,"' prêt à remplir !"), type="message", duration=4)
      return()
    }

    # Pas encore importé → télécharger depuis Drive
    if (!drive_is_connected()) {
      output$mob_scan_result <- renderUI({
        div(class="scan-err",
          tags$strong("Drive requis"), tags$br(),
          span(style="font-size:12px;",
            "Ce questionnaire n'est pas encore sur cet appareil. ",
            "Connectez Google Drive dans les Paramètres pour le télécharger."),
          br(), br(),
          actionButton("btn_mob_connect_drive_scan", "Connecter Drive",
                       class="btn-mob btn-teal-mob")
        )
      })
      return()
    }

    output$mob_scan_result <- renderUI({
      div(style="text-align:center;color:#4A5870;font-size:13px;padding:10px;",
          "⏳ Téléchargement depuis Drive...")
    })

    tryCatch({
      full_json  <- download_quest_from_drive(uid)
      new_id     <- import_quest_from_json(full_json)
      rv$current_quest  <- new_id
      rv$refresh_local  <- rv$refresh_local + 1L
      quest <- get_questionnaire_by_id(new_id)
      output$mob_scan_result <- renderUI({
        div(class="scan-ok",
          tags$strong("✓ Questionnaire importé depuis Drive !"), tags$br(),
          span(style="font-size:13px;", quest$nom), tags$br(),
          span(style="font-size:12px;color:#4A5870;",
            paste(count_questions_by_questionnaire(new_id), "question(s)"))
        )
      })
      session$sendCustomMessage('goTab', 'formulaire')
      showNotification(paste0("✓ '",quest$nom,"' prêt !"), type="message", duration=4)
    }, error=function(e) {
      output$mob_scan_result <- renderUI({
        div(class="scan-err",
          tags$strong("✗ Erreur de téléchargement"), tags$br(),
          span(style="font-size:12px;", e$message)
        )
      })
    })
  }

  # QR scanné par la caméra
  observeEvent(input$mob_qr_scanned, {
    req(!is.null(input$mob_qr_scanned), nchar(input$mob_qr_scanned) > 5)
    process_qr_payload(input$mob_qr_scanned)
  })

  # Erreur caméra
  observeEvent(input$mob_scan_error, {
    output$mob_scan_result <- renderUI({
      div(class="scan-err", input$mob_scan_error)
    })
  })

  # Import manuel par UID (fallback si scan impossible)
  observeEvent(input$btn_import_manual_uid, {
    uid <- trimws(input$mob_manual_uid %||% "")
    if (uid=="") { showNotification("Entrez un identifiant.", type="message", duration=3); return() }
    # Simuler un scan avec juste l'UID
    fake_json <- toJSON(list(v="1.0", uid=uid, nom="Questionnaire"), auto_unbox=TRUE)
    process_qr_payload(as.character(fake_json))
  })

  # Initialiser le résultat scan vide
  output$mob_scan_result <- renderUI({ NULL })

}
