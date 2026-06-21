LOAD 'age';
SET search_path = ag_catalog, "$user", public;

-- 给现有 Message 节点补 date 属性
DO $fn$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT id, date::text FROM mail_message WHERE date IS NOT NULL
    LOOP
        EXECUTE format(
            'SELECT * FROM cypher(''legal_knowledge'', $cy$ MATCH (m:Message {odoo_id: %s}) SET m.msg_date = "%s" RETURN m $cy$) AS (m agtype)',
            r.id, r.date
        );
    END LOOP;
END;
$fn$;

-- 验证
SELECT * FROM cypher('legal_knowledge', $$
    MATCH (m:Message) WHERE m.msg_date IS NOT NULL RETURN m.subject, m.msg_date LIMIT 3
$$) AS (subject agtype, msg_date agtype);
