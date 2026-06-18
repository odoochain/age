@echo off
"C:\Program Files\Git\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && pg_ctl -D /tmp/pgdata status 2>&1"
