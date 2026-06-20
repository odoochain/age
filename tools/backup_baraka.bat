@echo off
"C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && pg_dumpall -p 5433 -h localhost --encoding=UTF-8 --no-role-passwords --file D:/mydata/odoomolt/dump-baraka-202606210201.sql 2>&1"
