@echo off
echo === Dumping baraka from port 5432 (scoop PG) ===
"C:\Users\mirroam\scoop\apps\postgresql\current\bin\pg_dump.exe" -p 5432 -h localhost -U odoo -d baraka --encoding=UTF-8 --no-owner --no-privileges --file=D:\mydata\odoomolt\dump-baraka-5432.sql 2>&1
echo === Dump done, size: ===
dir D:\mydata\odoomolt\dump-baraka-5432.sql
