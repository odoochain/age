# Apache AGE v1.7.0 在 Windows 上编译运行完整指南

> 环境：Windows 10/11, PostgreSQL 18.4, MSYS2 MinGW64

## 一、背景

Apache AGE 是 PostgreSQL 的图数据库扩展，原生仅支持 Linux/Unix。本文记录了在 Windows 上成功编译运行的完整过程，包括遇到的所有坑和解决方案。

## 二、为什么不能用 MSVC

尝试过使用 VS Build Tools (MSVC) 编译，但 Apache AGE 的源码与 Windows SDK 存在大量命名冲突：

| 冲突项 | 来源 | 说明 |
|--------|------|------|
| `STRING` | `winternl.h` | Windows typedef `STRING`，与 Bison token 冲突 |
| `CHAR` | `winnt.h` | `typedef char CHAR`，与 Bison token 冲突 |
| `DELETE` | `winnt.h` | `#define DELETE ((ACCESS_MASK)0x00010000L)` |
| `IN` | `minwindef.h` | Windows 宏，与 Cypher 关键字冲突 |
| `OPTIONAL` | `ntdef.h` | Windows 注解宏 |
| `uint` | 不存在 | MSVC 不提供 `uint` 类型 |
| `clock_gettime` | POSIX | Windows 不支持 |
| `realpath` | POSIX | Windows 不支持 |

**结论：使用 MSYS2 MinGW64 工具链是最佳方案。**

## 三、环境搭建

### 3.1 安装 MSYS2

```powershell
scoop install msys2
```

### 3.2 安装编译工具链

在 MSYS2 MinGW64 终端中：

```bash
pacman --noconfirm -S make
pacman --noconfirm -S mingw-w64-x86_64-gcc mingw-w64-x86_64-make \
       mingw-w64-x86_64-postgresql flex bison mingw-w64-x86_64-perl
```

### 3.3 修复 zlib1.dll 冲突

**关键发现**：MSYS2 的 `as.exe`（汇编器）在 `x86_64-w64-mingw32/bin/` 目录下运行时，会错误加载 Windows System32 中的 `zlib1.dll`，导致汇编器静默失败。

```bash
cp /mingw64/bin/zlib1.dll /mingw64/x86_64-w64-mingw32/bin/zlib1.dll
```

**验证方法**：
```bash
# 如果 exit=127 说明 DLL 冲突
/mingw64/x86_64-w64-mingw32/bin/as.exe --version
# 如果 exit=0 说明修复成功
```

## 四、源码修改

需要对 Apache AGE 源码做以下修改：

### 4.1 重命名冲突的 Bison Token

**文件**：`src/backend/parser/cypher_gram.y`

```diff
-%token <string> DECIMAL STRING
+%token <string> DECIMAL CYTOK_STRING

-%token <character> CHAR
+%token <character> CYTOK_CHAR

-    | STRING
+    | CYTOK_STRING
```

**文件**：`src/backend/parser/cypher_parser.c`

```diff
-        STRING,
+        CYTOK_STRING,

-        CHAR,
+        CYTOK_CHAR,
```

### 4.2 修复 `uint` 类型

**文件**：`src/backend/parser/cypher_gram.y`

```diff
-    uint nlen = 0;
+    unsigned int nlen = 0;
```

### 4.3 添加 Windows 宏 #undef

**文件**：`src/include/parser/cypher_gram.h`

在 `#include "parser/cypher_gram_def.h"` 之前添加：

```c
#ifdef _WIN32
#undef IN
#undef OUT
#undef DELETE
#undef VOID
#undef OPTIONAL
#undef near
#undef far
#endif
#include "parser/cypher_gram_def.h"
```

**注意**：不要 `#undef ERROR`，因为 PostgreSQL 的 `ereport(ERROR, ...)` 需要它。

### 4.4 修复 `clock_gettime`（Windows 不支持）

**文件**：`src/backend/utils/adt/agtype.c` 第 10302 行附近

```diff
-    clock_gettime(CLOCK_REALTIME, &ts);
-    ms += (ts.tv_sec * 1000) + (ts.tv_nsec / 1000000);
+#ifdef _WIN32
+    {
+        FILETIME ft;
+        GetSystemTimeAsFileTime(&ft);
+        uint64_t t = ((uint64_t)ft.dwHighDateTime << 32) | ft.dwLowDateTime;
+        ms = (long)((t - 116444736000000000ULL) / 10000);
+    }
+#else
+    clock_gettime(CLOCK_REALTIME, &ts);
+    ms += (ts.tv_sec * 1000) + (ts.tv_nsec / 1000000);
+#endif
```

### 4.5 修复 `realpath`（Windows 不支持）

**文件**：`src/backend/utils/load/age_load.c` 第 120 行附近

```diff
-    resolved = realpath(path, NULL);
+#ifdef _WIN32
+    resolved = _fullpath(NULL, path, MAXPGPATH);
+#else
+    resolved = realpath(path, NULL);
+#endif
```

## 五、编译构建

### 5.1 创建构建脚本

**文件**：`build_mingw.bat`

```batch
@echo off
set PATH=C:\Users\%USERNAME%\scoop\apps\msys2\current\mingw64\bin;C:\Users\%USERNAME%\scoop\apps\msys2\current\mingw64\x86_64-w64-mingw32\bin;C:\Users\%USERNAME%\scoop\apps\msys2\current\usr\bin;%PATH%
cd /d "%~dp0"
bash -lc "export PATH=/mingw64/bin:/mingw64/x86_64-w64-mingw32/bin:/usr/bin:$PATH && make clean > /tmp/age_clean.log 2>&1 && make PG_CONFIG=/mingw64/bin/pg_config BISON=/usr/bin/bison FLEX=/usr/bin/flex PERL=/mingw64/bin/perl > /tmp/age_build.log 2>&1; echo EXIT_CODE=$? > /tmp/age_exit.txt"
type C:\Users\%USERNAME%\scoop\apps\msys2\current\tmp\age_exit.txt
```

### 5.2 执行编译

```powershell
cd D:\odoochain\odoo19\age-source
.\build_mingw.bat
```

成功输出：
```
EXIT_CODE=0
```

生成文件：
- `age.dll` (~960KB) — 扩展动态库
- `age--1.7.0.sql` (~113KB) — SQL 安装脚本

### 5.3 安装扩展

**文件**：`install_mingw.bat`

```batch
@echo off
set PATH=C:\Users\%USERNAME%\scoop\apps\msys2\current\mingw64\bin;C:\Users\%USERNAME%\scoop\apps\msys2\current\mingw64\x86_64-w64-mingw32\bin;C:\Users\%USERNAME%\scoop\apps\msys2\current\usr\bin;%PATH%
cd /d "%~dp0"
bash -lc "export PATH=/mingw64/bin:/mingw64/x86_64-w64-mingw32/bin:/usr/bin:$PATH && make PG_CONFIG=/mingw64/bin/pg_config BISON=/usr/bin/bison FLEX=/usr/bin/flex PERL=/mingw64/bin/perl install > /tmp/age_install.log 2>&1; echo EXIT_CODE=$? > /tmp/age_install.txt"
type C:\Users\%USERNAME%\scoop\apps\msys2\current\tmp\age_install.txt
```

## 六、运行测试

### 6.1 启动 PostgreSQL（MSYS2 版本）

```bash
# 初始化（仅首次）
initdb -D /tmp/pgdata

# 启动（使用 5433 端口避免与 scoop PostgreSQL 冲突）
pg_ctl -D /tmp/pgdata -o '-p 5433' -l /tmp/pgdata/logfile start
```

### 6.2 加载扩展

```sql
-- 创建测试数据库
CREATE DATABASE age_test;
\c age_test

-- 加载 AGE
CREATE EXTENSION age;
LOAD 'age';
SET search_path = ag_catalog, "$user", public;
```

### 6.3 验证功能

```sql
-- 创建图
SELECT create_graph('test_graph');

-- 创建节点
SELECT * FROM cypher('test_graph', $$
  CREATE (a:Person {name: 'Alice', age: 30})
  CREATE (b:Person {name: 'Bob', age: 25})
  RETURN a, b
$$) AS (a agtype, b agtype);

-- 创建关系（使用 MATCH + CREATE）
SELECT * FROM cypher('test_graph', $$
  MATCH (a:Person {name: 'Alice'}), (b:Person {name: 'Bob'})
  CREATE (a)-[:KNOWS {since: 2020}]->(b)
  RETURN a.name, b.name
$$) AS (a agtype, b agtype);

-- 查询关系
SELECT * FROM cypher('test_graph', $$
  MATCH (a:Person)-[r:KNOWS]->(b:Person)
  RETURN a.name AS from_person, b.name AS to_person, r.since
$$) AS (from_person agtype, to_person agtype, since agtype);

-- 聚合查询
SELECT * FROM cypher('company', $$
  MATCH (e:Employee)-[:WORKS_IN]->(d:Department)
  RETURN d.name AS dept, count(e) AS headcount, avg(e.salary) AS avg_salary
$$) AS (dept agtype, headcount agtype, avg_salary agtype);
```

## 七、已验证功能

| 功能 | 状态 | 示例 |
|------|------|------|
| 节点 CRUD | ✅ | CREATE/MATCH/DELETE 节点 |
| 边创建 | ✅ | MATCH + CREATE 方式 |
| 模式匹配 | ✅ | MATCH (a)-[r]->(b) |
| 多跳遍历 | ✅ | MATCH (a)-[:KNOWS*1..2]->(c) |
| WHERE 过滤 | ✅ | WHERE p.age > 28 |
| 聚合 | ✅ | count, avg, collect |
| OPTIONAL MATCH | ✅ | 左连接 |
| WITH 管道 | ✅ | 数据流处理 |
| UNWIND | ✅ | 列表展开 |
| 列表推导 | ✅ | [x IN list WHERE x > 2 \| x * 10] |
| Map 投影 | ✅ | p {.*, .name} |
| CASE WHEN | ✅ | 条件分支 |
| DELETE | ✅ | DETACH DELETE |

## 八、已知限制

| 限制 | 说明 |
|------|------|
| MERGE ON MATCH/ON CREATE | AGE 1.7.0 在此环境不支持 |
| 内联多 CREATE 关系 | 变量作用域问题，需用 MATCH + CREATE 分开写 |
| 端口冲突 | MSYS2 PG 与 scoop PG 需用不同端口 |
| DLL 搜索顺序 | 需手动复制 zlib1.dll 到 binutils 目录 |

## 九、踩坑记录

### 坑 1：GCC 编译静默失败（exit=1, 无输出）

**原因**：`as.exe` 加载了 Windows System32 的 `zlib1.dll` 而非 MSYS2 的。

**排查方法**：
```bash
# 检查 as.exe 的 DLL 依赖
ldd /mingw64/x86_64-w64-mingw32/bin/as.exe
# 如果看到 zlib1.dll => /c/Windows/SYSTEM32/zlib1.dll 就是问题所在
```

**解决**：`cp /mingw64/bin/zlib1.dll /mingw64/x86_64-w64-mingw32/bin/`

### 坑 2：PGXS 的 BISON/FLEX/PERL 路径错误

**原因**：`pg_config` 返回 MSYS2 编译时缓存的路径（如 `D:\M\msys64`），但实际安装路径不同。

**解决**：在 make 命令中显式覆盖：
```bash
make PG_CONFIG=/mingw64/bin/pg_config BISON=/usr/bin/bison FLEX=/usr/bin/flex PERL=/mingw64/bin/perl
```

### 坑 3：Windows 宏与 Bison Token 冲突

**原因**：Windows 头文件定义了 `IN`, `DELETE`, `OPTIONAL` 等宏，与 AGE 的 Bison 生成的枚举值冲突。

**解决**：在 `cypher_gram.h` 中 `#include "parser/cypher_gram_def.h"` 前 `#undef` 冲突宏。

**注意**：不要 `#undef ERROR`，因为 PG 的 `ereport(ERROR, ...)` 依赖它。

### 坑 4：PowerShell 引号转义问题

**原因**：PowerShell 对 `$`, `\`, `"` 的转义规则与 bash 不同。

**解决**：
- 使用 `.bat` 文件调用 MSYS2 bash
- 使用 `.sql` 文件存储 SQL 脚本
- 避免在 PowerShell 中直接嵌套复杂 shell 命令

## 十、文件清单

```
age-source/
├── build_mingw.bat          # 编译脚本
├── install_mingw.bat        # 安装脚本
├── test_complex.sql         # 复杂查询测试
├── test_edges.sql           # 关系测试
└── src/
    ├── backend/parser/
    │   ├── cypher_gram.y    # 修改：重命名 token, uint
    │   └── cypher_parser.c  # 修改：更新 type_map
    ├── include/parser/
    │   └── cypher_gram.h    # 修改：添加 #undef
    └── backend/utils/
        ├── adt/agtype.c     # 修改：clock_gettime
        └── load/age_load.c  # 修改：realpath
```

---

*文档创建时间：2026-06-17*
*编译环境：Windows + MSYS2 MinGW64 + GCC 16.1.0 + PostgreSQL 18.4*
