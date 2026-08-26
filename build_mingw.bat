@echo off
setlocal
if defined SCOOP (set "SCOOP_ROOT=%SCOOP%") else if exist "d:\programs\scoop" (set "SCOOP_ROOT=d:\programs\scoop") else (set "SCOOP_ROOT=C:\Users\%USERNAME%\scoop")
set "MSYS2=%SCOOP_ROOT%\apps\msys2\current"
if not exist "%MSYS2%\usr\bin\bash.exe" (
  echo ERROR: MSYS2 not found: %MSYS2%
  exit /b 1
)
set "PATH=%MSYS2%\mingw64\bin;%MSYS2%\mingw64\x86_64-w64-mingw32\bin;%MSYS2%\usr\bin;%PATH%"
cd /d "%~dp0"
"%MSYS2%\usr\bin\bash.exe" -lc "export PATH=/mingw64/bin:/mingw64/x86_64-w64-mingw32/bin:/usr/bin:$PATH && make clean > /tmp/age_clean.log 2>&1 && make PG_CONFIG=/mingw64/bin/pg_config BISON=/usr/bin/bison FLEX=/usr/bin/flex PERL=/mingw64/bin/perl > /tmp/age_build.log 2>&1; echo EXIT_CODE=$? > /tmp/age_exit.txt"
type "%MSYS2%\tmp\age_exit.txt"
endlocal
