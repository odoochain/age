@echo off
echo === Restoring from SQL dump to UTF-8 baraka ===
"C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && psql -p 5433 -d baraka -f D:/mydata/odoomolt/dump-baraka-5432.sql 2>&1 | tail -5"
echo.
echo === Verify ===
"C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && psql -p 5433 -d baraka -c \"SELECT 'res_partner' AS tbl, count(*) FROM res_partner UNION ALL SELECT 'mail_message', count(*) FROM mail_message UNION ALL SELECT 'ir_model_data', count(*) FROM ir_model_data UNION ALL SELECT 'ir_attachment', count(*) FROM ir_attachment UNION ALL SELECT 'res_users', count(*) FROM res_users ORDER BY 1;\" 2>&1"
