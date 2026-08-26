@echo off
setlocal
if defined SCOOP (set "SCOOP_ROOT=%SCOOP%") else if exist "d:\programs\scoop" (set "SCOOP_ROOT=d:\programs\scoop") else (set "SCOOP_ROOT=C:\Users\%USERNAME%\scoop")
set "MSYS2=%SCOOP_ROOT%\apps\msys2\current"
set "PATH=%MSYS2%\mingw64\bin;%MSYS2%\usr\bin;%PATH%"
if /i "%~1"=="start" goto :start
if /i "%~1"=="status" goto :status
if /i "%~1"=="stop" goto :stop
if /i "%~1"=="restart" goto :restart
echo Usage: %~nx0 start^|status^|stop^|restart
exit /b 2

:start
"%MSYS2%\usr\bin\bash.exe" -lc "export PATH=/mingw64/bin:/usr/bin:$PATH && if [ -d D:/mydata/pgdata ] && [ -f D:/mydata/pgdata/PG_VERSION ]; then echo 'Data dir exists, starting directly...'; else mkdir -p D:/mydata/pgdata && initdb -D D:/mydata/pgdata 2>&1 | tail -3; fi && pg_ctl -D D:/mydata/pgdata -o '-p 5433' -l D:/mydata/pgdata/logfile start 2>&1 && sleep 2 && psql -p 5433 -d postgres -c 'SELECT version();' 2>&1"
goto :eof

:status
"%MSYS2%\usr\bin\bash.exe" -lc "export PATH=/mingw64/bin:/usr/bin:$PATH && echo '=== pg_ctl status ===' && pg_ctl -D D:/mydata/pgdata status 2>&1 && echo '' && echo '=== connection test ===' && psql -p 5433 -d postgres -c 'SELECT version();' 2>&1 && echo '' && echo '=== active connections ===' && psql -p 5433 -d postgres -c \"SELECT pid, usename, datname, state, query_start FROM pg_stat_activity WHERE datname IS NOT NULL;\" 2>&1"
goto :eof

:stop
"%MSYS2%\usr\bin\bash.exe" -lc "export PATH=/mingw64/bin:/usr/bin:$PATH && pg_ctl -D D:/mydata/pgdata stop 2>&1"
goto :eof

:restart
"%MSYS2%\usr\bin\bash.exe" -lc "export PATH=/mingw64/bin:/usr/bin:$PATH && pg_ctl -D D:/mydata/pgdata stop 2>&1; sleep 1 && pg_ctl -D D:/mydata/pgdata -o '-p 5433' -l D:/mydata/pgdata/logfile start 2>&1 && sleep 2 && psql -p 5433 -d postgres -c 'SELECT version();' 2>&1"
goto :eof
