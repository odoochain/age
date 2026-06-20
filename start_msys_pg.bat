@echo off
set PATH=C:\Users\mirroam\scoop\apps\msys2\current\mingw64\bin;C:\Users\mirroam\scoop\apps\msys2\current\usr\bin;%PATH%

if /i "%~1"=="start" goto :start
if /i "%~1"=="status" goto :status
if /i "%~1"=="stop" goto :stop
if /i "%~1"=="restart" goto :restart

:start
"C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && if [ -d D:/mydata/pgdata ] && [ -f D:/mydata/pgdata/PG_VERSION ]; then echo 'Data dir exists, starting directly...'; else mkdir -p D:/mydata/pgdata && initdb -D D:/mydata/pgdata 2>&1 | tail -3; fi && pg_ctl -D D:/mydata/pgdata -o '-p 5433' -l D:/mydata/pgdata/logfile start 2>&1 && sleep 2 && psql -p 5433 -d postgres -c 'SELECT version();' 2>&1"
goto :eof

:status
"C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && echo '=== pg_ctl status ===' && pg_ctl -D D:/mydata/pgdata status 2>&1 && echo '' && echo '=== connection test ===' && psql -p 5433 -d postgres -c 'SELECT version();' 2>&1 && echo '' && echo '=== active connections ===' && psql -p 5433 -d postgres -c \"SELECT pid, usename, datname, state, query_start FROM pg_stat_activity WHERE datname IS NOT NULL;\" 2>&1"
goto :eof

:stop
"C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && pg_ctl -D D:/mydata/pgdata stop 2>&1"
goto :eof

:restart
"C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && pg_ctl -D D:/mydata/pgdata stop 2>&1; sleep 1 && pg_ctl -D D:/mydata/pgdata -o '-p 5433' -l D:/mydata/pgdata/logfile start 2>&1 && sleep 2 && psql -p 5433 -d postgres -c 'SELECT version();' 2>&1"
