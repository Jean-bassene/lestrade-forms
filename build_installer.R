# =============================================================================
# build_installer.R — Build de l'installeur Lestrade Forms Desktop
# Usage : cd c:/Projets/CaritasR/enquete && Rscript build_installer.R
# =============================================================================

ROOT_DIR   <- normalizePath("c:/Projets/CaritasR/enquete", "/")
APP_DIR    <- file.path(ROOT_DIR, "LestradeApp")
R_PORTABLE <- file.path(APP_DIR, "R-Portable")
RSCRIPT    <- file.path(R_PORTABLE, "bin", "Rscript.exe")
LIB_PATH   <- file.path(R_PORTABLE, "library")
INST_APP   <- file.path(APP_DIR, "inst", "app")
SRC_DIR    <- file.path(ROOT_DIR, "Nouveau dossier")
INNO_SETUP <- "C:/Program Files (x86)/Inno Setup 6/iscc.exe"
OUTPUT_DIR <- file.path(ROOT_DIR, "installer_output")
ISS_FILE   <- file.path(ROOT_DIR, "lestrade_setup.iss")

cat("=== Build Lestrade Forms Desktop Installer ===\n\n")

# ─────────────────────────────────────────────────────────────────────────────
# ETAPE 1 : Copier les fichiers app vers inst/app
# ─────────────────────────────────────────────────────────────────────────────
cat("[ 1/4 ] Mise a jour des fichiers app...\n")

copies <- list(
  global_final.R  = "global.R",
  server_final.R  = "server.R",
  ui_final.R      = "ui.R",
  global_licence.R = "global_licence.R",
  plumber.R        = "plumber.R"
)
for (src_name in names(copies)) {
  src  <- file.path(SRC_DIR, src_name)
  dest <- file.path(INST_APP, copies[[src_name]])
  if (file.exists(src)) {
    file.copy(src, dest, overwrite = TRUE)
    cat("   OK:", src_name, "->", copies[[src_name]], "\n")
  } else {
    cat("   SKIP (absent):", src_name, "\n")
  }
}
cat("\n")

# ─────────────────────────────────────────────────────────────────────────────
# ETAPE 2 : Installer les packages manquants dans R-Portable
# ─────────────────────────────────────────────────────────────────────────────
cat("[ 2/4 ] Installation des packages dans R-Portable...\n")
cat("   (cette etape peut prendre 5-15 minutes la premiere fois)\n\n")

packages_requis <- c(
  # Core Shiny
  "shiny", "shinyjs", "httpuv", "mime", "xtable", "fontawesome",
  "bslib", "sass", "jquerylib", "htmltools", "promises", "later",
  # Data
  "DT", "DBI", "RSQLite", "bit64", "blob", "bit",
  # Viz
  "ggplot2", "plotly", "htmlwidgets", "crosstalk", "viridisLite",
  "scales", "gtable", "isoband", "farver", "labeling",
  "RColorBrewer", "lazyeval",
  # Tidy
  "dplyr", "tidyr", "tibble", "pillar", "vctrs", "generics",
  "purrr", "stringr", "forcats", "lubridate", "hms", "tzdb",
  "readxl", "readr", "vroom", "cellranger", "rematch",
  # Utils
  "jsonlite", "stringi", "httr", "curl", "openssl",
  "digest", "qrcode", "zip", "withr", "memoise",
  "cachem", "fastmap", "lifecycle", "ellipsis", "pkgconfig",
  "progress", "prettyunits", "cli", "glue", "rlang", "R6",
  # API
  "plumber", "callr", "processx"
)

tmp_install <- tempfile(fileext = ".R")
writeLines(c(
  'options(repos = c(CRAN = "https://cloud.r-project.org"), warn = 1)',
  sprintf('.libPaths("%s")', LIB_PATH),
  sprintf('pkgs <- %s', deparse(packages_requis)),
  sprintf('installed <- rownames(installed.packages(lib.loc = "%s"))', LIB_PATH),
  'manquants <- pkgs[!pkgs %in% installed]',
  'if (length(manquants) == 0) { cat("Tous les packages sont deja installes.\\n"); quit("no") }',
  'cat("Packages a installer:", paste(manquants, collapse=", "), "\\n")',
  sprintf('install.packages(manquants, lib = "%s", dependencies = TRUE)', LIB_PATH)
), tmp_install)

ret <- system2(RSCRIPT, args = c("--vanilla", tmp_install))
if (ret != 0) stop("Erreur installation packages (code ", ret, ")")
cat("   OK — packages installes\n\n")

# ─────────────────────────────────────────────────────────────────────────────
# ETAPE 3 : Créer le launcher
# ─────────────────────────────────────────────────────────────────────────────
cat("[ 3/4 ] Creation du launcher...\n")

launcher_r_content <- '# Lestrade Forms Desktop — Launcher
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
'

writeLines(launcher_r_content, file.path(APP_DIR, "launcher.R"))
cat("   OK — launcher.R\n")

# Batch launcher Windows (double-click)
bat_content <- paste0(
  '@echo off\r\n',
  'title Lestrade Forms\r\n',
  'cd /d "%~dp0"\r\n',
  'start "" "R-Portable\\bin\\Rscript.exe" --vanilla launcher.R\r\n'
)
writeBin(chartr("\n", "\r\n", bat_content),
         con = file(file.path(APP_DIR, "Lestrade Forms.bat"), "wb"))
cat("   OK — Lestrade Forms.bat\n\n")

# ─────────────────────────────────────────────────────────────────────────────
# ETAPE 4 : Générer le .iss et compiler l'installeur
# ─────────────────────────────────────────────────────────────────────────────
cat("[ 4/4 ] Generation Inno Setup et compilation...\n")
dir.create(OUTPUT_DIR, showWarnings = FALSE)

iss <- sprintf('; Lestrade Forms — Script Inno Setup (genere par build_installer.R)
#define AppName "Lestrade Forms"
#define AppVersion "1.0.0"
#define AppPublisher "Caritas"

[Setup]
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppId={{8F3A2D1E-4B5C-6D7E-8F9A-0B1C2D3E4F5A}
DefaultDirName={autopf}\\{#AppName}
DefaultGroupName={#AppName}
OutputDir=%s
OutputBaseFilename=Lestrade_Forms_Setup_v{#AppVersion}
SetupIconFile=%s\\app_icon.ico
UninstallDisplayIcon={app}\\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
DisableProgramGroupPage=yes
CloseApplications=no
ShowLanguageDialog=no

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\\French.isl"

[Tasks]
Name: "desktopicon"; Description: "Raccourci sur le &bureau"; GroupDescription: "Raccourcis supplementaires:";

[Files]
; Application Shiny
Source: "%s\\inst\\app\\*"; DestDir: "{app}\\app"; Flags: ignoreversion recursesubdirs createallsubdirs
; Launcher et donnees
Source: "%s\\launcher.R"; DestDir: "{app}"; Flags: ignoreversion
Source: "%s\\Lestrade Forms.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "%s\\inst\\extdata\\questionnaires_empty.db"; DestDir: "{app}"; Flags: ignoreversion
Source: "%s\\app_icon.ico"; DestDir: "{app}"; Flags: ignoreversion
; R-Portable complet avec packages
Source: "%s\\R-Portable\\*"; DestDir: "{app}\\R-Portable"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\\{#AppName}"; Filename: "{app}\\Lestrade Forms.bat"; WorkingDir: "{app}"; IconFilename: "{app}\\app_icon.ico"
Name: "{group}\\Desinstaller {#AppName}"; Filename: "{uninstallexe}"
Name: "{commondesktop}\\{#AppName}"; Filename: "{app}\\Lestrade Forms.bat"; WorkingDir: "{app}"; IconFilename: "{app}\\app_icon.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\\Lestrade Forms.bat"; Description: "Lancer {#AppName} maintenant"; Flags: nowait postinstall skipifsilent shellexec

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

[Code]
procedure InitializeWizard();
begin
  WizardForm.WelcomeLabel2.Caption :=
    "Lestrade Forms est une application de collecte de donnees terrain pour Caritas." + #13#10#13#10 +
    "- Fonctionne sans connexion internet" + #13#10 +
    "- Synchronisation via panier (Google Sheets)" + #13#10 +
    "- Compatible avec l'"'"'application mobile Lestrade" + #13#10#13#10 +
    "Aucune installation de R n'"'"'est necessaire.";
end;
',
  OUTPUT_DIR, APP_DIR,
  APP_DIR, APP_DIR, APP_DIR, APP_DIR, APP_DIR,
  APP_DIR
)

writeLines(iss, ISS_FILE)
cat("   OK — lestrade_setup.iss cree\n")

if (file.exists(INNO_SETUP)) {
  cat("   Compilation (peut prendre 2-5 min selon taille R-Portable)...\n")
  ret3 <- system2(INNO_SETUP, args = sprintf('"%s"', ISS_FILE))
  if (ret3 == 0) {
    exe_file <- file.path(OUTPUT_DIR, "Lestrade_Forms_Setup_v1.0.0.exe")
    if (file.exists(exe_file)) {
      size_mb <- round(file.size(exe_file) / 1024 / 1024, 1)
      cat(sprintf("\n============================\n"))
      cat(sprintf("  SUCCES !\n"))
      cat(sprintf("  Fichier : %s\n", exe_file))
      cat(sprintf("  Taille  : %.1f Mo\n", size_mb))
      cat(sprintf("============================\n"))
    }
  } else {
    cat("   ERREUR Inno Setup code:", ret3, "\n")
    cat("   Verifiez lestrade_setup.iss et relancez.\n")
  }
} else {
  cat("   Inno Setup non trouve.\n")
  cat("   Lancez manuellement : iscc lestrade_setup.iss\n")
}
