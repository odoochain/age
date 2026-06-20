@echo off
set PATH=C:\Users\mirroam\scoop\apps\msys2\current\mingw64\bin;C:\Users\mirroam\scoop\apps\msys2\current\usr\bin;%PATH%
"C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && psql -p 5433 -d age_test -c \"LOAD 'age'; SET search_path = ag_catalog, \\\"\\\"$user\\\"\\\", public;\" 2>&1 && psql -p 5433 -d age_test -c \"LOAD 'age'; SET search_path = ag_catalog, \\\"\\\"$user\\\"\\\", public; SELECT * FROM cypher('CREATE (n:Person {name: Alice, age: 30}) RETURN n') AS (v agtype);\" 2>&1"
