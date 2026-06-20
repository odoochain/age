@echo off
echo === Port 5432 (scoop PG) ===
"C:\Users\mirroam\scoop\apps\postgresql\current\bin\psql.exe" -p 5432 -h localhost -U odoo -d baraka -c "SELECT schemaname, count(*) AS table_count FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema','ag_catalog') GROUP BY schemaname ORDER BY schemaname;" 2>&1
echo.
"C:\Users\mirroam\scoop\apps\postgresql\current\bin\psql.exe" -p 5432 -h localhost -U odoo -d baraka -c "SELECT sum(n_live_tup) AS total_rows FROM pg_stat_user_tables;" 2>&1
echo.
echo === Port 5433 (MSYS2 PG) ===
"C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && psql -p 5433 -d baraka -c \"SELECT schemaname, count(*) AS table_count FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema','ag_catalog') GROUP BY schemaname ORDER BY schemaname;\" 2>&1"
echo.
"C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && psql -p 5433 -d baraka -c \"SELECT sum(n_live_tup) AS total_rows FROM pg_stat_user_tables;\" 2>&1"
