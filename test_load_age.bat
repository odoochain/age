@echo off
setlocal
if defined SCOOP (set "SCOOP_ROOT=%SCOOP%") else if exist "d:\programs\scoop" (set "SCOOP_ROOT=d:\programs\scoop") else (set "SCOOP_ROOT=C:\Users\%USERNAME%\scoop")
set "MSYS2=%SCOOP_ROOT%\apps\msys2\current"
set "PATH=%MSYS2%\mingw64\bin;%MSYS2%\usr\bin;%PATH%"
"%MSYS2%\usr\bin\bash.exe" -lc "export PATH=/mingw64/bin:/usr/bin:$PATH && cd D:/odoochain/age-source && make PG_CONFIG=/mingw64/bin/pg_config BISON=/usr/bin/bison FLEX=/usr/bin/flex PERL=/mingw64/bin/perl install 2>&1 && echo '=== Install done ===' && psql -p 5433 -d postgres -c 'DROP DATABASE IF EXISTS age_test;' 2>&1 && psql -p 5433 -d postgres -c 'CREATE DATABASE age_test;' 2>&1 && psql -p 5433 -d age_test -c 'CREATE EXTENSION age;' 2>&1 && echo '=== Extension loaded ===' && psql -p 5433 -d age_test -c "LOAD '\''age'\''; SET search_path = ag_catalog, \"\"$user\"\", public; SELECT * FROM cypher('CREATE (n:Person {name: \"Alice\", age: 30}) RETURN n') AS (v agtype);" 2>&1"
endlocal
