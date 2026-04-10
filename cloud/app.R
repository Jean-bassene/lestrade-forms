# ============================================================================
# app.R — Version Cloud (shinyapps.io)
# Différences vs Desktop :
#   - Pas d'API Plumber (callr interdit sur shinyapps)
#   - DB SQLite dans tempdir() (session uniquement)
#   - Licence vérifiée via Apps Script uniquement
#   - Pas de WiFi local (mobile sync via panier uniquement)
# ============================================================================

source("global_final.R")
source("ui_final.R")
source("server_final.R")

shinyApp(ui = ui, server = server)
