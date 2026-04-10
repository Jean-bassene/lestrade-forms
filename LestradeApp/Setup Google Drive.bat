@echo off
title Configuration Google Drive — Lestrade Forms
cd /d "%~dp0"
echo.
echo === Configuration Google Drive pour Lestrade Forms ===
echo.
echo Le navigateur va s'ouvrir pour l'authentification Google.
echo Connectez-vous avec votre compte Google Drive.
echo.
echo Appuyez sur une touche pour continuer...
pause > nul
"R-Portable\bin\Rscript.exe" --vanilla setup_drive.R
echo.
echo Appuyez sur une touche pour fermer...
pause > nul
