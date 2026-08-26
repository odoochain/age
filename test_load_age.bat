@echo off
REM Full pipeline: install extension, recreate age_test DB, run Cypher smoke test.
setlocal
if defined SCOOP (set "SCOOP_ROOT=%SCOOP%") else if exist "d:\programs\scoop" (set "SCOOP_ROOT=d:\programs\scoop") else (set "SCOOP_ROOT=C:\Users\%USERNAME%\scoop")
set "MSYS2=%SCOOP_ROOT%\apps\msys2\current"
set "PATH=%MSYS2%\mingw64\bin;%MSYS2%\usr\bin;%PATH%"
cd /d "%~dp0"

echo [1/3] Installing extension...
call "%~dp0install_mingw.bat" || exit /b 1

echo [2/3] Recreating age_test database...
"%MSYS2%\usr\bin\bash.exe" -lc "export PATH=/mingw64/bin:/usr/bin:$PATH && psql -p 5433 -d postgres -c 'DROP DATABASE IF EXISTS age_test;' && psql -p 5433 -d postgres -c 'CREATE DATABASE age_test;' && psql -p 5433 -d age_test -c 'CREATE EXTENSION age;'" || exit /b 1

echo [3/3] Running Cypher smoke test...
call "%~dp0test_cypher.bat" age_test
endlocal
