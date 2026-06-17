#!/bin/bash
export PATH=/mingw64/bin:/mingw64/x86_64-w64-mingw32/bin:/usr/bin:$PATH
cd D:/odoochain/odoo19/age-source

# Fix 1: Rename STRING, CHAR tokens in grammar
sed -i 's/%token <string> DECIMAL STRING/%token <string> DECIMAL CYTOK_STRING/' src/backend/parser/cypher_gram.y
sed -i 's/%token <character> CHAR/%token <character> CYTOK_CHAR/' src/backend/parser/cypher_gram.y
sed -i 's/    | STRING$/    | CYTOK_STRING/' src/backend/parser/cypher_gram.y
sed -i 's/    uint nlen/    unsigned int nlen/' src/backend/parser/cypher_gram.y

# Fix 2: Update type_map in cypher_parser.c
sed -i 's/        STRING,/        CYTOK_STRING,/' src/backend/parser/cypher_parser.c
sed -i 's/        CHAR,/        CYTOK_CHAR,/' src/backend/parser/cypher_parser.c

# Fix 3: Fix DELETE token conflict with Windows macro
# DELETE is a macro from winnt.h. We need to undef it before the enum
sed -i 's/#include "parser\/cypher_gram_def.h"/#ifdef DELETE\n#undef DELETE\n#endif\n#include "parser\/cypher_gram_def.h"/' src/include/parser/cypher_gram.h

echo "All fixes applied"

# Verify
grep -n "CYTOK_STRING\|CYTOK_CHAR\|unsigned int nlen" src/backend/parser/cypher_gram.y
grep -n "CYTOK_STRING\|CYTOK_CHAR" src/backend/parser/cypher_parser.c
grep -n "undef DELETE\|cypher_gram_def.h" src/include/parser/cypher_gram.h
