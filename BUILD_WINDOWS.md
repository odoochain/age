# Apache AGE v1.8.0 在 Windows 上编译运行完整指南

> 环境：Windows 10/11, PostgreSQL 18.4, MSYS2 MinGW64
> 版本：AGE 1.8.0（2026-08-26 从 1.7.0 合并 `apache/PG18` 升级并实测编译通过）

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

> **Scoop 安装位置约定（重要）**
>
> 本文用 `SCOOP_ROOT` 表示 Scoop 根目录：
>
> | 安装方式 | `SCOOP_ROOT` | MSYS2 完整路径 |
> |----------|--------------|----------------|
> | 本机自定义位置 | `d:\programs\scoop` | `d:\programs\scoop\apps\msys2\current` |
> | 默认用户目录 | `C:\Users\<用户名>\scoop` | `C:\Users\<用户名>\scoop\apps\msys2\current` |
>
> 脚本按 `%SCOOP%` → `d:\programs\scoop` → `C:\Users\%USERNAME%\scoop` 的顺序探测。
>
> **运行时兼容性（重要）**：AGE 必须安装到与其编译工具链兼容的 PostgreSQL。本文的 `mingw-w64-x86_64-postgresql` 与 AGE 产物面向 MSYS2/MinGW PostgreSQL；不能直接把 MinGW 编译的 `age.dll` 安装到 Scoop 提供的 MSVC PostgreSQL。Scoop 在这里负责安装和管理 MSYS2，实际运行 AGE 时仍需使用 MSYS2/MinGW PostgreSQL；如果只保留 Scoop 的 MSVC PostgreSQL，应改用与 MSVC ABI 匹配的 AGE 构建方式或使用 Docker/Linux。下文的 `SCOOP_ROOT` 指 Scoop 根目录，不代表 PostgreSQL 的 ABI。

### 3.1 安装 MSYS2

```powershell
scoop install msys2
```

### 3.2 安装编译工具链

> **全新 MSYS2 需先初始化密钥环**，否则 pacman 报 `key ... is unknown` / `invalid or corrupted database (PGP signature)`：
>
> ```bash
> pacman-key --init
> pacman-key --populate msys2
> pacman -Sy
> ```
>
> **国内网络注意**：如果本机通过代理出网，pacman 需显式设置代理，否则所有镜像"秒失败"（`Could not connect to server`，耗时仅 10ms 级）：
>
> ```bash
> export http_proxy=http://127.0.0.1:10808 https_proxy=http://127.0.0.1:10808
> ```
>
> 实测清华/中科大/阿里镜像在走代理时可能返回 **403**（镜像对代理出口 IP 有限制），此时保留官方 `mirror.msys2.org` 即可，pacman 会自动回退。

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
setlocal
if defined SCOOP (set "SCOOP_ROOT=%SCOOP%") else if exist "d:\programs\scoop" (set "SCOOP_ROOT=d:\programs\scoop") else (set "SCOOP_ROOT=C:\Users\%USERNAME%\scoop")
set "MSYS2=%SCOOP_ROOT%\apps\msys2\current"
if not exist "%MSYS2%\usr\bin\bash.exe" (
  echo ERROR: MSYS2 not found: %MSYS2%
  exit /b 1
)
set "PATH=%MSYS2%\mingw64\bin;%MSYS2%\mingw64\x86_64-w64-mingw32\bin;%MSYS2%\usr\bin;%PATH%"
cd /d "%~dp0"
"%MSYS2%\usr\bin\bash.exe" -lc "cd \"$(cygpath -u '%~dp0')\" && export PATH=/mingw64/bin:/mingw64/x86_64-w64-mingw32/bin:/usr/bin:$PATH && MAKEARGS='PG_CONFIG=/mingw64/bin/pg_config BISON=/usr/bin/bison FLEX=/usr/bin/flex PERL=/mingw64/bin/perl' && make $MAKEARGS clean > /tmp/age_clean.log 2>&1; make $MAKEARGS > /tmp/age_build.log 2>&1; echo EXIT_CODE=$? > /tmp/age_exit.txt"
type "%MSYS2%\tmp\age_exit.txt"
endlocal
```

> 两个关键点（见坑 5、坑 6）：`clean` 必须带 `PG_CONFIG` 且用 `;` 连接；bash 命令内需 `cd "$(cygpath -u '%~dp0')"`，因为 `-lc` 会切到 home 目录。

### 5.2 执行编译

```powershell
cd D:\odoochain\age-source
.\build_mingw.bat
```

成功输出：
```
EXIT_CODE=0
```

生成文件（1.8.0 实测）：
- `age.dll` (~1.09MB) — 扩展动态库
- `age--1.8.0.sql` (~154KB) — SQL 安装脚本

> 文件名由 `age.control` 的 `default_version` 推导（`Makefile` 中 `age_sql = age--$(AGE_CURR_VER).sql`），升级版本后无需手工改 Makefile。

### 5.3 安装扩展

**文件**：`install_mingw.bat`

```batch
@echo off
setlocal
if defined SCOOP (set "SCOOP_ROOT=%SCOOP%") else if exist "d:\programs\scoop" (set "SCOOP_ROOT=d:\programs\scoop") else (set "SCOOP_ROOT=C:\Users\%USERNAME%\scoop")
set "MSYS2=%SCOOP_ROOT%\apps\msys2\current"
if not exist "%MSYS2%\usr\bin\bash.exe" (
  echo ERROR: MSYS2 not found: %MSYS2%
  exit /b 1
)
set "PATH=%MSYS2%\mingw64\bin;%MSYS2%\mingw64\x86_64-w64-mingw32\bin;%MSYS2%\usr\bin;%PATH%"
cd /d "%~dp0"
"%MSYS2%\usr\bin\bash.exe" -lc "cd \"$(cygpath -u '%~dp0')\" && export PATH=/mingw64/bin:/mingw64/x86_64-w64-mingw32/bin:/usr/bin:$PATH && make PG_CONFIG=/mingw64/bin/pg_config BISON=/usr/bin/bison FLEX=/usr/bin/flex PERL=/mingw64/bin/perl install > /tmp/age_install.log 2>&1; echo EXIT_CODE=$? > /tmp/age_install.txt"
type "%MSYS2%\tmp\age_install.txt"
endlocal
```

安装位置（由 `pg_config` 决定）：
- `age.dll` → `$(pg_config --pkglibdir)/age.dll`
- `age.control`、`age--1.8.0.sql`、`age--1.7.0--1.8.0.sql` → `$(pg_config --sharedir)/extension/`

## 六、运行测试

### 6.1 启动 PostgreSQL（运行 AGE 的目标实例）

> MSYS2 在本流程中负责 AGE 编译，并提供 ABI 匹配的 MinGW PostgreSQL 运行环境；编译产物不能直接安装到 Scoop 提供的 MSVC PostgreSQL。下文以独立的 MSYS2/MinGW PostgreSQL 实例（5433）为准；如果只保留 Scoop 的 MSVC PostgreSQL，应改用 ABI 匹配的 AGE 构建方式或使用 Docker/Linux。

```bash
# 初始化（仅首次，使用 MSYS2/MinGW PostgreSQL 的 initdb）
initdb -D D:/mydata/pgdata

# 启动独立的 MSYS2/MinGW PostgreSQL 实例（5433）
pg_ctl -D D:/mydata/pgdata -o '-p 5433' -l D:/mydata/pgdata/logfile start
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

-- MERGE ON CREATE / ON MATCH（1.8.0 起支持）
-- 第一次执行：节点不存在 -> 走 ON CREATE，只设 created
SELECT * FROM cypher('test_graph', $$
  MERGE (n:Item {name: 'a'})
  ON CREATE SET n.created = true
  ON MATCH SET n.matched = true
  RETURN n.name, n.created, n.matched
$$) AS (name agtype, created agtype, matched agtype);

-- 重复执行同一语句：节点已存在 -> 走 ON MATCH，只设 matched
```

> **1.8.0 实测结果**：两个子句同时存在时能正确二选一（新建只触发 `ON CREATE`，命中只触发 `ON MATCH`），语义正确。1.7.0 时该功能不可用，属上游 issue #1619，已在 1.8.0 修复。

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
| MERGE ON CREATE/ON MATCH | ✅ | 1.8.0 起支持（上游 issue #1619 修复），1.7.0 不支持 |

## 八、已知限制

| 限制 | 说明 |
|------|------|
| 内联多 CREATE 关系 | 变量作用域问题，需用 MATCH + CREATE 分开写 |
| 扩展目标 PG | MSYS2/MinGW 用于编译并运行 AGE；编译出的 `age.dll`/`age--1.7.0.sql` 只能安装到 ABI 匹配的 MSYS2/MinGW PostgreSQL（本流程为 5433），不能直接安装到 Scoop 的 MSVC PostgreSQL |
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

> **2026-08-26 补充**：不要用 `as.exe --version; echo $?` 判断此问题。实测在工具链完全正常的机器上该命令也返回 `exit=127`（属误报）。可靠判断方式是直接试编译：
>
> ```bash
> printf 'int main(void){return 0;}\n' > /tmp/t.c && gcc /tmp/t.c -o /tmp/t.exe && echo OK
> ```
>
> 应以 `ldd` 是否出现 `not found`、以及上面的试编译结果为准。

### 坑 5：`make clean` 报 "No rule to make target 'clean'"（1.8.0 新增）

**原因**：AGE 1.8.0 重构了 `Makefile`，`clean` 等目标由 PGXS 提供，而 PGXS 只有在传入 `PG_CONFIG` 时才会被正确加载。1.7.0 时代 `make clean` 可裸跑，升级后不行。

**解决**：`clean` 也要带上完整参数，且用 `;` 而非 `&&` 连接（首次构建时没有可清理内容，不应阻断后续编译）：

```bash
MAKEARGS='PG_CONFIG=/mingw64/bin/pg_config BISON=/usr/bin/bison FLEX=/usr/bin/flex PERL=/mingw64/bin/perl'
make $MAKEARGS clean; make $MAKEARGS
```

### 坑 6：`make` 报 "No targets specified and no makefile found"

**原因**：`bash -lc` 是 login shell，启动时会切到用户 home 目录，把 `.bat` 里的 `cd /d "%~dp0"` 覆盖掉，导致 make 在错误目录执行。

**解决**：在 bash 命令内部显式切回脚本目录：

```bat
"%MSYS2%\usr\bin\bash.exe" -lc "cd \"$(cygpath -u '%~dp0')\" && export PATH=... && make ..."
```

### 坑 2：PGXS 的 BISON/FLEX/PERL 路径错误

**原因**：`pg_config` 返回 MSYS2 编译时缓存的路径（如 `D:\M\msys64` 或 `%SCOOP_ROOT%\apps\msys2\current`），与实际安装路径不同。

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
*最近更新：2026-08-26（升级到 AGE 1.8.0：合并 `apache/PG18`，5 处 MinGW 补丁自动保留；新增坑 5/坑 6、pacman 密钥环与代理说明；修正 Scoop 位置为 `d:\programs\scoop` 兼容写法）*
*编译与运行环境：Windows + MSYS2 MinGW64 + GCC 16.1.0 + PostgreSQL 18.4（MSYS2/MinGW，5433）*
*Scoop 路径：`SCOOP_ROOT` 优先取 `%SCOOP%`，其次 `d:\programs\scoop`，最后回退 `C:\Users\<用户名>\scoop`*
*已验证：编译 EXIT_CODE=0、安装 EXIT_CODE=0、扩展版本 1.8.0；Cypher 基础功能与 MERGE ON CREATE/ON MATCH 实测通过*
