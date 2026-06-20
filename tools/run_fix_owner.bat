@echo off
"C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && psql -p 5433 -d baraka -f D:/dev/lawgraph/age-source/fix_owner.sql 2>&1 | tail -5"
