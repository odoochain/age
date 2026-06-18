@echo off
"C:\Program Files\Git\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && cat D:/tmp/pgdata/logfile 2>&1 | tail -10"
