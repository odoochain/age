@echo off
"C:\Program Files\Git\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && psql -p 5433 -d postgres -c 'SELECT version();' 2>&1 && psql -p 5433 -d postgres -c 'CREATE EXTENSION IF NOT EXISTS age;' 2>&1 && psql -p 5433 -d postgres -f D:/dev/lawgraph/age-source/test_age.sql 2>&1"
