-- 预热 AGE
LOAD 'age';
SET search_path = ag_catalog, "$user", public;
SELECT * FROM cypher('legal_knowledge', $$ MATCH (n) RETURN count(n) $$) AS (cnt agtype);

-- 再测试
SELECT * FROM legal_graph.messages_by_date_range('2026-06-01','2026-06-30') LIMIT 5;
