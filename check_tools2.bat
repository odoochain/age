@echo off
set PATH=C:\Users\mirroam\scoop\apps\msys2\current\mingw64\bin;C:\Users\mirroam\scoop\apps\msys2\current\usr\bin;%PATH%
"C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && which initdb && which pg_ctl && which psql && initdb --version"
