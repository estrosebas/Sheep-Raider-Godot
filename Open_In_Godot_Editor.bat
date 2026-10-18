@echo off
title Ralph Wolf - Godot Editor
setlocal EnableDelayedExpansion

set "CURRENT_DIR=%~dp0"
if "%CURRENT_DIR:~-1%"=="\" set "CURRENT_DIR=%CURRENT_DIR:~0,-1%"
set "PROJ_PATH=%CURRENT_DIR%"

set "GODOT_EXE=C:\Users\estro\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"

if not exist "%GODOT_EXE%" (
    echo [ERROR] No se encontro el ejecutable de Godot en:
    echo "%GODOT_EXE%"
    echo.
    pause
    exit /b 1
)

if not exist "%CURRENT_DIR%\project.godot" (
    echo [ERROR] No se encontro 'project.godot' en:
    echo "%CURRENT_DIR%"
    echo.
    pause
    exit /b 1
)

echo ======================================================
echo   Abriendo proyecto Ralph Wolf en el Editor de Godot...
echo ======================================================
start "" "%GODOT_EXE%" -e --path "%PROJ_PATH%"
ping -n 2 127.0.0.1 >nul
exit /b 0
