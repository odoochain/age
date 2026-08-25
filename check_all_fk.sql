-- 文档 partner_id 关系
SELECT '=== docs with partner_id ===' AS info;
SELECT id, partner_id FROM documents_document WHERE partner_id IS NOT NULL;

-- 文档 owner_id 关系
SELECT '=== docs with owner_id ===' AS info;
SELECT id, owner_id FROM documents_document WHERE type != 'folder' AND owner_id IS NOT NULL;

-- 消息关联文档
SELECT '=== messages about documents ===' AS info;
SELECT id, model, res_id FROM mail_message WHERE model = 'documents.document' AND res_id IS NOT NULL;

-- 消息关联合作伙伴
SELECT '=== messages about partners ===' AS info;
SELECT id, model, res_id FROM mail_message WHERE model = 'res.partner' AND res_id IS NOT NULL;

-- 文档-标签关系
SELECT '=== document-tag rels ===' AS info;
SELECT count(*) FROM document_tag_rel;

-- 文档-附件关系
SELECT '=== docs with attachment ===' AS info;
SELECT id, attachment_id FROM documents_document WHERE attachment_id IS NOT NULL;
