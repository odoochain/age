LOAD 'age';
SET search_path = ag_catalog, "$user", public;

-- 检查 Message 节点属性
SELECT * FROM cypher('legal_knowledge', $$
    MATCH (m:Message) RETURN keys(m), m LIMIT 3
$$) AS (keys agtype, m agtype);

-- 检查 mail_message 表的 date 列
SELECT '=== mail_message date range ===' AS info;
SELECT min(date), max(date), count(*) FROM mail_message WHERE date IS NOT NULL;
