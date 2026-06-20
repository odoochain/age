@echo off
set PATH=C:\Users\mirroam\scoop\apps\msys2\current\mingw64\bin;C:\Users\mirroam\scoop\apps\msys2\current\mingw64\x86_64-w64-mingw32\bin;C:\Users\mirroam\scoop\apps\msys2\current\usr\bin;%PATH%
cd /d "%~dp0"
bash -lc "export PATH=/mingw64/bin:/mingw64/x86_64-w64-mingw32/bin:/usr/bin:$PATH && cd D:/dev/lawgraph/age-source && make PG_CONFIG=/mingw64/bin/pg_config BISON=/usr/bin/bison FLEX=/usr/bin/flex PERL=/mingw64/bin/perl install 2>&1; echo EXIT_CODE=$? > /tmp/age_install.txt"
type C:\Users\mirroam\scoop\apps\msys2\current\tmp\age_install.txt
