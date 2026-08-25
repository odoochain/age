SELECT '=== 6月1日-6月30日消息 ===' AS info;
SELECT * FROM legal_graph.messages_by_date_range('2026-06-01', '2026-06-30') LIMIT 10;

SELECT '=== 5月27日消息 ===' AS info;
SELECT count(*) AS total FROM legal_graph.messages_by_date_range('2026-05-27', '2026-05-28');

SELECT '=== 6月16日消息 ===' AS info;
SELECT count(*) AS total FROM legal_graph.messages_by_date_range('2026-06-16', '2026-06-17');
