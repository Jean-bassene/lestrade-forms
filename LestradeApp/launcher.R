# Lestrade Forms — Launcher R
# Les variables LESTRADE_BASE_DIR et LESTRADE_DB_PATH sont definies par run_app.bat

app_base <- Sys.getenv("LESTRADE_BASE_DIR")
if (!nzchar(app_base)) app_base <- getwd()
app_base <- normalizePath(trimws(app_base), "/")

# Bibliotheque R-Portable locale
r_lib <- file.path(app_base, "R-Portable", "library")
.libPaths(c(r_lib, .libPaths()))

# Chemin DB (defini par le bat, sinon fallback)
db_path <- Sys.getenv("LESTRADE_DB_PATH")
if (!nzchar(db_path)) {
  db_path <- file.path(Sys.getenv("APPDATA"), "LestradeApp", "questionnaires.db")
}
Sys.setenv(LESTRADE_DB_PATH = db_path)
Sys.setenv(LESTRADE_DATA_DIR = dirname(db_path))

# Dossier de l'app Shiny
app_dir <- file.path(app_base, "app")
if (!dir.exists(app_dir)) stop("Dossier app introuvable: ", app_dir)

library(shiny)
# launch.browser = FALSE : Chrome Portable est ouvert par run_app.bat
shiny::runApp(app_dir, port = 3838, launch.browser = FALSE, host = "127.0.0.1")
