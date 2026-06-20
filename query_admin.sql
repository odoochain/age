LOAD 'age';
SET search_path = ag_catalog, "$user", public;

-- 查询"管理员"文件夹中的所有文档
SELECT '=== Documents in 管理员 folder ===' AS info;
SELECT * FROM cypher('legal_knowledge', $$ 
    MATCH (d:Document)-[:IN_FOLDER]->(f:Folder {name: '管理员'})
    RETURN d.name AS doc_name, d.odoo_id AS doc_id
$$) AS (doc_name agtype, doc_id agtype);

-- 查询"管理员"文件夹及其子文件夹
SELECT '=== Admin folder tree ===' AS info;
SELECT * FROM cypher('legal_knowledge', $$ 
    MATCH (child:Folder)-[:IN_FOLDER*0..2]->(f:Folder {name: '管理员'})
    RETURN child.name, child.odoo_id
$$) AS (name agtype, oid agtype);

-- 查询与"管理员"文件夹中文档相关的消息
SELECT '=== Messages about documents in Admin ===' AS info;
SELECT * FROM cypher('legal_knowledge', $$ 
    MATCH (d:Document)-[:IN_FOLDER]->(f:Folder {name: '管理员'})
    MATCH (m:Message)-[:ABOUT]->(d)
    RETURN m.subject, d.name
$$) AS (subject agtype, doc_name agtype);

-- 综合查询：管理员文件夹 + 文档 + 标签 + 消息
SELECT '=== Full path from Admin folder ===' AS info;
SELECT * FROM cypher('legal_knowledge', $$ 
    MATCH (d:Document)-[:IN_FOLDER]->(f:Folder {name: '管理员'})
    OPTIONAL MATCH (d)-[:HAS_TAG]->(t:Tag)
    OPTIONAL MATCH (m:Message)-[:ABOUT]->(d)
    OPTIONAL MATCH (m)-[:SENT_BY]->(p:Person)
    RETURN f.name AS folder, d.name AS document, 
           t.name AS tag, m.subject AS message, 
           p.name AS sender
$$) AS (folder agtype, document agtype, tag agtype, message agtype, sender agtype);

-- 补充：从 Odoo 原始表直接查管理员文件夹下的文档
SELECT '=== Raw Odoo query ===' AS info;
SELECT d.id, COALESCE(d.name->>'zh_CN', d.name->>'en_US') AS doc_name, d.type
FROM documents_document d
JOIN documents_document f ON d.folder_id = f.id
WHERE COALESCE(f.name->>'zh_CN', f.name->>'en_US') = '管理员' 
  AND d.type != 'folder';
