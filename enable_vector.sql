SELECT name, default_version FROM pg_available_extensions WHERE name = 'vector';
CREATE EXTENSION IF NOT EXISTS vector;
SELECT extname, extversion FROM pg_extension WHERE extname IN ('age', 'vector');
-- 快速功能测试
CREATE TABLE IF NOT EXISTS vec_test (id serial PRIMARY KEY, embedding vector(3));
INSERT INTO vec_test (embedding) VALUES ('[1,2,3]'), ('[4,5,6]');
SELECT id, embedding, embedding <-> '[3,1,2]' AS distance FROM vec_test ORDER BY distance;
DROP TABLE vec_test;
