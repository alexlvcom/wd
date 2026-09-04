@echo off
setlocal
set "_WD_TARGET_FILE=%TEMP%\wd-%RANDOM%-%RANDOM%.tmp"
set "WD_SHELL_TARGET_FILE=%_WD_TARGET_FILE%"
wd-core.exe %*
set "_WD_EXIT=%ERRORLEVEL%"
set "WD_SHELL_TARGET_FILE="
if not exist "%_WD_TARGET_FILE%" goto no_target
set /p "_WD_TARGET="<"%_WD_TARGET_FILE%"
del /q "%_WD_TARGET_FILE%" >nul 2>&1
if not defined _WD_TARGET goto no_target
endlocal & cd /d "%_WD_TARGET%" & exit /b %_WD_EXIT%

:no_target
if exist "%_WD_TARGET_FILE%" del /q "%_WD_TARGET_FILE%" >nul 2>&1
endlocal & exit /b %_WD_EXIT%
