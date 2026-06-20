LOAD 'age';
SET search_path = ag_catalog, "$user", public;

SELECT create_graph('test_graph');

SELECT * FROM cypher('test_graph', $$CREATE (n:Person {name: "Alice", age: 30}) RETURN n$$) AS (v agtype);
SELECT * FROM cypher('test_graph', $$CREATE (m:Person {name: "Bob", age: 25}) RETURN m$$) AS (v agtype);
SELECT * FROM cypher('test_graph', $$MATCH (a:Person), (b:Person) WHERE a.name = "Alice" AND b.name = "Bob" CREATE (a)-[:KNOWS]->(b) RETURN a, b$$) AS (a agtype, b agtype);
SELECT * FROM cypher('test_graph', $$MATCH (a:Person)-[r:KNOWS]->(b:Person) RETURN a.name, b.name$$) AS (from_name agtype, to_name agtype);
