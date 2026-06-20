@echo off
echo === Step 1: Drop and recreate baraka with UTF-8 ===
"C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && psql -p 5433 -d postgres -c 'SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '\''baraka'\'' AND pid <> pg_backend_pid();' 2>&1 && psql -p 5433 -d postgres -c 'DROP DATABASE baraka;' 2>&1 && psql -p 5433 -d postgres -c 'CREATE DATABASE baraka OWNER odoo ENCODING '\''UTF8'\'' LC_COLLATE '\''C'\'' LC_CTYPE '\''C'\'' TEMPLATE template0;' 2>&1 && echo Database recreated OK"
echo.
echo === Step 2: Enable extensions ===
"C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && psql -p 5433 -d baraka -c 'CREATE EXTENSION IF NOT EXISTS age;' 2>&1 && psql -p 5433 -d baraka -c 'CREATE EXTENSION IF NOT EXISTS vector;' 2>&1 && psql -p 5433 -d baraka -c 'ALTER SCHEMA public OWNER TO odoo;' 2>&1 && echo Extensions enabled OK"
echo.
echo === Step 3: Restore data ===
"C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && psql -p 5433 -d baraka -f D:/mydata/odoomolt/dump-baraka-5432.sql 2>&1 | tail -5" && echo Restore OK
echo.
echo === Step 4: Fix ownership ===
"C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && psql -p 5433 -d baraka -f D:/dev/lawgraph/age-source/tools/fix_owner.sql 2>&1 | tail -5" && echo Ownership fixed OK
echo.
echo === Step 5: Verify ===
"C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && psql -p 5433 -d baraka -c \"SELECT 'tables' AS metric, count(*) AS val FROM pg_tables WHERE schemaname='public' UNION ALL SELECT 'res_partner', count(*) FROM res_partner UNION ALL SELECT 'mail_message', count(*) FROM mail_message UNION ALL SELECT 'ir_model_data', count(*) FROM ir_model_data UNION ALL SELECT 'ir_attachment', count(*) FROM ir_attachment UNION ALL SELECT 'res_users', count(*) FROM res_users ORDER BY 1;\" 2>&1"
echo.
echo === Migration complete ===
