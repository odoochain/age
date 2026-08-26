@echo off
setlocal
if defined SCOOP (set "SCOOP_ROOT=%SCOOP%") else if exist "d:\programs\scoop" (set "SCOOP_ROOT=d:\programs\scoop") else (set "SCOOP_ROOT=C:\Users\%USERNAME%\scoop")
set "MSYS2=%SCOOP_ROOT%\apps\msys2\current"
set "PATH=%MSYS2%\mingw64\bin;%MSYS2%\usr\bin;%PATH%"
echo === Exporting baraka schema from port 5433 ===
"%MSYS2%\usr\bin\bash.exe" -lc "export PATH=/mingw64/bin:/usr/bin:$PATH && pg_dump -p 5433 -d baraka --schema-only --no-owner --no-privileges --file=D:/odoochain/age-source/baraka_schema.sql 2>&1"
echo === Done ===
dir D:\odoochain\age-source\baraka_schema.sql
endlocal
