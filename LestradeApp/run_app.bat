@echo off
cd /d "%~dp0"

:: Variables d'environnement pour R
set LESTRADE_BASE_DIR=%~dp0
set LESTRADE_DATA_DIR=%APPDATA%\LestradeApp

::Creer le dossier donnees utilisateur si absent
if not exist "%LESTRADE_DATA_DIR%" mkdir "%LESTRADE_DATA_DIR%"

:: Copier la base vide si premiere installation
if not exist "%LESTRADE_DATA_DIR%\questionnaires.db" (
    copy "%~dp0questionnaires_empty.db" "%LESTRADE_DATA_DIR%\questionnaires.db" >nul 2>&1
)

set LESTRADE_DB_PATH=%LESTRADE_DATA_DIR%\questionnaires.db

:: Lancer R en arriere-plan (sans fenetre)
start /B "" "R-Portable\bin\Rscript.exe" --vanilla launcher.R > "%TEMP%\lestrade_shiny.log" 2>&1

:: Attendre que Shiny demarre (10 secondes)
timeout /t 10 /nobreak > nul

:: Ouvrir Chrome Portable en mode app (sans barre d'adresse, comme une vraie app)
:: --disable-popup-blocking : autorise la popup Google OAuth
start "" "ChromePortable\ChromePortable.exe" "--app=http://127.0.0.1:3838" "--disable-popup-blocking"
