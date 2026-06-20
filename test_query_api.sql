-- 1. 按文件夹查消息
SELECT '=== messages_by_folder(财务) ===' AS info;
SELECT * FROM legal_graph.messages_by_folder('财务') LIMIT 5;

-- 2. 按文件夹树查消息（含子文件夹）
SELECT '=== messages_by_folder_tree(财务) ===' AS info;
SELECT * FROM legal_graph.messages_by_folder_tree('财务') LIMIT 10;

-- 3. 按发送者查消息
SELECT '=== messages_by_sender(OdooBot) ===' AS info;
SELECT * FROM legal_graph.messages_by_sender('OdooBot') LIMIT 5;

-- 4. 查文件夹下文档
SELECT '=== documents_by_folder(管理员) ===' AS info;
SELECT * FROM legal_graph.documents_by_folder('管理员');

-- 5. 查文件夹树
SELECT '=== folder_tree(财务) ===' AS info;
SELECT * FROM legal_graph.folder_tree('财务');
