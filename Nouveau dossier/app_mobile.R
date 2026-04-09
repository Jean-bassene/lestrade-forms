# ============================================================================
# app_mobile.R  — Lestrade Forms Mobile
# Point d'entrée — à lancer séparément de app_final.R
#
# INSTALLATION :
#   install.packages(c("shinyMobile","googlesheets4","gargle","RSQLite","DBI","jsonlite","dplyr"))
#
# LANCEMENT :
#   shiny::runApp("app_mobile.R", port=3939, launch.browser=TRUE)
#   Ou sur mobile, via l'IP locale du PC : http://192.168.x.x:3939
#
# ARCHITECTURE :
#   app_mobile.R   → point d'entrée
#   ui_mobile.R    → interface shinyMobile (Framework7)
#   server_mobile.R→ logique collecte + sync Drive
#   global_final.R → partagé avec l'app Desktop (questionnaires, questions, DB)
# ============================================================================

# Dépendances communes avec l'app Desktop
source("global_final.R")
source("ui_mobile.R")
source("server_mobile.R")
shinyApp(ui = ui_mobile, server = server_mobile)
