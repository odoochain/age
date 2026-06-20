@echo off
"C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && psql -p 5433 -d baraka -c \"SELECT schemaname, tablename, tableowner FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema','ag_catalog') ORDER BY schemaname, tablename;\" 2>&1"
