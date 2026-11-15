@echo off
setlocal
title FPS Boost - RTX 3060 / Ryzen 5800X

rem --- Relance en administrateur si besoin ---
net session >nul 2>&1
if errorlevel 1 (
    echo Demande des droits administrateur...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"

:menu
cls
echo ============================================================
echo    FPS BOOST - RTX 3060 / Ryzen 7 5800X / B550
echo ============================================================
echo.
echo    0. Diagnostic (lecture seule, rapport sur le Bureau)
echo    1. Windows Gaming (alimentation, Mode Jeu, HAGS, souris)
echo    2. Nettoyage (temporaires, telemetrie, applis de fond)
echo    3. Reseau / latence (coupe la connexion quelques secondes)
echo.
echo    A. Tout appliquer (1 + 2 + 3)
echo    R. RESTAURER : tout remettre comme avant
echo    Q. Quitter
echo.
set "choix="
set /p "choix=Ton choix : "

if /i "%choix%"=="0" call :run 00_Diagnostic.ps1
if /i "%choix%"=="1" call :run 01_Windows_Gaming.ps1
if /i "%choix%"=="2" call :run 02_Nettoyage.ps1
if /i "%choix%"=="3" call :run 03_Reseau_Latence.ps1
if /i "%choix%"=="A" (
    call :run 01_Windows_Gaming.ps1
    call :run 02_Nettoyage.ps1
    call :run 03_Reseau_Latence.ps1
)
if /i "%choix%"=="R" call :run 99_Restaurer.ps1
if /i "%choix%"=="Q" exit /b
goto menu

:run
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0%~1"
echo.
pause
exit /b
