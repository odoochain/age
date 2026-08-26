@echo off
setlocal
if defined SCOOP (set "SCOOP_ROOT=%SCOOP%") else if exist "d:\programs\scoop" (set "SCOOP_ROOT=d:\programs\scoop") else (set "SCOOP_ROOT=C:\Users\%USERNAME%\scoop")
set "MSYS2=%SCOOP_ROOT%\apps\msys2\current"
set "PATH=%MSYS2%\mingw64\bin;%MSYS2%\usr\bin;%PATH%"
"%MSYS2%\usr\bin\bash.exe" -lc "export PATH=/mingw64/bin:/usr/bin:$PATH && psql -p 5433 -d age_test -c \"LOAD 'age'; SET search_path = ag_catalog, \\\"\\\"$user\\\", public;\" 2>&1 && psql -p 5433 -d age_test -c \"LOAD 'age'; SET search_path = ag_catalog, \\\"\\\"$user\\\", public; SELECT * FROM cypher('CREATE (n:Person {name: Alice, age: 30}) RETURN n') AS (v agtype);\" 2>&1"
endlocal
