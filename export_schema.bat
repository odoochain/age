@echo off
echo === Exporting baraka schema from port 5433 ===
"C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && pg_dump -p 5433 -d baraka --schema-only --no-owner --no-privileges --file=D:/dev/lawgraph/age-source/baraka_schema.sql 2>&1"
echo === Done ===
dir D:\dev\lawgraph\age-source\baraka_schema.sql
