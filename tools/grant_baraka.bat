@echo off
"C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && psql -p 5433 -d baraka -c \"GRANT ALL ON SCHEMA public TO odoo; GRANT ALL ON DATABASE baraka TO odoo;\" 2>&1 && psql -p 5433 -d postgres -c \"SELECT datname, datdba::regrole AS owner FROM pg_database WHERE datname='baraka';\" 2>&1"
