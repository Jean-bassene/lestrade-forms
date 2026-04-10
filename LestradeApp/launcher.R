# Lestrade Forms Desktop — Launcher
# Chemin relatif a ce fichier : R-Portable/ et app/ sont dans le meme dossier

args <- commandArgs(trailingOnly = FALSE)
this_script <- normalizePath(
  sub("--file=", "", grep("--file=", args, value = TRUE)[1]),
  mustWork = FALSE
)
this_dir <- if (!is.na(this_script)) dirname(this_script) else getwd()

# Bibliotheque R-Portable locale
r_lib <- file.path(this_dir, "R-Portable", "library")
.libPaths(c(r_lib, .libPaths()))

# Dossier de donnees utilisateur (persiste entre les reinstallations)
data_dir <- file.path(Sys.getenv("APPDATA"), "LestradeApp")
dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
db_path <- file.path(data_dir, "questionnaires.db")

if (!file.exists(db_path)) {
  db_src <- file.path(this_dir, "questionnaires_empty.db")
  if (file.exists(db_src)) {
    file.copy(db_src, db_path)
    message("Base de donnees creee dans : ", data_dir)
  }
}
Sys.setenv(LESTRADE_DB_PATH = db_path)
Sys.setenv(LESTRADE_DATA_DIR = data_dir)

app_dir <- file.path(this_dir, "app")
if (!dir.exists(app_dir)) stop("Dossier app introuvable: ", app_dir)

library(shiny)
message("Lancement de Lestrade Forms sur http://127.0.0.1:3838")
shiny::runApp(app_dir, port = 3838, launch.browser = TRUE, host = "127.0.0.1")

