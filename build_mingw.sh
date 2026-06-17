#!/bin/bash
export PATH=/mingw64/bin:/usr/bin:$PATH
cd D:/odoochain/odoo19/age-source

exec > /tmp/age_build3.log 2>&1

# First revert source changes that were for MSVC
# Restore graph_commands.h
cat > src/include/commands/graph_commands.h << 'ENDHDR'
#ifndef AG_GRAPH_COMMANDS_H
#define AG_GRAPH_COMMANDS_H
Datum create_graph(PG_FUNCTION_ARGS);
Oid create_graph_internal(const Name graph_name);
#endif
ENDHDR

# Restore label_commands.h
cat > src/include/commands/label_commands.h << 'ENDHDR'
#ifndef AG_LABEL_COMMANDS_H
#define AG_LABEL_COMMANDS_H
#define LABEL_TYPE_VERTEX 'v'
#define LABEL_TYPE_EDGE 'e'
#define AG_DEFAULT_LABEL_EDGE "_ag_label_edge"
#define AG_DEFAULT_LABEL_VERTEX "_ag_label_vertex"
#define AG_VERTEX_COLNAME_ID "id"
#define AG_VERTEX_COLNAME_PROPERTIES "properties"
#define AG_ACCESS_FUNCTION_ID "age_id"
#define AG_VERTEX_ACCESS_FUNCTION_ID "age_id"
#define AG_VERTEX_ACCESS_FUNCTION_PROPERTIES "age_properties"
#define AG_EDGE_COLNAME_ID "id"
#define AG_EDGE_COLNAME_START_ID "start_id"
#define AG_EDGE_COLNAME_END_ID "end_id"
#define AG_EDGE_COLNAME_PROPERTIES "properties"
#define AG_EDGE_ACCESS_FUNCTION_ID "age_id"
#define AG_EDGE_ACCESS_FUNCTION_START_ID "age_start_id"
#define AG_EDGE_ACCESS_FUNCTION_END_ID "age_end_id"
#define AG_EDGE_ACCESS_FUNCTION_PROPERTIES "age_properties"
#define IS_DEFAULT_LABEL_EDGE(str) \
    (str != NULL && strcmp(AG_DEFAULT_LABEL_EDGE, str) == 0)
#define IS_DEFAULT_LABEL_VERTEX(str) \
    (str != NULL && strcmp(AG_DEFAULT_LABEL_VERTEX, str) == 0)
#define IS_AG_DEFAULT_LABEL(x) \
    (IS_DEFAULT_LABEL_EDGE(x) || IS_DEFAULT_LABEL_VERTEX(x))
void create_label(char *graph_name, char *label_name, char label_type,
                  List *parents);
Datum create_vlabel(PG_FUNCTION_ARGS);
Datum create_elabel(PG_FUNCTION_ARGS);
#endif
ENDHDR

# Restore cypher_gram.y token names
sed -i 's/%token <string> DECIMAL CYTOK_STRING/%token <string> DECIMAL STRING/' src/backend/parser/cypher_gram.y
sed -i 's/%token <character> CYTOK_CHAR/%token <character> CHAR/' src/backend/parser/cypher_gram.y
sed -i 's/| CYTOK_STRING/| STRING/' src/backend/parser/cypher_gram.y

# Restore cypher_parser.c
sed -i 's/CYTOK_STRING,/STRING,/' src/backend/parser/cypher_parser.c
sed -i 's/CYTOK_CHAR,/CHAR,/' src/backend/parser/cypher_parser.c

# Restore graph_generation.c
sed -i '/extern Datum create_graph(PG_FUNCTION_ARGS);/d' src/backend/utils/graph_generation.c

# Restore cypher_gram.h
cat > src/include/parser/cypher_gram.h << 'ENDHDR'
#ifndef AG_CYPHER_GRAM_H
#define AG_CYPHER_GRAM_H
#include "nodes/pg_list.h"
#include "parser/ag_scanner.h"
#define YYLTYPE int
typedef struct cypher_yy_extra
{
    List *result;
    Node *extra;
} cypher_yy_extra;
#include "parser/cypher_gram_def.h"
int cypher_yylex(YYSTYPE *lvalp, YYLTYPE *llocp, ag_scanner_t scanner);
void cypher_yyerror(YYLTYPE *llocp, ag_scanner_t scanner,
                    cypher_yy_extra *extra, const char *msg);
#endif
ENDHDR

# Fix uint -> unsigned int
sed -i 's/    uint nlen = 0;/    unsigned int nlen = 0;/' src/backend/parser/cypher_gram.y

echo "=== Source reverted, building ==="
make clean 2>&1
make PG_CONFIG=/mingw64/bin/pg_config 2>&1
echo "=== BUILD EXIT: $? ==="
