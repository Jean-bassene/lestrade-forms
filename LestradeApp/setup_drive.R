# ============================================================
# setup_drive.R — Configuration Google Drive (a lancer UNE FOIS)
# Ouvrir ce script dans RStudio et cliquer "Source"
# OU depuis l'installation : double-cliquer "Setup Google Drive.bat"
# ============================================================

cat("=== Configuration Google Drive pour Lestrade Forms ===\n\n")

# Chemin du cache (meme que l'app)
cache_dir <- file.path(Sys.getenv("APPDATA"), "LestradeApp", ".secrets_desktop")
dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
cat("Dossier token :", cache_dir, "\n\n")

# Charger googledrive
if (!requireNamespace("googledrive", quietly = TRUE)) {
  cat("Installation de googledrive...\n")
  install.packages("googledrive")
}
library(googledrive)

cat("Le navigateur va s'ouvrir pour l'authentification Google.\n")
cat("Connectez-vous avec le compte Google Drive de votre organisation.\n\n")

# Authentification interactive (ouvre le navigateur)
drive_auth(
  cache  = cache_dir,
  scopes = c(
    "https://www.googleapis.com/auth/drive",
    "https://www.googleapis.com/auth/spreadsheets"
  )
)

# Verification
tryCatch({
  u <- drive_user()
  cat("\n✓ Google Drive configure avec succes !\n")
  cat("  Compte :", u$emailAddress, "\n")
  cat("  Token sauvegarde dans :", cache_dir, "\n\n")
  cat("Vous pouvez maintenant lancer Lestrade Forms.\n")
}, error = function(e) {
  cat("\n! Erreur lors de la verification :", e$message, "\n")
})
