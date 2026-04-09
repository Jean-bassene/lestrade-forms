# ============================================================================
# run_api.R — Lance le serveur plumber Lestrade Forms
# Usage : Rscript run_api.R
#         ou ouvrir dans RStudio et cliquer Run
# ============================================================================

# Se positionner dans le bon dossier (RStudio ou Rscript)
tryCatch({
  path <- rstudioapi::getActiveDocumentContext()$path
  if (!is.null(path) && nzchar(path)) {
    setwd(dirname(path))
  }
}, error = function(e) {
  # Lancé via Rscript
  args <- commandArgs(trailingOnly = FALSE)
  f <- sub("--file=", "", args[grep("--file=", args)])
  if (length(f) > 0 && nzchar(f)) setwd(dirname(normalizePath(f)))
})

library(plumber)

PORT <- 8765   # Changer si conflit réseau

cat("====================================================\n")
cat("  Lestrade Forms API\n")
cat(sprintf("  Port : %d\n", PORT))
cat(sprintf("  URL  : http://0.0.0.0:%d\n", PORT))
cat("  Donnez cette adresse IP aux utilisateurs Flutter\n")
cat("====================================================\n\n")

# Afficher l'IP locale (première interface non-loopback)
tryCatch({
  ips <- system("ipconfig", intern = TRUE)
  ipv4 <- grep("IPv4", ips, value = TRUE)
  if (length(ipv4) > 0) {
    cat("IPs disponibles sur ce PC :\n")
    for (line in ipv4) {
      ip <- trimws(sub(".*: ", "", line))
      cat(sprintf("  -> http://%s:%d\n", ip, PORT))
    }
    cat("\n")
  }
}, error = function(e) NULL)

pr <- plumb("plumber.R")
pr$run(host = "0.0.0.0", port = PORT, docs = TRUE)
