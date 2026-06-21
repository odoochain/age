#!/usr/bin/env python3
"""按模块生成 Mermaid ER 子图"""
import sys
import io
from collections import defaultdict

OUT = open('D:/dev/lawgraph/age-source/baraka_er.md', 'w', encoding='utf-8')
def print(*args, **kwargs):
    OUT.write(' '.join(str(a) for a in args) + kwargs.get('end', '\n'))

fks = []
with open('D:/dev/lawgraph/age-source/fks.txt', 'r', encoding='utf-8') as f:
    for line in f:
        line = line.strip()
        if not line or '|' not in line:
            continue
        parts = line.split('|')
        if len(parts) >= 4:
            fks.append((parts[0], parts[1], parts[2], parts[3]))

# 按表名前缀分组
def get_prefix(table):
    if '_' in table:
        return table.split('_')[0]
    return table

# 模块 -> 外键
module_fks = defaultdict(list)
for child, child_col, parent, parent_col in fks:
    prefix = get_prefix(child)
    module_fks[prefix].append((child, child_col, parent, parent_col))

# 核心模块（限制大小）
core_modules = ['res', 'mail', 'ir', 'account', 'product', 'documents', 'payment', 'ai', 'lawpad', 'knowledge', 'discuss', 'spreadsheet']

module_names = {
    'res': '基础资源 (res_)',
    'mail': '消息邮件 (mail_)',
    'ir': '内部资源 (ir_)',
    'account': '会计 (account_)',
    'product': '产品 (product_)',
    'documents': '文档管理 (documents_)',
    'payment': '支付 (payment_)',
    'ai': 'AI (ai_)',
    'lawpad': '法律 (lawpad_)',
    'knowledge': '知识库 (knowledge_)',
    'discuss': '讨论 (discuss_)',
    'spreadsheet': '电子表格 (spreadsheet_)',
}

print("# Baraka 数据库 ER 图（按模块）")
print()
print(f"总表数: 530 | 总外键: {len(fks)}")
print()

for mod in core_modules:
    if mod not in module_fks:
        continue
    mod_fks = module_fks[mod]
    tables = set()
    for child, _, parent, _ in mod_fks:
        tables.add(child)
        tables.add(parent)
    
    # 限制每模块最多 40 个表
    if len(tables) > 40:
        # 只保留该模块自己的表
        tables = {t for t in tables if get_prefix(t) == mod}
        mod_fks = [(c, cc, p, pc) for c, cc, p, pc in mod_fks if c in tables]
    
    if not tables:
        continue
    
    print(f"## {module_names.get(mod, mod)}")
    print(f"({len(tables)} 表, {len(mod_fks)} 外键)")
    print()
    print("```mermaid")
    print("erDiagram")
    
    for t in sorted(tables):
        print(f"  {t} {{")
        print(f"    int id PK")
        print(f"  }}")
    
    seen = set()
    for child, child_col, parent, parent_col in mod_fks:
        if child not in tables or parent not in tables:
            continue
        key = (child, parent)
        if key in seen:
            continue
        seen.add(key)
        print(f"  {child} }}o--|| {parent} : \"{child_col}\"")
    
    print("```")
    print()

# 其他模块汇总
print("## 其他模块")
print()
other_modules = set(module_fks.keys()) - set(core_modules)
for mod in sorted(other_modules):
    mod_fks = module_fks[mod]
    tables = set()
    for child, _, parent, _ in mod_fks:
        tables.add(child)
        tables.add(parent)
    if len(tables) <= 3:
        continue
    print(f"### {mod}_ ({len(tables)} 表)")
    print()
    print("```mermaid")
    print("erDiagram")
    for t in sorted(tables)[:20]:
        print(f"  {t} {{")
        print(f"    int id PK")
        print(f"  }}")
    seen = set()
    table_list = sorted(tables)[:20]
    for child, child_col, parent, parent_col in mod_fks:
        if child not in table_list and parent not in table_list:
            continue
        key = (child, parent)
        if key in seen:
            continue
        seen.add(key)
        print(f"  {child} }}o--|| {parent} : \"{child_col}\"")
    print("```")
    print()

OUT.close()
