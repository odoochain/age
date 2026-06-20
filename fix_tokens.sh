#!/bin/bash
export PATH=/mingw64/bin:/mingw64/x86_64-w64-mingw32/bin:/usr/bin:$PATH
cd D:/dev/lawgraph/age-source

# Fix 1: Rename STRING, CHAR tokens in grammar (conflict with Windows typedefs)
sed -i 's/%token <string> DECIMAL STRING/%token <string> DECIMAL CYTOK_STRING/' src/backend/parser/cypher_gram.y
sed -i 's/%token <character> CHAR/%token <character> CYTOK_CHAR/' src/backend/parser/cypher_gram.y
sed -i 's/    | STRING$/    | CYTOK_STRING/' src/backend/parser/cypher_gram.y
sed -i 's/    uint nlen/    unsigned int nlen/' src/backend/parser/cypher_gram.y

# Fix 2: Update type_map in cypher_parser.c
sed -i 's/        STRING,/        CYTOK_STRING,/' src/backend/parser/cypher_parser.c
sed -i 's/        CHAR,/        CYTOK_CHAR,/' src/backend/parser/cypher_parser.c

# Fix 3: Add Windows macro undefs to cypher_gram.h (IN, DELETE, OPTIONAL etc.)
# Replace the simple DELETE-only undef with full set
python3 -c "
import re
with open('src/include/parser/cypher_gram.h', 'r') as f:
    content = f.read()
# Remove any existing #ifdef DELETE block
content = re.sub(r'#ifdef DELETE\s*#undef DELETE\s*#endif\s*', '', content)
# Add full undef block before include
old = '#include \"parser/cypher_gram_def.h\"'
new = '''#ifdef _WIN32
#undef IN
#undef OUT
#undef DELETE
#undef VOID
#undef OPTIONAL
#undef near
#undef far
#endif
#include \"parser/cypher_gram_def.h\"'''
content = content.replace(old, new)
with open('src/include/parser/cypher_gram.h', 'w') as f:
    f.write(content)
"

# Fix 4: clock_gettime -> GetSystemTimeAsFileTime for Windows
python3 -c "
with open('src/backend/utils/adt/agtype.c', 'r') as f:
    content = f.read()
old = '''    /* get the system time and convert it to milliseconds */
    clock_gettime(CLOCK_REALTIME, &ts);
    ms += (ts.tv_sec * 1000) + (ts.tv_nsec / 1000000);'''
new = '''    /* get the system time and convert it to milliseconds */
#ifdef _WIN32
    {
        FILETIME ft;
        GetSystemTimeAsFileTime(&ft);
        uint64_t t = ((uint64_t)ft.dwHighDateTime << 32) | ft.dwLowDateTime;
        ms = (long)((t - 116444736000000000ULL) / 10000);
    }
#else
    clock_gettime(CLOCK_REALTIME, &ts);
    ms += (ts.tv_sec * 1000) + (ts.tv_nsec / 1000000);
#endif'''
content = content.replace(old, new)
with open('src/backend/utils/adt/agtype.c', 'w') as f:
    f.write(content)
"

# Fix 5: realpath -> _fullpath for Windows
python3 -c "
with open('src/backend/utils/load/age_load.c', 'r') as f:
    content = f.read()
old = '    resolved = realpath(path, NULL);'
new = '''#ifdef _WIN32
    resolved = _fullpath(NULL, path, MAXPGPATH);
#else
    resolved = realpath(path, NULL);
#endif'''
content = content.replace(old, new)
with open('src/backend/utils/load/age_load.c', 'w') as f:
    f.write(content)
"

echo "=== All fixes applied ==="

# Verify all changes
echo "--- cypher_gram.y ---"
grep -n "CYTOK_STRING\|CYTOK_CHAR\|unsigned int nlen" src/backend/parser/cypher_gram.y
echo "--- cypher_parser.c ---"
grep -n "CYTOK_STRING\|CYTOK_CHAR" src/backend/parser/cypher_parser.c
echo "--- cypher_gram.h ---"
grep -n "undef\|cypher_gram_def" src/include/parser/cypher_gram.h
echo "--- agtype.c ---"
grep -n "GetSystemTimeAsFileTime\|clock_gettime\|_WIN32" src/backend/utils/adt/agtype.c | head -10
echo "--- age_load.c ---"
grep -n "_fullpath\|realpath\|_WIN32" src/backend/utils/load/age_load.c
