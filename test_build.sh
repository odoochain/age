#!/bin/bash
export PATH=/mingw64/bin:/mingw64/x86_64-w64-mingw32/bin:/usr/bin:$PATH

echo "=== Fix zlib1.dll ==="
cp /mingw64/bin/zlib1.dll /mingw64/x86_64-w64-mingw32/bin/zlib1.dll 2>&1
echo "copy exit=$?"

echo "=== Test as.exe ==="
/mingw64/x86_64-w64-mingw32/bin/as.exe --version 2>&1; echo "as exit=$?"

echo "=== Test gcc -c ==="
echo 'int x=1;' > /tmp/test.c
gcc -c /tmp/test.c -o /tmp/test.o 2>&1; echo "gcc exit=$?"
ls -la /tmp/test.o 2>&1
