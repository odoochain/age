@echo off
set PATH=C:\Users\mirroam\scoop\apps\msys2\current\mingw64\bin;C:\Users\mirroam\scoop\apps\msys2\current\usr\bin;%PATH%
"C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && rm -rf D:/tmp/pgdata && initdb -D D:/tmp/pgdata 2>&1 | tail -3 && pg_ctl -D D:/tmp/pgdata -o '-p 5433' -l D:/tmp/pgdata/logfile start 2>&1 && sleep 2 && psql -p 5433 -d postgres -c 'SELECT version();' 2>&1"
