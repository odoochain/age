SELECT res_id, 
       (SELECT type FROM documents_document WHERE id = m.res_id) AS doc_type,
       count(*) 
FROM mail_message m 
WHERE model = 'documents.document' AND res_id IS NOT NULL 
GROUP BY res_id 
ORDER BY res_id;
