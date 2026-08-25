@echo off
"C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && psql -p 5433 -d baraka -t -A -c 'SELECT id, folder_id FROM documents_document WHERE type = ''folder'' AND folder_id IS NOT NULL;'"
