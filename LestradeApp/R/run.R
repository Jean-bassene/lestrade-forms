#' Lance l'application Lestrade Forms Desktop
#'
#' @param port Port HTTP pour l'app Shiny (défaut 3838)
#' @param launch_browser Ouvre le navigateur automatiquement
#' @export
run <- function(port = 3838, launch_browser = TRUE) {

  # Dossier des ressources embarquées dans le package
  app_dir <- system.file("app", package = "LestradeApp")
  if (!nzchar(app_dir)) stop("Ressources introuvables dans le package LestradeApp.")

  # Copier la DB dans le répertoire utilisateur si absente
  .init_user_data()

  # Mettre à jour DB_PATH dans le namespace du package (il peut être figé
  # à "questionnaires.db" si library(LestradeApp) a été appelé avant run())
  db_path_correct <- file.path(.user_data_dir(), "questionnaires.db")
  ns <- asNamespace("LestradeApp")
  tryCatch({
    unlockBinding("DB_PATH", ns)
    assign("DB_PATH", db_path_correct, envir = ns)
    lockBinding("DB_PATH", ns)
  }, error = function(e) NULL)

  # Démarrer l'API plumber en arrière-plan
  .start_api_background()

  # Lancer Shiny
  shiny::shinyOptions(port = port)
  shiny::runApp(
    app_dir,
    port            = port,
    launch.browser  = launch_browser,
    host            = "127.0.0.1"
  )
}

#' Arrête l'API plumber en arrière-plan
#' @export
stop_api <- function() {
  proc <- .lestrade_env$api_process
  if (!is.null(proc) && proc$is_alive()) {
    proc$kill()
    .lestrade_env$api_process <- NULL
    message("API Lestrade arrêtée.")
  } else {
    message("Aucune API active.")
  }
}

#' Lance uniquement l'API plumber (sans l'interface Shiny)
#' @param port Port de l'API (défaut 8765)
#' @export
run_api <- function(port = 8765) {
  .start_api_background(port = port, wait = FALSE)
  message(sprintf("API Lestrade Forms démarrée sur le port %d", port))
  invisible(NULL)
}

# ─────────────────────────────────────────────────────────────────────────────
# Fonctions internes
# ─────────────────────────────────────────────────────────────────────────────

# Environnement interne pour stocker le process (évite le verrou <<- sur package)
.lestrade_env <- new.env(parent = emptyenv())
.lestrade_env$api_process <- NULL

.start_api_background <- function(port = 8765, wait = FALSE) {
  # Vérifier si déjà active
  already <- tryCatch({
    con <- url(sprintf("http://127.0.0.1:%d/health", port), open = "r")
    close(con); TRUE
  }, error = function(e) FALSE)

  if (already) {
    message("API déjà active sur le port ", port)
    return(invisible(NULL))
  }

  plumber_file <- system.file("app", "plumber.R", package = "LestradeApp")

  log_out <- file.path(tempdir(), "lestrade_api.log")
  log_err <- file.path(tempdir(), "lestrade_api_err.log")

  data_dir <- .user_data_dir()
  db_path  <- file.path(data_dir, "questionnaires.db")

  .lestrade_env$api_process <- callr::r_bg(
    func = function(plumber_file, data_dir, db_path, port, lib_paths) {
      # Ajouter les mêmes lib paths que la session principale
      .libPaths(lib_paths)
      Sys.setenv(LESTRADE_DB_PATH = db_path)
      options(gargle_oauth_cache = FALSE, gargle_quiet = TRUE)
      Sys.setenv(GARGLE_OAUTH_EMAIL = "")
      setwd(data_dir)
      library(plumber)
      pr <- plumber::plumb(plumber_file)
      pr$run(host = "0.0.0.0", port = port, docs = FALSE)
    },
    args = list(
      plumber_file = plumber_file,
      data_dir     = data_dir,
      db_path      = db_path,
      port         = port,
      lib_paths    = .libPaths()
    ),
    stdout = log_out,
    stderr = log_err
  )

  # Attendre que l'API démarre (retry 5x toutes les 2s = 10s max)
  ok <- FALSE
  for (i in seq_len(5)) {
    Sys.sleep(2)
    ok <- tryCatch({
      con <- url(sprintf("http://127.0.0.1:%d/health", port), open = "r")
      close(con); TRUE
    }, error = function(e) FALSE)
    if (ok) break
  }

  if (ok) {
    message(sprintf("API Lestrade active sur le port %d.", port))
  } else {
    message("API démarrée — logs disponibles si problème :")
    message("  ", log_out)
    message("  ", log_err)
  }

  if (wait) Sys.sleep(2)
  invisible(NULL)
}

.user_data_dir <- function() {
  dir <- file.path(tools::R_user_dir("LestradeApp", "data"))
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  dir
}

.init_user_data <- function() {
  data_dir <- .user_data_dir()
  db_dest  <- file.path(data_dir, "questionnaires.db")

  # Copier la DB vide si absente (première installation)
  if (!file.exists(db_dest)) {
    db_src <- system.file("extdata", "questionnaires_empty.db", package = "LestradeApp")
    if (nzchar(db_src)) {
      file.copy(db_src, db_dest)
    }
  }

  # Définir DB_PATH globalement pour les fonctions global.R
  Sys.setenv(LESTRADE_DB_PATH = db_dest)
  invisible(data_dir)
}
