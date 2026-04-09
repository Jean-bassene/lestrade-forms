# relancer.R — Rebuild + relance LestradeApp en une commande
# Usage : source("c:/Projets/CaritasR/enquete/relancer.R")

cat("Arrêt des processus R en arrière-plan...\n")
system("taskkill /F /IM Rscript.exe", ignore.stdout = TRUE, ignore.stderr = TRUE)
system("taskkill /F /IM Rterm.exe",   ignore.stdout = TRUE, ignore.stderr = TRUE)
Sys.sleep(1)

cat("Build du package...\n")
pkg <- devtools::build("c:/Projets/CaritasR/enquete/LestradeApp")

cat("Installation...\n")
lib_alt <- "C:/Users/j1jea/AppData/Local/R/lestrade_lib"
dir.create(lib_alt, recursive = TRUE, showWarnings = FALSE)
install.packages(pkg, repos = NULL, type = "source", lib = lib_alt)

cat("Lancement...\n")
if ("LestradeApp" %in% loadedNamespaces()) unloadNamespace("LestradeApp")
.libPaths(c(lib_alt, .libPaths()))
library(LestradeApp)
LestradeApp::run()
