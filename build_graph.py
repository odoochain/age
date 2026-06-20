#!/usr/bin/env python3
"""从 Odoo 数据构建 Apache AGE 法律知识图谱 — 生成 SQL 文件执行"""
import subprocess
import sys
import io
import tempfile
import os

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

PSQL = 'C:/Users/mirroam/scoop/apps/msys2/current/mingw64/bin/psql.exe'

def rows_from_psql(sql):
    """执行 psql 并解析行"""
    result = subprocess.run(
        [PSQL, '-p', '5433', '-d', 'baraka', '-t', '-A', '-q', '-c', sql],
        capture_output=True
    )
    raw = result.stdout.decode('utf-8', errors='replace').replace('\r', '')
    return [line.strip() for line in raw.split('\n') if line.strip()]

def esc(s):
    s = str(s)
    s = s.replace('\\', '\\\\')
    s = s.replace("'", "\\'")
    return s

def build_sql(graph, lines, include_header=True):
    """生成 SQL 文件并执行"""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.sql', delete=False, encoding='utf-8') as f:
        if include_header:
            f.write("LOAD 'age';\nSET search_path = ag_catalog, \"$user\", public;\n")
        for line in lines:
            f.write(line + "\n")
        sql_path = f.name
    
    result = subprocess.run([PSQL, '-p', '5433', '-d', 'baraka', '-f', sql_path], capture_output=True)
    if result.returncode != 0:
        print(f"  ERR: {result.stderr.decode('utf-8', errors='replace')[:300]}", file=sys.stderr)
    os.unlink(sql_path)

def main():
    G = 'legal_knowledge'
    
    nodes = []
    rels = []
    
    # 清理
    nodes.append(f"SELECT * FROM cypher('{G}', $$ MATCH (n) DETACH DELETE n $$) AS (r agtype);")
    
    # 客户
    print("Client nodes...")
    for line in rows_from_psql("SELECT id, name FROM res_partner WHERE is_company = true AND name IS NOT NULL"):
        parts = line.split('|')
        if len(parts) >= 2:
            nodes.append(f"SELECT * FROM cypher('{G}', $$ CREATE (c:Client {{odoo_id: {parts[0]}, name: '{esc(parts[1])}'}}) $$) AS (r agtype);")
            print(f"  Client: {parts[1]}")
    
    # 个人
    print("Person nodes...")
    for line in rows_from_psql("SELECT id, name FROM res_partner WHERE is_company = false AND name IS NOT NULL"):
        parts = line.split('|')
        if len(parts) >= 2:
            nodes.append(f"SELECT * FROM cypher('{G}', $$ CREATE (p:Person {{odoo_id: {parts[0]}, name: '{esc(parts[1])}'}}) $$) AS (r agtype);")
            print(f"  Person: {parts[1]}")
    
    # 文件夹
    print("Folder nodes...")
    for line in rows_from_psql("SELECT id, COALESCE(name->>'zh_CN', name->>'en_US', 'Unknown') FROM documents_document WHERE type = 'folder' AND name IS NOT NULL"):
        parts = line.split('|')
        if len(parts) >= 2:
            nodes.append(f"SELECT * FROM cypher('{G}', $$ CREATE (f:Folder {{odoo_id: {parts[0]}, name: '{esc(parts[1])}'}}) $$) AS (r agtype);")
            print(f"  Folder: {parts[1]}")
    
    # 文档
    print("Document nodes...")
    for line in rows_from_psql("SELECT id, COALESCE(name->>'zh_CN', name->>'en_US', 'Unknown') FROM documents_document WHERE type != 'folder' AND name IS NOT NULL"):
        parts = line.split('|')
        if len(parts) >= 2:
            nodes.append(f"SELECT * FROM cypher('{G}', $$ CREATE (d:Document {{odoo_id: {parts[0]}, name: '{esc(parts[1])}'}}) $$) AS (r agtype);")
            print(f"  Document: {parts[1]}")
    
    # 标签
    print("Tag nodes...")
    for line in rows_from_psql("SELECT id, COALESCE(name->>'zh_CN', name->>'en_US', 'Unknown') FROM documents_tag WHERE name IS NOT NULL"):
        parts = line.split('|')
        if len(parts) >= 2:
            nodes.append(f"SELECT * FROM cypher('{G}', $$ CREATE (t:Tag {{odoo_id: {parts[0]}, name: '{esc(parts[1])}'}}) $$) AS (r agtype);")
            print(f"  Tag: {parts[1]}")
    
    # 消息
    print("Message nodes...")
    for line in rows_from_psql("SELECT id, subject FROM mail_message WHERE subject IS NOT NULL"):
        parts = line.split('|')
        if len(parts) >= 2:
            nodes.append(f"SELECT * FROM cypher('{G}', $$ CREATE (m:Message {{odoo_id: {parts[0]}, subject: '{esc(parts[1])}'}}) $$) AS (r agtype);")
    
    # 关系: 文档-文件夹
    print("Doc-Folder relations...")
    cnt = 0
    for line in rows_from_psql("SELECT id, folder_id FROM documents_document WHERE type != 'folder' AND folder_id IS NOT NULL"):
        parts = line.split('|')
        if len(parts) >= 2:
            rels.append(f"SELECT * FROM cypher('{G}', $$ MATCH (d:Document {{odoo_id: {parts[0]}}}), (f:Folder {{odoo_id: {parts[1]}}}) CREATE (d)-[:IN_FOLDER]->(f) $$) AS (r agtype);")
            cnt += 1
    print(f"  {cnt} IN_FOLDER edges")
    
    # 关系: 文档-标签
    print("Doc-Tag relations...")
    cnt = 0
    for line in rows_from_psql("SELECT documents_document_id, documents_tag_id FROM document_tag_rel"):
        parts = line.split('|')
        if len(parts) >= 2:
            rels.append(f"SELECT * FROM cypher('{G}', $$ MATCH (d:Document {{odoo_id: {parts[0]}}}), (t:Tag {{odoo_id: {parts[1]}}}) CREATE (d)-[:HAS_TAG]->(t) $$) AS (r agtype);")
            cnt += 1
    print(f"  {cnt} HAS_TAG edges")
    
    # 关系: 消息-发送者
    print("Msg-Sender relations...")
    cnt = 0
    for line in rows_from_psql("SELECT id, author_id FROM mail_message WHERE author_id IS NOT NULL AND subject IS NOT NULL"):
        parts = line.split('|')
        if len(parts) >= 2:
            rels.append(f"SELECT * FROM cypher('{G}', $$ MATCH (m:Message {{odoo_id: {parts[0]}}}), (p:Person {{odoo_id: {parts[1]}}}) CREATE (m)-[:SENT_BY]->(p) $$) AS (r agtype);")
            cnt += 1
    print(f"  {cnt} SENT_BY edges")
    
    # 执行
    print(f"\nExecuting {len(nodes)} nodes + {len(rels)} relations...")
    build_sql(G, nodes + rels)
    
    # 验证
    print("\n=== Verification ===")
    lines = [
        f"SELECT * FROM cypher('{G}', $$ MATCH (n) RETURN labels(n)[0] AS label, count(*) AS cnt ORDER BY cnt DESC $$) AS (label agtype, cnt agtype);",
        f"SELECT * FROM cypher('{G}', $$ MATCH ()-[r]->() RETURN type(r) AS rel, count(*) AS cnt ORDER BY cnt DESC $$) AS (rel agtype, cnt agtype);",
    ]
    build_sql(G, lines, include_header=True)

if __name__ == '__main__':
    main()
