@echo off
setlocal EnableExtensions EnableDelayedExpansion
title KDLP OOM Live Demo
cd /d "%~dp0"

set "IMAGE=f26_kdlp_container"
set "NAME=oom-demo"

echo.
echo ============================================
echo   KDLP OOM LIVE DEMO
echo ============================================
echo.

:: ------------------------------------------------------------
:: Start from a clean container every time
:: ------------------------------------------------------------
echo [0] Resetting demo container...
podman rm -f "%NAME%" >nul 2>&1

podman run -d --rm ^
  --name "%NAME%" ^
  --memory=256m ^
  --memory-swap=256m ^
  --entrypoint /usr/bin/sleep ^
  "%IMAGE%" ^
  infinity >nul

if errorlevel 1 (
    echo [ERROR] Could not start container "%NAME%".
    echo Run KDLP_OOM_START.bat first to verify the environment.
    pause
    exit /b 1
)

if not exist "%~dp0memhog" (
    echo [ERROR] memhog executable is missing.
    echo Run KDLP_OOM_START.bat first.
    podman rm -f "%NAME%" >nul 2>&1
    pause
    exit /b 1
)

podman cp "%~dp0memhog" "%NAME%:/tmp/memhog" >nul
podman exec "%NAME%" chmod +x /tmp/memhog >nul 2>&1

echo       Clean 256 MB container ready.

:: ------------------------------------------------------------
:: Start A and B
:: ------------------------------------------------------------
echo.
echo [1] Starting Process A and Process B...
podman exec -d "%NAME%" /tmp/memhog 80 A >nul
podman exec -d "%NAME%" /tmp/memhog 80 B >nul

timeout /t 2 /nobreak >nul

echo.
echo Current processes:
podman top "%NAME%" pid args

:: ------------------------------------------------------------
:: Find PIDs robustly
:: ------------------------------------------------------------
echo.
echo [2] Finding Process A and Process B PIDs...

set "PID_A="
set "PID_B="

for /f "tokens=1" %%P in ('podman top "%NAME%" pid args ^| findstr /c:"/tmp/memhog 80 A"') do set "PID_A=%%P"
for /f "tokens=1" %%P in ('podman top "%NAME%" pid args ^| findstr /c:"/tmp/memhog 80 B"') do set "PID_B=%%P"

if not defined PID_A (
    echo [ERROR] Could not find Process A.
    pause
    exit /b 1
)

if not defined PID_B (
    echo [ERROR] Could not find Process B.
    pause
    exit /b 1
)

echo Process A PID = !PID_A!
echo Process B PID = !PID_B!

:: ------------------------------------------------------------
:: Show initial OOM values
:: ------------------------------------------------------------
echo.
echo [3] Initial OOM values
echo.
echo Process A
echo   oom_score:
podman exec "%NAME%" cat /proc/!PID_A!/oom_score
echo   oom_score_adj:
podman exec "%NAME%" cat /proc/!PID_A!/oom_score_adj

echo.
echo Process B
echo   oom_score:
podman exec "%NAME%" cat /proc/!PID_B!/oom_score
echo   oom_score_adj:
podman exec "%NAME%" cat /proc/!PID_B!/oom_score_adj

echo.
echo Press any key to increase Process A's OOM preference...
pause >nul

:: ------------------------------------------------------------
:: Adjust A
:: ------------------------------------------------------------
echo.
echo [4] Setting Process A oom_score_adj to 1000...
podman exec "%NAME%" sh -c "echo 1000 > /proc/!PID_A!/oom_score_adj"

echo.
echo Process A after adjustment
echo   oom_score:
podman exec "%NAME%" cat /proc/!PID_A!/oom_score
echo   oom_score_adj:
podman exec "%NAME%" cat /proc/!PID_A!/oom_score_adj

echo.
echo Process B remains unchanged
echo   oom_score:
podman exec "%NAME%" cat /proc/!PID_B!/oom_score
echo   oom_score_adj:
podman exec "%NAME%" cat /proc/!PID_B!/oom_score_adj

echo.
echo Press any key to create memory pressure...
pause >nul

:: ------------------------------------------------------------
:: Trigger pressure
:: ------------------------------------------------------------
echo.
echo [5] Starting Process C with 120 MiB...
podman exec -d "%NAME%" /tmp/memhog 120 C >nul

timeout /t 3 /nobreak >nul

:: ------------------------------------------------------------
:: Show result
:: ------------------------------------------------------------
echo.
echo [6] Processes after memory pressure:
podman top "%NAME%" pid args

echo.
echo [7] Memory status:
podman stats --no-stream "%NAME%"

echo.
echo [8] Kernel cgroup memory events:
podman exec "%NAME%" cat /sys/fs/cgroup/memory.events.local

echo.
echo ============================================
echo   DEMO COMPLETE
echo ============================================
echo.
echo Expected result:
echo   Process A is gone.
echo   Process B and Process C remain.
echo   oom_kill should show 1.
echo.
echo Press any key to keep this window open.
pause >nul
cmd /k
