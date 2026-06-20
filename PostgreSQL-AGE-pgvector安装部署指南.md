# PostgreSQL 18.4 + Apache AGE + pgvector 安装部署指南

> **文档版本**: 1.0  
> **更新日期**: 2026-06-19  
> **适用平台**: Windows 10/11 + MSYS2/MinGW64  
> **PostgreSQL 版本**: 18.4 (gcc-16.1.0, MSYS2 编译)  
> **Apache AGE 版本**: 1.7.0  
> **pgvector 版本**: 0.8.2

---

## 目录

1. [架构概述](#1-架构概述)
2. [环境准备](#2-环境准备)
3. [PostgreSQL 18.4 编译安装](#3-postgresql-184-编译安装)
4. [Apache AGE 1.7.0 编译安装](#4-apache-age-170-编译安装)
5. [pgvector 0.8.2 编译安装](#5-pgvector-082-编译安装)
6. [服务管理脚本](#6-服务管理脚本)
7. [数据库初始化与用户配置](#7-数据库初始化与用户配置)
8. [扩展启用与验证](#8-扩展启用与验证)
9. [故障排查](#9-故障排查)
10. [快速参考卡片](#10-快速参考卡片)

---

## 1. 架构概述

### 1.1 技术栈

```
┌─────────────────────────────────────────────────┐
│                  应用层                          │
│         Odoo / 法律可视化 / 图谱应用              │
├─────────────────────────────────────────────────┤
│                  扩展层                          │
│   Apache AGE 1.7.0    │    pgvector 0.8.2       │
│   (Cypher 图查询)      │    (向量相似度搜索)      │
├─────────────────────────────────────────────────┤
│              PostgreSQL 18.4                     │
│           (MSYS2/MinGW64 编译)                   │
├─────────────────────────────────────────────────┤
│           Windows 10/11 + MSYS2                  │
└─────────────────────────────────────────────────┘
```

### 1.2 关键设计决策

| 决策点 | 选择 | 原因 |
|--------|------|------|
| PostgreSQL 来源 | MSYS2/MinGW64 编译 | Apache AGE 需要 C 扩展，必须与 PG 编译器一致 |
| 数据目录 | `D:/mydata/pgdata` | 持久化存储，不随系统清理丢失 |
| 端口 | 5433 | 避免与 scoop 安装的原生 PG (5432) 冲突 |
| 管理脚本 | `.bat` + bash | Windows 环境下方便调用 msys2 bash |
| Bash 环境 | MSYS2 bash | `/mingw64/bin` 下有编译好的 PG 工具链 |

### 1.3 为什么不用 scoop 的 PostgreSQL？

scoop 安装的 PostgreSQL 是 **MSVC 编译的原生 Windows 版本**，而 Apache AGE 使用 **GCC/MinGW64 编译**。两者 ABI 不兼容，C 扩展无法跨编译器加载。因此必须使用 MSYS2/MinGW64 编译的 PostgreSQL。

---

## 2. 环境准备

### 2.1 必要软件

| 软件 | 用途 | 安装方式 |
|------|------|---------|
| MSYS2 | 提供 MinGW64 编译工具链 | `scoop install msys2` |
| PostgreSQL 18 源码 | 编译 PG 服务器 | MSYS2 pacman 或手动编译 |
| Apache AGE 源码 | 图数据库扩展 | `d:\dev\lawgraph\age-source` |
| pgvector 源码 | 向量搜索扩展 | `d:\dev\lawgraph\pgvector` |

### 2.2 MSYS2 路径

```
MSYS2 安装目录: C:\Users\mirroam\scoop\apps\msys2\current
MinGW64 bin:     C:\Users\mirroam\scoop\apps\msys2\current\mingw64\bin
MSYS2 usr bin:   C:\Users\mirroam\scoop\apps\msys2\current\usr\bin
Bash 路径:       C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe
```

### 2.3 验证 MSYS2 环境

```powershell
# 验证 bash 可用
& "C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "echo 'MSYS2 OK'"

# 验证 mingw64 工具链
& "C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && gcc --version && make --version"
```

---

## 3. PostgreSQL 18.4 编译安装

### 3.1 通过 MSYS2 pacman 安装

最简单的方式是通过 MSYS2 的包管理器安装预编译的 PostgreSQL：

```bash
# 在 MSYS2 终端中执行
pacman -S mingw-w64-x86_64-postgresql
```

### 3.2 验证安装

```bash
# 检查 pg_config 路径
export PATH=/mingw64/bin:/usr/bin:$PATH
which pg_config
# 应输出: /mingw64/bin/pg_config

# 检查版本和路径
pg_config --version
# 应输出: PostgreSQL 18.4

pg_config --pgxs
# 应输出: .../mingw64/lib/postgresql/pgxs/src/makefiles/pgxs.mk

pg_config --libdir
# 应输出: .../mingw64/lib

pg_config --sharedir
# 应输出: .../mingw64/share/postgresql
```

### 3.3 关键路径

| 用途 | 路径 (MSYS2 内) | Windows 等价路径 |
|------|-----------------|------------------|
| pg_config | `/mingw64/bin/pg_config` | `C:\Users\mirroam\scoop\apps\msys2\current\mingw64\bin\pg_config.exe` |
| PG 库目录 | `/mingw64/lib/postgresql` | `...\mingw64\lib\postgresql` |
| PG 扩展 SQL | `/mingw64/share/postgresql/extension` | `...\mingw64\share\postgresql\extension` |
| PG 头文件 | `/mingw64/include/postgresql/server` | `...\mingw64\include\postgresql\server` |

---

## 4. Apache AGE 1.7.0 编译安装

### 4.1 源码位置

```
d:\dev\lawgraph\age-source\
├── src/           # C 源码
├── sql/           # SQL 定义文件
├── Makefile       # 编译规则
├── age.control    # 扩展控制文件
└── regress/       # 回归测试
```

### 4.2 编译安装

```bash
# 在 MSYS2 bash 中执行
export PATH=/mingw64/bin:/usr/bin:$PATH
cd /d/dev/lawgraph/age-source

# 编译
make PG_CONFIG=/mingw64/bin/pg_config

# 安装（将 .dll, .control, .sql 复制到 PG 目录）
make PG_CONFIG=/mingw64/bin/pg_config install
```

### 4.3 编译产物

安装后以下文件会被放置到 PG 目录：

| 文件 | 目标位置 | 用途 |
|------|---------|------|
| `age.dll` | `mingw64/lib/postgresql/age.dll` | C 扩展动态库 |
| `age.control` | `mingw64/share/postgresql/extension/age.control` | 扩展控制文件 |
| `age--1.7.0.sql` 等 | `mingw64/share/postgresql/extension/` | SQL 定义文件 |
| 头文件 | `mingw64/include/postgresql/server/extension/age/` | 开发头文件 |

### 4.4 验证安装

```sql
-- 检查扩展是否可用
SELECT name, default_version FROM pg_available_extensions WHERE name = 'age';
-- 应返回: age | 1.7.0
```

---

## 5. pgvector 0.8.2 编译安装

### 5.1 源码位置

```
d:\dev\lawgraph\pgvector\
├── src/           # C 源码 (vector.c, hnsw.c, ivfflat.c 等)
├── sql/           # SQL 定义文件 (含版本迁移脚本)
├── Makefile       # 编译规则
└── vector.control # 扩展控制文件
```

### 5.2 编译安装

```bash
# 在 MSYS2 bash 中执行
export PATH=/mingw64/bin:/usr/bin:$PATH
cd /d/dev/lawgraph/pgvector

# 清理（如之前编译过）
make clean

# 编译
make PG_CONFIG=/mingw64/bin/pg_config

# 安装
make PG_CONFIG=/mingw64/bin/pg_config install
```

### 5.3 编译产物

| 文件 | 目标位置 | 用途 |
|------|---------|------|
| `vector.dll` | `mingw64/lib/postgresql/vector.dll` | C 扩展动态库 |
| `vector.control` | `mingw64/share/postgresql/extension/vector.control` | 扩展控制文件 |
| `vector--0.8.2.sql` 等 | `mingw64/share/postgresql/extension/` | SQL 定义文件 |
| 头文件 | `mingw64/include/postgresql/server/extension/vector/` | 开发头文件 |

### 5.4 功能特性

pgvector 0.8.2 支持以下向量类型和索引：

| 类型 | 说明 | 最大维度 |
|------|------|---------|
| `vector` | 单精度浮点向量 | 16,000 |
| `halfvec` | 半精度浮点向量 | 16,000 |
| `bit` | 二进制向量 | 64,000 |
| `sparsevec` | 稀疏向量 | 1,000 非零元素 |

| 索引 | 算法 | 适用场景 |
|------|------|---------|
| HNSW | 层次化可导航小世界图 | 高召回率，低延迟查询 |
| IVFFlat | 倒排文件 + 扁平量化 | 大规模数据，内存效率高 |

| 距离函数 | 操作符 | 说明 |
|---------|--------|------|
| L2 距离 | `<->` | 欧几里得距离 |
| 内积 | `<#>` | 负内积 |
| 余弦距离 | `<=>` | 1 - 余弦相似度 |
| L1 距离 | `<+>` | 曼哈顿距离 |

### 5.5 验证安装

```sql
SELECT name, default_version FROM pg_available_extensions WHERE name = 'vector';
-- 应返回: vector | 0.8.2
```

---

## 6. 服务管理脚本

### 6.1 脚本文件

**文件路径**: `d:\dev\lawgraph\age-source\start_msys_pg.bat`

### 6.2 脚本内容

```batch
@echo off
set PATH=C:\Users\mirroam\scoop\apps\msys2\current\mingw64\bin;C:\Users\mirroam\scoop\apps\msys2\current\usr\bin;%PATH%

if /i "%~1"=="start" goto :start
if /i "%~1"=="status" goto :status
if /i "%~1"=="stop" goto :stop
if /i "%~1"=="restart" goto :restart

:start
"C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && if [ -d D:/mydata/pgdata ] && [ -f D:/mydata/pgdata/PG_VERSION ]; then echo 'Data dir exists, starting directly...'; else mkdir -p D:/mydata/pgdata && initdb -D D:/mydata/pgdata 2>&1 | tail -3; fi && pg_ctl -D D:/mydata/pgdata -o '-p 5433' -l D:/mydata/pgdata/logfile start 2>&1 && sleep 2 && psql -p 5433 -d postgres -c 'SELECT version();' 2>&1"
goto :eof

:status
"C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && echo '=== pg_ctl status ===' && pg_ctl -D D:/mydata/pgdata status 2>&1 && echo '' && echo '=== connection test ===' && psql -p 5433 -d postgres -c 'SELECT version();' 2>&1 && echo '' && echo '=== active connections ===' && psql -p 5433 -d postgres -c \"SELECT pid, usename, datname, state, query_start FROM pg_stat_activity WHERE datname IS NOT NULL;\" 2>&1"
goto :eof

:stop
"C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && pg_ctl -D D:/mydata/pgdata stop 2>&1"
goto :eof

:restart
"C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && pg_ctl -D D:/mydata/pgdata stop 2>&1; sleep 1 && pg_ctl -D D:/mydata/pgdata -o '-p 5433' -l D:/mydata/pgdata/logfile start 2>&1 && sleep 2 && psql -p 5433 -d postgres -c 'SELECT version();' 2>&1"
```

### 6.3 使用方法

```powershell
# 启动 PostgreSQL（首次运行自动初始化数据目录）
d:\dev\lawgraph\age-source\start_msys_pg.bat
# 或显式指定
d:\dev\lawgraph\age-source\start_msys_pg.bat start

# 查看服务状态（进程状态 + 连接测试 + 活动连接）
d:\dev\lawgraph\age-source\start_msys_pg.bat status

# 停止服务
d:\dev\lawgraph\age-source\start_msys_pg.bat stop

# 重启服务
d:\dev\lawgraph\age-source\start_msys_pg.bat restart
```

### 6.4 数据目录策略

| 行为 | 说明 |
|------|------|
| 首次启动 | 自动创建 `D:/mydata/pgdata` 并执行 `initdb` |
| 后续启动 | 检测到 `PG_VERSION` 文件存在，直接启动 |
| 数据持久化 | 数据目录不在临时目录，重启系统后数据不丢失 |

### 6.5 配置参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 数据目录 | `D:/mydata/pgdata` | 持久化存储 |
| 监听端口 | `5433` | 避免与 scoop PG (5432) 冲突 |
| 日志文件 | `D:/mydata/pgdata/logfile` | PG 运行日志 |
| Bash 路径 | MSYS2 bash | 确保 `/mingw64/bin` 在 PATH 中 |

---

## 7. 数据库初始化与用户配置

### 7.1 数据目录初始化

首次运行 `start_msys_pg.bat start` 时自动完成：

```bash
# 自动执行的逻辑
mkdir -p D:/mydata/pgdata
initdb -D D:/mydata/pgdata
pg_ctl -D D:/mydata/pgdata -o '-p 5433' -l D:/mydata/pgdata/logfile start
```

### 7.2 创建超级管理员用户

为 Odoo 应用创建专用用户：

```sql
-- 文件: d:\dev\lawgraph\age-source\create_odoo_user.sql
DO $$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'odoo') THEN
      CREATE ROLE odoo WITH LOGIN SUPERUSER PASSWORD 'odoo';
   ELSE
      ALTER ROLE odoo WITH LOGIN SUPERUSER PASSWORD 'odoo';
   END IF;
END $$;

SELECT rolname, rolsuper, rolcanlogin FROM pg_roles WHERE rolname = 'odoo';
```

执行方式：

```powershell
& "C:\Users\mirroam\scoop\apps\msys2\current\usr\bin\bash.exe" -c "export PATH=/mingw64/bin:/usr/bin:$PATH && psql -p 5433 -d postgres -f d:/dev/lawgraph/age-source/create_odoo_user.sql"
```

### 7.3 连接参数

| 参数 | 值 |
|------|-----|
| 主机 | localhost |
| 端口 | 5433 |
| 数据库 | postgres |
| 用户名 | odoo |
| 密码 | odoo |
| 连接字符串 | `postgresql://odoo:odoo@localhost:5433/postgres` |

---

## 8. 扩展启用与验证

### 8.1 启用 Apache AGE

```sql
-- 文件: d:\dev\lawgraph\age-source\enable_age.sql
CREATE EXTENSION IF NOT EXISTS age;
LOAD 'age';
SET search_path = ag_catalog, "$user", public;

-- 验证
SELECT extname, extversion FROM pg_extension WHERE extname = 'age';
SELECT * FROM ag_catalog.ag_graph;
```

### 8.2 启用 pgvector

```sql
-- 文件: d:\dev\lawgraph\age-source\enable_vector.sql
CREATE EXTENSION IF NOT EXISTS vector;

-- 验证
SELECT extname, extversion FROM pg_extension WHERE extname = 'vector';

-- 功能测试
CREATE TABLE IF NOT EXISTS vec_test (id serial PRIMARY KEY, embedding vector(3));
INSERT INTO vec_test (embedding) VALUES ('[1,2,3]'), ('[4,5,6]');
SELECT id, embedding, embedding <-> '[3,1,2]' AS distance FROM vec_test ORDER BY distance;
DROP TABLE vec_test;
```

### 8.3 完整验证清单

```sql
-- 1. 检查已安装扩展
SELECT extname, extversion FROM pg_extension WHERE extname IN ('age', 'vector');
-- 预期: age | 1.7.0, vector | 0.8.2

-- 2. AGE 功能测试
SELECT create_graph('test_graph');
SELECT * FROM cypher('test_graph', $$ CREATE (n:Person {name: 'Alice'}) $$) AS (a agtype);
SELECT * FROM cypher('test_graph', $$ MATCH (n) RETURN n $$) AS (n agtype);
SELECT drop_graph('test_graph', true);

-- 3. pgvector 功能测试
CREATE TABLE vec_test (id serial PRIMARY KEY, embedding vector(3));
INSERT INTO vec_test (embedding) VALUES ('[1,2,3]'), ('[4,5,6]');
SELECT id, embedding, embedding <-> '[3,1,2]' AS distance FROM vec_test ORDER BY distance;
DROP TABLE vec_test;

-- 4. 用户验证
SELECT rolname, rolsuper, rolcanlogin FROM pg_roles WHERE rolname = 'odoo';
-- 预期: odoo | t | t
```

### 8.4 AGE + pgvector 联合使用示例

```sql
-- 创建图
SELECT create_graph('legal_graph');

-- 创建带向量属性的节点
SELECT * FROM cypher('legal_graph', $$
    CREATE (n:Case {
        title: '借款合同纠纷',
        embedding: '[0.1, 0.2, 0.3, 0.4]'
    })
$$) AS (a agtype);

-- Cypher 查询
SELECT * FROM cypher('legal_graph', $$
    MATCH (n:Case) RETURN n.title
$$) AS (title agtype);
```

---

## 9. 故障排查

### 9.1 Git Bash vs MSYS2 Bash 问题

**问题现象**: 执行 `start_pg.bat`（使用 Git for Windows bash）时，实际调用了 scoop 安装的原生 Windows PostgreSQL，而非 MSYS2 编译的版本。

**诊断方法**: 检查 `SELECT version()` 输出：
- `compiled by msvc-19.44.35226` → 错误，使用了 scoop PG
- `compiled by gcc-16.1.0` → 正确，使用了 MSYS2 PG

**根因**: Git for Windows 的 bash 的 `/mingw64/bin` 下没有 PostgreSQL，PATH 回退到 Windows 环境变量，找到了 scoop 的 `pg_ctl.exe`。

**解决方案**: 始终使用 `start_msys_pg.bat`（MSYS2 bash），不要使用 Git for Windows bash。

### 9.2 扩展加载失败

**问题**: `CREATE EXTENSION age` 报错 `could not load library` 

**可能原因**:
1. AGE 编译时使用的 PG 版本与运行时不一致
2. DLL 依赖缺失

**排查**:
```bash
# 检查 DLL 依赖
ldd /mingw64/lib/postgresql/age.dll | grep "not found"

# 确认 pg_config 版本
pg_config --version
```

### 9.3 端口冲突

**问题**: `pg_ctl start` 报错 `port 5433 already in use`

**排查**:
```powershell
# 检查端口占用
netstat -ano | findstr 5433

# 查看占用进程
tasklist /FI "PID eq <pid>"
```

**解决**: 停止占用进程，或修改脚本中的端口号。

### 9.4 数据目录权限问题

**问题**: `initdb` 报错权限不足

**解决**: 确保 MSYS2 bash 对 `D:/mydata/pgdata` 有读写权限：
```bash
mkdir -p D:/mydata/pgdata
chmod 700 D:/mydata/pgdata
```

### 9.5 数据目录被占用

**问题**: `initdb` 报错 `directory exists but is not empty`

**注意**: 不要使用 `C:\Users\mirroam\scoop\persist\postgresql\data`，该目录已被 scoop 安装的 PostgreSQL 占用。

**解决**: 使用独立目录 `D:/mydata/pgdata`。

---

## 10. 快速参考卡片

### 10.1 日常操作速查

```
┌──────────────────────────────────────────────────────────┐
│           PostgreSQL 服务管理速查卡                       │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  启动:  start_msys_pg.bat start                          │
│  停止:  start_msys_pg.bat stop                           │
│  状态:  start_msys_pg.bat status                         │
│  重启:  start_msys_pg.bat restart                        │
│                                                          │
│  连接:  psql -p 5433 -d postgres -U odoo                 │
│  连接串: postgresql://odoo:odoo@localhost:5433/postgres  │
│                                                          │
│  数据目录: D:/mydata/pgdata                              │
│  日志文件: D:/mydata/pgdata/logfile                      │
│  端口:    5433                                           │
│                                                          │
├──────────────────────────────────────────────────────────┤
│                  已安装扩展                               │
├──────────────────────────────────────────────────────────┤
│  AGE 1.7.0    - Cypher 图数据库查询                      │
│  vector 0.8.2 - 向量相似度搜索 (HNSW/IVFFlat)            │
├──────────────────────────────────────────────────────────┤
│                  关键路径                                 │
├──────────────────────────────────────────────────────────┤
│  AGE 源码:     d:\dev\lawgraph\age-source                │
│  pgvector 源码: d:\dev\lawgraph\pgvector                 │
│  管理脚本:     d:\dev\lawgraph\age-source\start_msys_pg.bat │
│  SQL 脚本目录: d:\dev\lawgraph\age-source\               │
│    ├── enable_age.sql       - 启用 AGE                   │
│    ├── enable_vector.sql    - 启用 pgvector              │
│    ├── create_odoo_user.sql - 创建 odoo 用户             │
│    └── check_age.sql        - 检查 AGE 状态              │
└──────────────────────────────────────────────────────────┘
```

### 10.2 编译安装速查

```bash
# MSYS2 bash 环境下执行
export PATH=/mingw64/bin:/usr/bin:$PATH

# 编译安装 AGE
cd /d/dev/lawgraph/age-source
make PG_CONFIG=/mingw64/bin/pg_config
make PG_CONFIG=/mingw64/bin/pg_config install

# 编译安装 pgvector
cd /d/dev/lawgraph/pgvector
make clean
make PG_CONFIG=/mingw64/bin/pg_config
make PG_CONFIG=/mingw64/bin/pg_config install
```

### 10.3 SQL 操作速查

```sql
-- AGE 操作
LOAD 'age';
SET search_path = ag_catalog, "$user", public;
SELECT create_graph('my_graph');
SELECT * FROM cypher('my_graph', $$ CREATE (n:Label {prop: 'value'}) $$) AS (a agtype);
SELECT * FROM cypher('my_graph', $$ MATCH (n) RETURN n $$) AS (n agtype);
SELECT drop_graph('my_graph', true);

-- pgvector 操作
CREATE TABLE items (id serial PRIMARY KEY, embedding vector(3));
INSERT INTO items (embedding) VALUES ('[1,2,3]');
SELECT * FROM items ORDER BY embedding <-> '[3,1,2]' LIMIT 5;
-- 创建 HNSW 索引
CREATE INDEX ON items USING hnsw (embedding vector_l2_ops);
```

---

## 附录: 文件清单

| 文件 | 路径 | 用途 |
|------|------|------|
| 管理脚本 | `d:\dev\lawgraph\age-source\start_msys_pg.bat` | PG 服务管理 (start/stop/status/restart) |
| AGE 启用 | `d:\dev\lawgraph\age-source\enable_age.sql` | 启用 AGE 扩展 |
| pgvector 启用 | `d:\dev\lawgraph\age-source\enable_vector.sql` | 启用 vector 扩展 |
| 用户创建 | `d:\dev\lawgraph\age-source\create_odoo_user.sql` | 创建 odoo 超级用户 |
| AGE 检查 | `d:\dev\lawgraph\age-source\check_age.sql` | 检查 AGE 安装状态 |
| AGE 源码 | `d:\dev\lawgraph\age-source\` | Apache AGE 1.7.0 源码 |
| pgvector 源码 | `d:\dev\lawgraph\pgvector\` | pgvector 0.8.2 源码 |

---

## 标签

`PostgreSQL` `Apache-AGE` `pgvector` `MSYS2` `MinGW64` `图数据库` `向量搜索` `Cypher` `HNSW` `IVFFlat` `Windows` `数据库扩展` `Odoo` `法律可视化` `知识图谱` `编译安装` `服务管理`
