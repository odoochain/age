@echo off
setlocal
if defined SCOOP (set "SCOOP_ROOT=%SCOOP%") else if exist "d:\programs\scoop" (set "SCOOP_ROOT=d:\programs\scoop") else (set "SCOOP_ROOT=C:\Users\%USERNAME%\scoop")
set "MSYS2=%SCOOP_ROOT%\apps\msys2\current"
set "PATH=%MSYS2%\mingw64\bin;%MSYS2%\usr\bin;%PATH%"
"%MSYS2%\usr\bin\bash.exe" -lc "export PATH=/mingw64/bin:/usr/bin:$PATH && cd D:/odoochain/age-source && sed -i 's|#include \"parser/cypher_gram_def.h\"|#ifdef _WIN32\n#undef IN\n#undef OUT\n#undef DELETE\n#undef VOID\n#undef OPTIONAL\n#undef near\n#undef far\n#endif\n#include \"parser/cypher_gram_def.h\"|' src/include/parser/cypher_gram.h && grep -n 'undef\|cypher_gram_def' src/include/parser/cypher_gram.h"
endlocal
