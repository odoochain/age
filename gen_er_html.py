#!/usr/bin/env python3
"""生成 ER 图 HTML 页面，可在浏览器中打开"""
import re

with open('D:/dev/lawgraph/age-source/baraka_er.md', 'r', encoding='utf-8') as f:
    md = f.read()

# 提取每个模块的 mermaid 代码块
sections = re.findall(r'##+ (.+?)\n.*?```mermaid\n(.*?)```', md, re.DOTALL)

html = '''<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="UTF-8">
<title>Baraka 数据库 ER 图</title>
<script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
<style>
body { font-family: -apple-system, "Microsoft YaHei", sans-serif; max-width: 1400px; margin: 0 auto; padding: 20px; background: #f8f9fa; }
h1 { color: #333; border-bottom: 2px solid #007bff; padding-bottom: 10px; }
h2 { color: #007bff; margin-top: 40px; cursor: pointer; user-select: none; }
h2:hover { text-decoration: underline; }
h2::before { content: "▼ "; font-size: 0.8em; }
.collapsed h2::before { content: "▶ "; }
.mermaid { background: white; padding: 15px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin: 10px 0 30px; overflow-x: auto; }
.summary { background: #e3f2fd; padding: 15px; border-radius: 8px; margin-bottom: 20px; font-size: 1.1em; }
.section { margin-bottom: 10px; }
.section.collapsed .mermaid-container { display: none; }
</style>
</head>
<body>
<h1>Baraka 数据库 ER 图</h1>
<div class="summary">📊 总表数: 530 | 总外键: 1758 | 按模块分组 | 点击标题折叠/展开</div>
'''

for i, (title, diagram) in enumerate(sections):
    title = title.strip()
    html += f'<div class="section" id="sec{i}">\n'
    html += f'<h2 onclick="toggle({i})">{title}</h2>\n'
    html += f'<div class="mermaid-container"><div class="mermaid">\n{diagram.strip()}\n</div></div>\n'
    html += '</div>\n'

html += '''
<script>
mermaid.initialize({ startOnLoad: true, theme: 'default', securityLevel: 'loose', flowchart: { useMaxWidth: true } });

function toggle(id) {
    const sec = document.getElementById('sec' + id);
    sec.classList.toggle('collapsed');
}
</script>
</body>
</html>
'''

with open('D:/dev/lawgraph/age-source/baraka_er.html', 'w', encoding='utf-8') as f:
    f.write(html)

print(f"HTML generated: {len(sections)} sections")
