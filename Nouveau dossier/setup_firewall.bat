@echo off
:: setup_firewall.bat — Ouvre le port 8765 pour Lestrade Forms (requiert admin)
:: Lance ce fichier UNE SEULE FOIS en tant qu'administrateur
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Relancement en administrateur...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)
netsh advfirewall firewall delete rule name="Lestrade API 8765" >nul 2>&1
netsh advfirewall firewall add rule name="Lestrade API 8765" dir=in action=allow protocol=TCP localport=8765
echo.
echo Port 8765 ouvert avec succes pour Lestrade Forms.
pause
