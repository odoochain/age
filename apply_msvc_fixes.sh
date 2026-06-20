#!/bin/bash
cd D:/dev/lawgraph/age-source

# Fix 1: Rename conflicting tokens
sed -i 's/%token <string> DECIMAL STRING/%token <string> DECIMAL CYTOK_STRING/' src/backend/parser/cypher_gram.y
sed -i 's/%token <character> CHAR/%token <character> CYTOK_CHAR/' src/backend/parser/cypher_gram.y
sed -i 's/    | STRING$/    | CYTOK_STRING/' src/backend/parser/cypher_gram.y
sed -i 's/    uint nlen/    unsigned int nlen/' src/backend/parser/cypher_gram.y
sed -i 's/        STRING,/        CYTOK_STRING,/' src/backend/parser/cypher_parser.c
sed -i 's/        CHAR,/        CYTOK_CHAR,/' src/backend/parser/cypher_parser.c

# Fix 2: Remove conflicting header declarations (PG_FUNCTION_INFO_V1 linkage issue)
sed -i '/^Datum create_graph(PG_FUNCTION_ARGS);$/d' src/include/commands/graph_commands.h
sed -i '/^Datum create_vlabel(PG_FUNCTION_ARGS);$/d' src/include/commands/label_commands.h
sed -i '/^Datum create_elabel(PG_FUNCTION_ARGS);$/d' src/include/commands/label_commands.h

# Fix 3: Add extern declarations where needed (graph_generation.c uses create_graph)
sed -i '/^#include "commands\/graph_commands.h"$/a extern Datum create_graph(PG_FUNCTION_ARGS);' src/backend/utils/graph_generation.c

# Fix 4: Add Windows macro undefs to cypher_gram.h
sed -i 's|#include "parser/cypher_gram_def.h"|#ifdef _WIN32\n#undef IN\n#undef OUT\n#undef DELETE\n#undef VOID\n#undef OPTIONAL\n#undef near\n#undef far\n#endif\n#include "parser/cypher_gram_def.h"|' src/include/parser/cypher_gram.h

# Fix 5: clock_gettime -> GetSystemTimeAsFileTime
sed -i '/clock_gettime(CLOCK_REALTIME, &ts);/,/ms += (ts.tv_sec \* 1000) + (ts.tv_nsec \/ 1000000);/{
s|    clock_gettime(CLOCK_REALTIME, &ts);\n    ms += (ts.tv_sec \* 1000) + (ts.tv_nsec \/ 1000000);|#ifdef _WIN32\n    {\n        FILETIME ft;\n        GetSystemTimeAsFileTime(\&ft);\n        uint64_t t = ((uint64_t)ft.dwHighDateTime << 32) | ft.dwLowDateTime;\n        ms = (long)((t - 116444736000000000ULL) / 10000);\n    }\n#else\n    clock_gettime(CLOCK_REALTIME, \&ts);\n    ms += (ts.tv_sec * 1000) + (ts.tv_nsec / 1000000);\n#endif|
}' src/backend/utils/adt/agtype.c

# Fix 6: realpath -> _fullpath
sed -i 's|    resolved = realpath(path, NULL);|#ifdef _WIN32\n    resolved = _fullpath(NULL, path, MAXPGPATH);\n#else\n    resolved = realpath(path, NULL);\n#endif|' src/backend/utils/load/age_load.c

echo "All fixes applied"
