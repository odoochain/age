@echo off
"C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && psql -p 5433 -d postgres -c \"SELECT datname, datdba::regrole AS owner, encoding, datcollate FROM pg_database WHERE datistemplate=false ORDER BY datname;\" 2>&1"
