-- Connect to age_test db
\c age_test
LOAD 'age';
SET search_path = ag_catalog, "$user", public;

-- ============================================
-- Test 1: Create nodes and edges
-- ============================================
\echo '=== Test 1: Create nodes with relationships ==='

SELECT * FROM cypher('test_graph', $$
  CREATE (bob:Person {name: 'Bob', age: 25})
  CREATE (charlie:Person {name: 'Charlie', age: 35})
  CREATE (alice)-[:KNOWS {since: 2020}]->(bob)
  CREATE (bob)-[:KNOWS {since: 2021}]->(charlie)
  CREATE (alice)-[:KNOWS {since: 2019}]->(charlie)
  RETURN bob, charlie
$$) AS (bob agtype, charlie agtype);

-- ============================================
-- Test 2: Pattern matching
-- ============================================
\echo '=== Test 2: Match patterns ==='

-- Find all people Alice knows
SELECT * FROM cypher('test_graph', $$
  MATCH (a:Person {name: 'Alice'})-[r:KNOWS]->(b:Person)
  RETURN b.name AS friend, r.since AS since
$$) AS (friend agtype, since agtype);

-- ============================================
-- Test 3: Multi-hop traversal
-- ============================================
\echo '=== Test 3: Multi-hop traversal ==='

-- Find friends of friends
SELECT * FROM cypher('test_graph', $$
  MATCH (a:Person {name: 'Alice'})-[:KNOWS]->()-[:KNOWS]->(fof:Person)
  RETURN fof.name AS friend_of_friend
$$) AS (friend_of_friend agtype);

-- ============================================
-- Test 4: WHERE clause
-- ============================================
\echo '=== Test 4: WHERE clause ==='

SELECT * FROM cypher('test_graph', $$
  MATCH (p:Person)
  WHERE p.age > 28
  RETURN p.name AS name, p.age AS age
  ORDER BY p.age
$$) AS (name agtype, age agtype);

-- ============================================
-- Test 5: CREATE more complex graph
-- ============================================
\echo '=== Test 5: Company graph ==='

SELECT create_graph('company');

SELECT * FROM cypher('company', $$
  CREATE (c:Company {name: 'TechCorp'})
  CREATE (e1:Employee {name: 'Dave', salary: 80000})
  CREATE (e2:Employee {name: 'Eve', salary: 95000})
  CREATE (e3:Employee {name: 'Frank', salary: 72000})
  CREATE (d1:Department {name: 'Engineering'})
  CREATE (d2:Department {name: 'Marketing'})
  CREATE (e1)-[:WORKS_IN]->(d1)
  CREATE (e2)-[:WORKS_IN]->(d1)
  CREATE (e3)-[:WORKS_IN]->(d2)
  CREATE (d1)-[:BELONGS_TO]->(c)
  CREATE (d2)-[:BELONGS_TO]->(c)
  CREATE (e2)-[:MANAGES]->(d1)
  RETURN c, e1, e2, e3, d1, d2
$$) AS (c agtype, e1 agtype, e2 agtype, e3 agtype, d1 agtype, d2 agtype);

-- ============================================
-- Test 6: Aggregation
-- ============================================
\echo '=== Test 6: Aggregation ==='

-- Count employees per department
SELECT * FROM cypher('company', $$
  MATCH (e:Employee)-[:WORKS_IN]->(d:Department)
  RETURN d.name AS dept, count(e) AS headcount, avg(e.salary) AS avg_salary
$$) AS (dept agtype, headcount agtype, avg_salary agtype);

-- ============================================
-- Test 7: OPTIONAL MATCH (left join equivalent)
-- ============================================
\echo '=== Test 7: OPTIONAL MATCH ==='

SELECT * FROM cypher('company', $$
  MATCH (e:Employee)
  OPTIONAL MATCH (e)-[:MANAGES]->(d:Department)
  RETURN e.name AS employee, d.name AS manages_dept
$$) AS (employee agtype, manages_dept agtype);

-- ============================================
-- Test 8: WITH clause (pipeline)
-- ============================================
\echo '=== Test 8: WITH clause ==='

SELECT * FROM cypher('company', $$
  MATCH (e:Employee)-[:WORKS_IN]->(d:Department)
  WITH d, collect(e.name) AS employees, count(e) AS cnt
  WHERE cnt > 1
  RETURN d.name AS dept, employees, cnt
$$) AS (dept agtype, employees agtype, cnt agtype);

-- ============================================
-- Test 9: Variable length path
-- ============================================
\echo '=== Test 9: Variable length paths ==='

SELECT * FROM cypher('test_graph', $$
  MATCH path = (a:Person {name: 'Alice'})-[:KNOWS*1..2]->(other:Person)
  RETURN other.name AS reachable, length(path) AS hops
$$) AS (reachable agtype, hops agtype);

-- ============================================
-- Test 10: MERGE (upsert)
-- ============================================
\echo '=== Test 10: MERGE ==='

SELECT * FROM cypher('test_graph', $$
  MERGE (p:Person {name: 'Alice'})
  ON MATCH SET p.last_seen = timestamp()
  ON CREATE SET p.created = timestamp()
  RETURN p.name, p.age
$$) AS (name agtype, age agtype);

-- ============================================
-- Test 11: UNWIND
-- ============================================
\echo '=== Test 11: UNWIND ==='

SELECT * FROM cypher('test_graph', $$
  UNWIND [1, 2, 3, 4, 5] AS num
  RETURN num * 2 AS doubled
$$) AS (doubled agtype);

-- ============================================
-- Test 12: List comprehension
-- ============================================
\echo '=== Test 12: List comprehension ==='

SELECT * FROM cypher('test_graph', $$
  WITH [1, 2, 3, 4, 5] AS numbers
  RETURN [x IN numbers WHERE x > 2 | x * 10] AS filtered
$$) AS (filtered agtype);

-- ============================================
-- Test 13: Delete operations
-- ============================================
\echo '=== Test 13: DELETE ==='

-- Create then delete
SELECT * FROM cypher('test_graph', $$
  CREATE (tmp:Temp {value: 'delete_me'})
  RETURN tmp.value AS before_delete
$$) AS (before_delete agtype);

SELECT * FROM cypher('test_graph', $$
  MATCH (t:Temp {value: 'delete_me'})
  DETACH DELETE t
  RETURN count(*) AS deleted
$$) AS (deleted agtype);

-- ============================================
-- Test 14: Map projection
-- ============================================
\echo '=== Test 14: Map projection ==='

SELECT * FROM cypher('test_graph', $$
  MATCH (p:Person {name: 'Alice'})
  RETURN p {.*, .name} AS person_info
$$) AS (person_info agtype);

-- ============================================
-- Test 15: CASE WHEN
-- ============================================
\echo '=== Test 15: CASE WHEN ==='

SELECT * FROM cypher('test_graph', $$
  MATCH (p:Person)
  RETURN p.name,
    CASE
      WHEN p.age < 30 THEN 'young'
      WHEN p.age < 40 THEN 'middle'
      ELSE 'senior'
    END AS age_group
$$) AS (name agtype, age_group agtype);

\echo '=== All tests complete! ==='
