from pathlib import Path

clean_bat = r"""@echo off
setlocal EnableExtensions
title KDLP OOM Demo Setup

:: Self-elevate to Administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

set "IMAGE=f26_kdlp_container"
set "NAME=oom-demo"
set "WORKDIR=%~dp0"

cd /d "%WORKDIR%"

echo.
echo ============================================
echo   KDLP Linux OOM Demo - Environment Setup
echo ============================================
echo.
echo Folder: %WORKDIR%
echo Image : %IMAGE%
echo Name  : %NAME%
echo.

where podman >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Podman was not found in PATH.
    echo Start Podman Desktop or the Podman machine and try again.
    pause
    exit /b 1
)

echo [1/6] Checking Podman...
podman info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Podman is installed but is not responding.
    echo Try: podman machine start
    pause
    exit /b 1
)
echo       OK

echo [2/6] Checking KDLP image...
podman image exists "%IMAGE%"
if errorlevel 1 (
    echo [ERROR] Image "%IMAGE%" was not found.
    podman images
    pause
    exit /b 1
)
echo       OK

echo [3/6] Checking memhog.c...
if not exist "%WORKDIR%memhog.c" (
    echo [ERROR] memhog.c is missing from:
    echo %WORKDIR%
    pause
    exit /b 1
)
echo       OK

echo [4/6] Compiling memhog.c...
podman run --rm ^
  --entrypoint /bin/bash ^
  -v "%WORKDIR%:/work" ^
  -w /work ^
  "%IMAGE%" ^
  -c "gcc -O2 -Wall -o memhog memhog.c"

if errorlevel 1 (
    echo [ERROR] Compilation failed.
    pause
    exit /b 1
)
echo       OK

echo [5/6] Starting memory-limited container...
podman rm -f "%NAME%" >nul 2>&1

podman run -d --rm ^
  --name "%NAME%" ^
  --memory=256m ^
  --memory-swap=256m ^
  --entrypoint /usr/bin/sleep ^
  "%IMAGE%" ^
  infinity >nul

if errorlevel 1 (
    echo [ERROR] Could not start "%NAME%".
    pause
    exit /b 1
)
echo       OK

echo [6/6] Copying memhog into container...
podman cp "%WORKDIR%memhog" "%NAME%:/tmp/memhog" >nul
if errorlevel 1 (
    echo [ERROR] Could not copy memhog into the container.
    podman rm -f "%NAME%" >nul 2>&1
    pause
    exit /b 1
)

podman exec "%NAME%" chmod +x /tmp/memhog >nul 2>&1
echo       OK

echo.
echo ============================================
echo   READY
echo ============================================
echo.
echo Container "%NAME%" is running.
echo Memory limit : 256 MB
echo Swap limit   : 256 MB total
echo.
echo Suggested next command:
echo   podman ps
echo.
echo The command window will remain open.
echo Type EXIT when you are finished.
echo.

cd /d "%WORKDIR%"
cmd /k
"""

path = Path("/mnt/data/KDLP_OOM_START.bat")
path.write_text(clean_bat, encoding="utf-8", newline="\r\n")
print(path)
