@echo off
set PATH=C:\Users\mirroam\scoop\apps\msys2\current\mingw64\bin;C:\Users\mirroam\scoop\apps\msys2\current\usr\bin;%PATH%
"C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && pg_ctl -D D:/mydata/pgdata -o '-p 5433' -l /tmp/pg_logfile start 2>&1 && sleep 3 && psql -p 5433 -d postgres -c 'SELECT version();' 2>&1"
