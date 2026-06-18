SELECT am.amname, opc.opcname, opc.opcmethod
FROM pg_opclass opc
JOIN pg_am am ON opc.opcmethod = am.oid
WHERE opc.opcnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'ag_catalog')
ORDER BY am.amname, opc.opcname;
