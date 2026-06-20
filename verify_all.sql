LOAD 'age';
SET search_path = ag_catalog, "$user", public;

SELECT '=== Nodes ===' AS info;
SELECT * FROM cypher('legal_knowledge', $$ 
    MATCH (n) RETURN labels(n)[0] AS label, count(*) AS cnt ORDER BY cnt DESC
$$) AS (label agtype, cnt agtype);

SELECT '=== Relations ===' AS info;
SELECT * FROM cypher('legal_knowledge', $$ 
    MATCH ()-[r]->() RETURN type(r) AS rel, count(*) AS cnt ORDER BY cnt DESC
$$) AS (rel agtype, cnt agtype);

SELECT '=== Path: Document -> Folder ===' AS info;
SELECT * FROM cypher('legal_knowledge', $$ 
    MATCH p = (d:Document)-[:IN_FOLDER]->(f:Folder) RETURN d.name, f.name
$$) AS (doc agtype, folder agtype);
