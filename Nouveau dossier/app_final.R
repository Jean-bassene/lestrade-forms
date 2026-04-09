 # ============================================================================
# VERSION FINALE - APP
# Point d'entrée principal
# ============================================================================

source("global_final.R")
source("ui_final.R")
source("server_final.R")

# ── Lancement automatique de l'API plumber en arrière-plan ──────────────────
.api_process <- NULL
.api_log <- file.path(tempdir(), "lestrade_api.log")
.api_err <- file.path(tempdir(), "lestrade_api_err.log")

start_api_background <- function() {
  tryCatch({
    # Vérifier si l'API tourne déjà
    already <- tryCatch({
      con <- url("http://127.0.0.1:8765/health", open = "r")
      close(con); TRUE
    }, error = function(e) FALSE)

    if (already) {
      message("API déjà active sur le port 8765.")
      return(invisible(NULL))
    }

    # Ouvrir le port 8765 dans le pare-feu Windows (silencieux si déjà présent)
    system(
      paste0('netsh advfirewall firewall add rule name="Lestrade API 8765"',
             ' dir=in action=allow protocol=TCP localport=8765'),
      ignore.stdout = TRUE, ignore.stderr = TRUE
    )

    # Passer le chemin absolu de plumber.R + DB_PATH + work_dir au sous-processus
    plumber_file <- normalizePath("plumber.R", mustWork = TRUE)
    work_dir     <- dirname(plumber_file)
    db_path      <- normalizePath(DB_PATH, mustWork = FALSE)

    message("Démarrage API : ", plumber_file)
    message("DB : ", db_path)

    .api_process <<- callr::r_bg(
      func = function(plumber_file, db_path, work_dir, port, lib_paths) {
        .libPaths(lib_paths)
        Sys.setenv(LESTRADE_DB_PATH = db_path)
        setwd(work_dir)
        library(plumber)
        pr <- plumber::plumb(plumber_file)
        pr$run(host = "0.0.0.0", port = port, docs = FALSE)
      },
      args = list(
        plumber_file = plumber_file,
        db_path      = db_path,
        work_dir     = work_dir,
        port         = 8765,
        lib_paths    = .libPaths()
      ),
      stdout = .api_log,
      stderr = .api_err
    )

    # Attendre max 15s (5 tentatives × 3s)
    ok <- FALSE
    for (i in seq_len(5)) {
      Sys.sleep(3)
      ok <- tryCatch({
        con <- url("http://127.0.0.1:8765/health", open = "r"); close(con); TRUE
      }, error = function(e) FALSE)
      if (ok) break
      message("Attente API... tentative ", i, "/5")
    }

    if (ok) {
      message("✓ API plumber active sur http://0.0.0.0:8765")
    } else {
      message("✗ API non disponible après 15s. Logs d'erreur :")
      if (file.exists(.api_err)) {
        err_lines <- readLines(.api_err, warn = FALSE)
        if (length(err_lines) > 0)
          message(paste(tail(err_lines, 20), collapse = "\n"))
      }
    }
  }, error = function(e) {
    message("Impossible de démarrer l'API : ", e$message)
  })
}

# Installer callr si absent
if (!requireNamespace("callr", quietly = TRUE)) {
  message("Installation de callr (requis pour l'API background)...")
  install.packages("callr", repos = "https://cloud.r-project.org", quiet = TRUE)
}

start_api_background()

shinyApp(ui = ui, server = server)
