LOAD 'age';
SET search_path = ag_catalog, "$user", public;

CREATE SCHEMA IF NOT EXISTS legal_graph;

-- ============================================
-- 1. 按文件夹查所有消息
-- 用法: SELECT * FROM legal_graph.messages_by_folder('财务');
-- ============================================
CREATE OR REPLACE FUNCTION legal_graph.messages_by_folder(p_folder_name TEXT)
RETURNS TABLE(message_subject text, folder_name text, sender_name text)
LANGUAGE plpgsql
SET search_path = ag_catalog, "$user", public AS $fn$
BEGIN
    RETURN QUERY EXECUTE format(
        'SELECT (subject::text), (folder::text), (sender::text) FROM cypher(''legal_knowledge'', $cy$ MATCH (msg:Message)-[:ABOUT]->(f:Folder {name: ''%s''}) MATCH (msg)-[:SENT_BY]->(sender:Person) RETURN msg.subject, f.name, sender.name $cy$) AS (subject agtype, folder agtype, sender agtype)',
        replace(p_folder_name, '''', '''''')
    );
END;
$fn$;

-- ============================================
-- 2. 按文件夹查消息（含子文件夹）
-- 用法: SELECT * FROM legal_graph.messages_by_folder_tree('财务');
-- ============================================
CREATE OR REPLACE FUNCTION legal_graph.messages_by_folder_tree(p_folder_name TEXT)
RETURNS TABLE(message_subject text, folder_name text, sender_name text)
LANGUAGE plpgsql
SET search_path = ag_catalog, "$user", public AS $fn$
BEGIN
    RETURN QUERY EXECUTE format(
        'SELECT (subject::text), (folder::text), (sender::text) FROM cypher(''legal_knowledge'', $cy$ MATCH (root:Folder {name: ''%s''})-[:PARENT_OF*0..3]->(f:Folder) MATCH (msg:Message)-[:ABOUT]->(f) OPTIONAL MATCH (msg)-[:SENT_BY]->(sender:Person) RETURN msg.subject, f.name, sender.name $cy$) AS (subject agtype, folder agtype, sender agtype)',
        replace(p_folder_name, '''', '''''')
    );
END;
$fn$;

-- ============================================
-- 3. 按发送者查所有消息
-- 用法: SELECT * FROM legal_graph.messages_by_sender('OdooBot');
-- ============================================
CREATE OR REPLACE FUNCTION legal_graph.messages_by_sender(p_person_name TEXT)
RETURNS TABLE(message_subject text, sender_name text)
LANGUAGE plpgsql
SET search_path = ag_catalog, "$user", public AS $fn$
BEGIN
    RETURN QUERY EXECUTE format(
        'SELECT (subject::text), (sender::text) FROM cypher(''legal_knowledge'', $cy$ MATCH (msg:Message)-[:SENT_BY]->(p:Person {name: ''%s''}) RETURN msg.subject, p.name $cy$) AS (subject agtype, sender agtype)',
        replace(p_person_name, '''', '''''')
    );
END;
$fn$;

-- ============================================
-- 4. 查文件夹下所有文档
-- 用法: SELECT * FROM legal_graph.documents_by_folder('管理员');
-- ============================================
CREATE OR REPLACE FUNCTION legal_graph.documents_by_folder(p_folder_name TEXT)
RETURNS TABLE(doc_name text, folder_name text)
LANGUAGE plpgsql
SET search_path = ag_catalog, "$user", public AS $fn$
BEGIN
    RETURN QUERY EXECUTE format(
        'SELECT (doc::text), (folder::text) FROM cypher(''legal_knowledge'', $cy$ MATCH (doc:Document)-[:IN_FOLDER]->(f:Folder {name: ''%s''}) RETURN doc.name, f.name $cy$) AS (doc agtype, folder agtype)',
        replace(p_folder_name, '''', '''''')
    );
END;
$fn$;

-- ============================================
-- 5. 查文件夹树
-- 用法: SELECT * FROM legal_graph.folder_tree('财务');
-- ============================================
CREATE OR REPLACE FUNCTION legal_graph.folder_tree(p_root_name TEXT)
RETURNS TABLE(folder_name text, parent_folder text, depth int)
LANGUAGE plpgsql
SET search_path = ag_catalog, "$user", public AS $fn$
BEGIN
    RETURN QUERY EXECUTE format(
        'SELECT (folder::text), (parent::text), (depth::int) FROM cypher(''legal_knowledge'', $cy$ MATCH path = (root:Folder {name: ''%s''})-[:PARENT_OF*0..5]->(f:Folder) OPTIONAL MATCH (f)<-[:PARENT_OF]-(parent:Folder) RETURN f.name, parent.name, length(path) $cy$) AS (folder agtype, parent agtype, depth agtype)',
        replace(p_root_name, '''', '''''')
    );
END;
$fn$;
