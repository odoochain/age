@echo off
"C:\Program Files\Git\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && which initdb && which pg_ctl && which psql && initdb --version && pg_ctl --version"
