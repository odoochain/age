@echo off
setlocal
if defined SCOOP (set "SCOOP_ROOT=%SCOOP%") else if exist "d:\programs\scoop" (set "SCOOP_ROOT=d:\programs\scoop") else (set "SCOOP_ROOT=C:\Users\%USERNAME%\scoop")
set "MSYS2=%SCOOP_ROOT%\apps\msys2\current"
set "PATH=%MSYS2%\mingw64\bin;%MSYS2%\usr\bin;%PATH%"
"%MSYS2%\usr\bin\bash.exe" -lc "export PATH=/mingw64/bin:/usr/bin:$PATH && cd D:/odoochain/age-source && sed -i 's|    clock_gettime(CLOCK_REALTIME, \&ts);|    /\* get the system time and convert it to milliseconds \*/\n#ifdef _WIN32\n    {\n        FILETIME ft;\n        GetSystemTimeAsFileTime(\&ft);\n        uint64_t t = ((uint64_t)ft.dwHighDateTime << 32) | ft.dwLowDateTime;\n        ms = (long)((t - 116444736000000000ULL) / 10000);\n    }\n#else\n    clock_gettime(CLOCK_REALTIME, \&ts);\n    ms += (ts.tv_sec * 1000) + (ts.tv_nsec / 1000000);\n#endif|' src/backend/utils/adt/agtype.c"
endlocal
