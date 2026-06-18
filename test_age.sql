DROP EXTENSION IF EXISTS age CASCADE;
DROP SCHEMA IF EXISTS ag_catalog CASCADE;
CREATE EXTENSION age;
LOAD 'age';
SET search_path = ag_catalog, "$user", public;

SELECT create_graph('test_graph');

SELECT * FROM cypher('test_graph', $$
  CREATE (a:Person {name: 'Alice', age: 30})
  CREATE (b:Person {name: 'Bob', age: 25})
  RETURN a, b
$$) AS (a agtype, b agtype);

SELECT * FROM cypher('test_graph', $$
  MATCH (a:Person {name: 'Alice'}), (b:Person {name: 'Bob'})
  CREATE (a)-[:KNOWS {since: 2020}]->(b)
  RETURN a.name, b.name
$$) AS (a agtype, b agtype);

SELECT * FROM cypher('test_graph', $$
  MATCH (a:Person)-[r:KNOWS]->(b:Person)
  RETURN a.name AS from_person, b.name AS to_person, r.since AS since
$$) AS (from_person agtype, to_person agtype, since agtype);

SELECT * FROM cypher('test_graph', $$
  MATCH (p:Person)
  RETURN p.name AS name, p.age AS age
  ORDER BY p.name
$$) AS (name agtype, age agtype);
