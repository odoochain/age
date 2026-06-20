@echo off
set MSYS2=C:\Users\mirroam\scoop\apps\msys2\current
set PATH=%MSYS2%\mingw64\bin;%MSYS2%\usr\bin;%PATH%
cd /d "%~dp0"
"%MSYS2%\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && bash deploy.sh %1 %2 %3 %4 %5"
