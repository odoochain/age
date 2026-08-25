SELECT '=== Messages with subject ===' AS info;
SELECT count(*) FROM mail_message WHERE subject IS NOT NULL;

SELECT '=== Messages about docs ===' AS info;
SELECT count(*) FROM mail_message WHERE model = 'documents.document' AND res_id IS NOT NULL;

SELECT '=== Overlap ===' AS info;
SELECT count(*) FROM mail_message WHERE subject IS NOT NULL AND model = 'documents.document' AND res_id IS NOT NULL;

SELECT '=== All messages count ===' AS info;
SELECT count(*) FROM mail_message;
