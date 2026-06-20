CREATE EXTENSION IF NOT EXISTS age;
LOAD 'age';
SET search_path = ag_catalog, "$user", public;
SELECT extname, extversion FROM pg_extension WHERE extname = 'age';
SELECT * FROM ag_catalog.ag_graph;
