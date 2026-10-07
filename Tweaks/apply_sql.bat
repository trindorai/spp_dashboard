@echo off
setlocal
cd /d "%~dp0"
set "MYSQL=%~dp0..\SPP_Server\Server\Database\bin\mysql.exe"
rem log goes to the personal (git-ignored) MyTweaks folder
if not exist "%~dp0..\MyTweaks" mkdir "%~dp0..\MyTweaks"
set "LOG=%~dp0..\MyTweaks\apply_sql_log.txt"
if "%~1"=="" goto usage
if not exist "%MYSQL%" goto nomysql
echo Applying %~nx1 ...
echo ===== %date% %time% : %~nx1 >> "%LOG%"
"%MYSQL%" -h127.0.0.1 -P3310 -uroot -p123456 -t wotlkmangos < "%~1" > "%TEMP%\apply_sql_out.txt" 2>&1
set "RC=%errorlevel%"
type "%TEMP%\apply_sql_out.txt"
type "%TEMP%\apply_sql_out.txt" >> "%LOG%"
echo exit code %RC% >> "%LOG%"
echo.
if not "%RC%"=="0" goto failed
echo Done. Restart the world server for it to take effect.
goto end
:failed
echo FAILED - make sure the database is running (start it from the SPP launcher).
goto end
:nomysql
echo Could not find mysql.exe at %MYSQL%
goto end
:usage
echo Usage: drag a .sql file onto this .bat file.
:end
echo.
echo Press any key to close...
pause >nul
