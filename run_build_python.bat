@echo off
setlocal
if defined SCOOP (set "SCOOP_ROOT=%SCOOP%") else if exist "d:\programs\scoop" (set "SCOOP_ROOT=d:\programs\scoop") else (set "SCOOP_ROOT=C:\Users\%USERNAME%\scoop")
set "MSYS2=%SCOOP_ROOT%\apps\msys2\current"
set "PATH=%MSYS2%\mingw64\bin;%MSYS2%\usr\bin;%PATH%"
echo === Building graph with Python ===
"%MSYS2%\usr\bin\bash.exe" -lc "export PATH=/mingw64/bin:/usr/bin:$PATH && python D:/odoochain/age-source/build_graph.py 2>&1"
endlocal
