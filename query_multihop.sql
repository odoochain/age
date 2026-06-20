LOAD 'age';
SET search_path = ag_catalog, "$user", public;

-- 多跳查询：消息 -> 文件夹 -> 子文件夹
SELECT '=== Msg -> Folder -> SubFolder (2-hop) ===' AS info;
SELECT * FROM cypher('legal_knowledge', $$ 
    MATCH (m:Message)-[:ABOUT]->(f:Folder)-[:PARENT_OF]->(child:Folder)
    RETURN m.subject AS msg, f.name AS folder, child.name AS subfolder
    LIMIT 5
$$) AS (msg agtype, folder agtype, subfolder agtype);

-- 多跳查询：消息 -> 发送者
SELECT '=== Msg -> Sender ===' AS info;
SELECT * FROM cypher('legal_knowledge', $$ 
    MATCH (m:Message)-[:SENT_BY]->(p:Person)
    RETURN m.subject AS msg, p.name AS sender
    LIMIT 5
$$) AS (msg agtype, sender agtype);

-- 文件夹层级树
SELECT '=== Folder tree (root -> children) ===' AS info;
SELECT * FROM cypher('legal_knowledge', $$ 
    MATCH (parent:Folder)-[:PARENT_OF]->(child:Folder)
    RETURN parent.name AS parent, child.name AS child
    ORDER BY parent.name
$$) AS (parent agtype, child agtype);
