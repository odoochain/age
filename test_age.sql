-- Use fresh database
\echo Using fresh db
DROP DATABASE IF EXISTS age_test;
CREATE DATABASE age_test;
\c age_test

\echo Loading AGE
CREATE EXTENSION age;

\echo Show schema
SELECT count(*) FROM information_schema.schemata WHERE schema_name = 'ag_catalog';
SELECT count(*) FROM pg_opclass WHERE opcname = 'graphid_ops';

\echo Load AGE search path
LOAD 'age';
SET search_path = ag_catalog, "$user", public;

\echo Create graph
SELECT create_graph('test_graph');

\echo Create node
SELECT * FROM cypher('test_graph', $$ CREATE (n:Person {name: 'Alice', age: 30}) RETURN n $$) AS (result agtype);

\echo Query node
SELECT * FROM cypher('test_graph', $$ MATCH (n:Person) RETURN n.name, n.age $$) AS (name agtype, age agtype);
