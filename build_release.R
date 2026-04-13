# ============================================================================
# build_release.R — Compilation bytecode Lestrade Forms
# Compile les .R en .Rbc (binaire illisible) pour protéger le code source
# Usage : Rscript build_release.R
# ============================================================================

library(compiler)

APP_SRC  <- "LestradeApp/inst/app"
APP_OUT  <- "LestradeApp/inst/app_release"

# Vérification : ce script doit être lancé avec R-Portable (4.2.x)
# car les .Rbc sont incompatibles entre versions R
r_ver <- paste0(R.version$major, ".", R.version$minor)
cat("Version R utilisée pour la compilation :", r_ver, "\n")
if (!startsWith(r_ver, "4.2")) {
  warning("ATTENTION : compilez avec R-Portable 4.2 (LestradeApp/R-Portable/bin/Rscript.exe)")
}

cat("=== Lestrade Forms — Build Release ===\n")
cat("Source :", APP_SRC, "\n")
cat("Output :", APP_OUT, "\n\n")

# ── Créer le dossier de sortie ────────────────────────────────────────────────
if (dir.exists(APP_OUT)) unlink(APP_OUT, recursive = TRUE)
dir.create(APP_OUT, recursive = TRUE)

# Copier les ressources non-R (www/, plumber.R, lestrade_panier.gs)
file.copy(file.path(APP_SRC, "www"),               APP_OUT, recursive = TRUE)
file.copy(file.path(APP_SRC, "plumber.R"),          APP_OUT)
file.copy(file.path(APP_SRC, "lestrade_panier.gs"), APP_OUT)

# ── Fichiers R à compiler ─────────────────────────────────────────────────────
r_files <- c("global.R", "global_licence.R", "server.R", "ui.R")

for (f in r_files) {
  src <- file.path(APP_SRC, f)
  rbc <- file.path(APP_OUT, sub("\\.R$", ".Rbc", f))
  cat("Compiling:", f, "->", basename(rbc), "... ")
  tryCatch({
    cmpfile(src, rbc)
    cat("OK\n")
  }, error = function(e) {
    cat("ERREUR:", e$message, "\n")
  })
}

# ── Créer les stubs .R qui chargent le bytecode ───────────────────────────────
# Ces stubs remplacent les .R originaux — ils sont minimes et ne révèlent rien

cat("\nCreating loader stubs...\n")

# global.R stub — side effects only, pas d'assignation nécessaire
writeLines(c(
  "# Lestrade Forms — protected build",
  "compiler::loadcmp('global.Rbc')"
), file.path(APP_OUT, "global.R"))

# global_licence.R stub — side effects only
writeLines(c(
  "# Lestrade Forms — protected build",
  "compiler::loadcmp('global_licence.Rbc')"
), file.path(APP_OUT, "global_licence.R"))

# server.R stub — Shiny cherche la variable `server` dans l'env sourcé
writeLines(c(
  "# Lestrade Forms — protected build",
  "server <- compiler::loadcmp('server.Rbc')"
), file.path(APP_OUT, "server.R"))

# ui.R stub — Shiny cherche la variable `ui` dans l'env sourcé
writeLines(c(
  "# Lestrade Forms — protected build",
  "ui <- compiler::loadcmp('ui.Rbc')"
), file.path(APP_OUT, "ui.R"))

cat("Stubs created.\n")

# ── Vérification ──────────────────────────────────────────────────────────────
cat("\n=== Fichiers générés ===\n")
files <- list.files(APP_OUT, recursive = TRUE, full.names = FALSE)
for (f in files) {
  size <- file.size(file.path(APP_OUT, f))
  cat(sprintf("  %-40s %s\n", f, format(size, big.mark=",")))
}

cat("\n=== Build terminé ===\n")
cat("Dossier release :", normalizePath(APP_OUT), "\n")
cat("Mettez à jour lestrade_setup.iss pour pointer vers app_release/\n")
