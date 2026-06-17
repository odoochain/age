\c age_test
LOAD 'age';
SET search_path = ag_catalog, "$user", public;

-- Test: relationship creation step by step
\echo '=== Create Alice ==='
SELECT * FROM cypher('test_graph', $$
  CREATE (a:Person {name: 'Diana', age: 28})
  RETURN a
$$) AS (a agtype);

\echo '=== Create edge using MATCH + CREATE ==='
SELECT * FROM cypher('test_graph', $$
  MATCH (a:Person {name: 'Alice'}), (b:Person {name: 'Bob'})
  CREATE (a)-[:FRIENDS_WITH {since: 2020}]->(b)
  RETURN a.name, b.name
$$) AS (a agtype, b agtype);

\echo '=== Verify edge exists ==='
SELECT * FROM cypher('test_graph', $$
  MATCH (a:Person)-[r:FRIENDS_WITH]->(b:Person)
  RETURN a.name AS from_person, b.name AS to_person, r.since AS since
$$) AS (from_person agtype, to_person agtype, since agtype);

\echo '=== Multi-hop with FRIENDS_WITH ==='
SELECT * FROM cypher('test_graph', $$
  MATCH (a:Person {name: 'Alice'})-[:FRIENDS_WITH]->(b:Person)-[:FRIENDS_WITH]->(c:Person)
  RETURN a.name, b.name, c.name
$$) AS (a agtype, b agtype, c agtype);

\echo '=== Variable length path ==='
SELECT * FROM cypher('test_graph', $$
  MATCH path = (a:Person {name: 'Alice'})-[:FRIENDS_WITH*1..3]->(other:Person)
  RETURN other.name AS reachable, length(path) AS hops
$$) AS (reachable agtype, hops agtype);

\echo '=== Create chain: Alice -> Bob -> Charlie ==='
SELECT * FROM cypher('test_graph', $$
  MATCH (b:Person {name: 'Bob'}), (c:Person {name: 'Charlie'})
  CREATE (b)-[:FRIENDS_WITH {since: 2021}]->(c)
  RETURN b.name, c.name
$$) AS (b agtype, c agtype);

\echo '=== Now multi-hop chain ==='
SELECT * FROM cypher('test_graph', $$
  MATCH path = (a:Person {name: 'Alice'})-[:FRIENDS_WITH*1..2]->(other:Person)
  RETURN other.name AS reachable, length(path) AS hops
$$) AS (reachable agtype, hops agtype);

\echo '=== All people in graph ==='
SELECT * FROM cypher('test_graph', $$
  MATCH (p:Person)
  RETURN p.name AS name, p.age AS age
  ORDER BY p.name
$$) AS (name agtype, age agtype);

\echo '=== Count all edges ==='
SELECT * FROM cypher('test_graph', $$
  MATCH ()-[r]->()
  RETURN type(r) AS edge_type, count(r) AS cnt
$$) AS (edge_type agtype, cnt agtype);
