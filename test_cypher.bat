@echo off
setlocal
if defined SCOOP (set "SCOOP_ROOT=%SCOOP%") else if exist "d:\programs\scoop" (set "SCOOP_ROOT=d:\programs\scoop") else (set "SCOOP_ROOT=C:\Users\%USERNAME%\scoop")
set "MSYS2=%SCOOP_ROOT%\apps\msys2\current"
set "PATH=%MSYS2%\mingw64\bin;%MSYS2%\usr\bin;%PATH%"
set "DB=%~1"
if "%DB%"=="" set "DB=age_test"
"%MSYS2%\usr\bin\bash.exe" -lc "cd \"$(cygpath -u '%~dp0')\" && export PATH=/mingw64/bin:/usr/bin:$PATH && psql -p 5433 -d '%DB%' -f test_cypher.sql 2>&1"
endlocal
