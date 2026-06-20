@echo off
"C:\Program Files\Git\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && psql -p 5433 -d age_test -f D:/dev/lawgraph/age-source/test_cypher.sql 2>&1"
