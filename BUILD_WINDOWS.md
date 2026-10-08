# Apache AGE v1.8.0 在 Windows 上编译运行完整指南

> 环境：Windows 10/11, PostgreSQL 18.4, MSYS2 MinGW64
> 版本：AGE 1.8.0（2026-08-26 从 1.7.0 合并 `apache/PG18` 升级并实测编译通过）
> 2026-10-07 补充：新增 §八之二（与其他扩展共存）、坑 8（`search_path`）、坑 9（`plpython3u` 运行时）、坑 10（实例崩溃）

## 一、背景

Apache AGE 是 PostgreSQL 的图数据库扩展，原生仅支持 Linux/Unix。本文记录了在 Windows 上成功编译运行的完整过程，包括遇到的所有坑和解决方案。

配套的扩展栈整体说明（本机实例为何用 MinGW PostgreSQL、与 pgvector/Jev 的版本关系、对 CI 的影响）见 `d:\odoochain\odoochain\doc\dev\postgres-extensions.md`。

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

完整回归应使用专用 MinGW PostgreSQL 安装目录和数据目录，以 `initdb --encoding=UTF8 --locale=C` 初始化，并选用空闲端口。不要对业务实例的共享扩展目录执行 `make install`；单独创建测试数据库并不能隔离 DLL。`installcheck-existing` 会删除并重建测试数据库，因此手工预建库的编码/排序规则不会保留。该目标强制 UTF8，但实例仍须采用 C 排序规则。

CSV 导入根目录由超管参数 `age.csv_directory` 指定，默认仍为 `/tmp/age/`。Windows 应指定本机绝对路径（例如 `D:/age-import`）；导入参数为根目录下的相对文件名。原有 `pg_read_server_files`、表权限和 RLS 检查仍然生效，路径遍历、目录外链接和 NTFS 数据流路径被拒绝。根目录及其父目录必须由可信管理员管理，不能允许不可信用户并发替换文件或链接。

`age_load` 回归使用 `regress/age_load/prepare.pl` 在 `regress/results/csv` 准备专用夹具，不再依赖 `/tmp` 或 `cmd` 下的 `mkdir -p`。请在 PATH 中提供完整 Perl（包括核心模块）和 GNU diff；MSYS2 的 Perl 会通过 `cygpath` 转换为原生 Windows 路径。

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
| `search_path` 依赖 | AGE 的对象（含 `graphid_ops`）装在 `ag_catalog`，会话 `search_path` 不含它时 `create_graph` 会失败。详见坑 8 |

## 八之二、与其他扩展共存（2026-10-07 实测）

在同一个 PostgreSQL 18.4（MSYS2/MinGW，5433）实例、同一个数据库内，AGE 可与 pgvector、`plpython3u`、Jev 同时加载，各自功能独立可用：

```
 extname   | extversion
-----------+------------
 age       | 1.8.0
 jev       | 0.2.1
 plpython3u| 1.0
 vector    | 0.8.6
```

| 组件 | 实测结果 |
|---|---|
| AGE 1.8.0 | 建图、`cypher()` 增改查、`drop_graph()` 均通过 |
| pgvector 0.8.6 | `vector(3)` 类型与 `<->` 距离运算符通过 |
| Jev 0.2.1 | `CREATE EXTENSION jev CASCADE` 成功，`jev_version()` 返回 `0.2.1`，10 个函数注册，GUC 可设置 |
| plpython3u | 需先装 MinGW Python，见坑 9 |

**注意**：`plpython3u` 是 untrusted 语言，Jev 依赖它。若不想让 untrusted 语言与图数据库共处同一实例，应另起一个实例承载 Jev（例如 5434），代价是跨实例无法直接 JOIN。

相关上下文见 `d:\odoochain\odoochain\doc\dev\postgres-extensions.md`。

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

### 坑 7：`SET search_path` 的 `"$user"` 被 shell 展开

**现象**：
```
ERROR:  unterminated quoted identifier at or near """", public;"
LINE 1: LOAD 'age'; SET search_path = ag_catalog, """, public;
```

**原因**：PostgreSQL 的 `search_path` 需要字面量 `"$user"`。若把这段 SQL 内联在 `bash -c "..."` 的双引号里，`$user` 会被 bash 当作变量展开为空字符串，导致引号数量错乱。层层 `\\\"` 转义几乎无法写对。

**解决**：**不要在命令行内联含 `"$user"` 的 SQL**，写入 `.sql` 文件后用 `-f` 执行：

```bat
REM test_cypher.bat —— 正确做法
"%MSYS2%\usr\bin\bash.exe" -lc "cd \"$(cygpath -u '%~dp0')\" && export PATH=/mingw64/bin:/usr/bin:$PATH && psql -p 5433 -d age_test -f test_cypher.sql 2>&1"
```

`.sql` 文件里照常写 `SET search_path = ag_catalog, "$user", public;` 即可，不需要任何转义。

> 补充：`SET search_path` 的另一个作用是省略 `ag_catalog.` 前缀。但**对于 `create_graph` 这类函数，设置 `search_path` 是必需的，不能只靠写全限定名**——详见坑 8。

### 坑 8：`create_graph` 报 `operator class "graphid_ops" does not exist`（2026-10-07 新增）

**现象**：

```
ERROR:  operator class "graphid_ops" does not exist for access method "btree"
STATEMENT:  SELECT ag_catalog.create_graph('my_graph');
```

**极易误判**：这个报错看起来像「AGE 没装好」或「PG 18 不兼容」，实际两者都不是。

**原因**：`graphid_ops` **确实存在**，但 AGE 把它装在 `ag_catalog` schema 下：

```sql
SELECT n.nspname, o.opcname, a.amname
FROM pg_opclass o
JOIN pg_am a ON a.oid = o.opcmethod
JOIN pg_namespace n ON n.oid = o.opcnamespace
WHERE o.opcname LIKE '%graphid%';
```

```
  nspname   |     opcname      | amname
------------+------------------+--------
 ag_catalog | graphid_ops      | btree
 ag_catalog | graphid_ops_hash | hash
```

而会话 `search_path` 默认是 `"$user", public`，**不包含 `ag_catalog`**。AGE 内部建表时按非限定名查找操作符类，于是找不到自己装的对象。

**解决**：设置 `search_path` 包含 `ag_catalog`：

```sql
SET search_path = ag_catalog, "$user", public;
SELECT ag_catalog.create_graph('my_graph');
```

**注意**：即使写全限定名 `ag_catalog.create_graph(...)` 也**不能**绕开，因为失败发生在函数内部对操作符类的查找上，不是函数调用本身。

**对应用接入的影响**：从应用连接（如 Odoo）时，必须在会话初始化时设置 `search_path`，不能只在 `psql` 里设。否则应用侧建图会失败，而手工在 psql 里执行却是成功的——这是最迷惑人的地方。

### 坑 9：`CREATE EXTENSION plpython3u` 失败，缺 `libpython3.14.dll`（2026-10-07 新增）

**现象**：

```
$ ldd $(pg_config --pkglibdir)/plpython3.dll
    libpython3.14.dll => not found
```

`plpython3u.control` 与 `plpython3--1.0.sql` 都在，但扩展无法加载。

**原因**：MinGW 的 Python 运行时未安装。注意 MSYS2 的 `/usr/bin` 下的 python 与 Scoop 的 Windows Python **都不满足**——需要 ABI 匹配的 MinGW 版本。

**解决**：

```bash
pacman -S mingw-w64-x86_64-python      # 实测装到 3.14.5-1
ldd $(pg_config --pkglibdir)/plpython3.dll   # 确认 not found 归零
```

装好后可通过实际调用验证：

```sql
CREATE EXTENSION plpython3u;
CREATE FUNCTION pyver() RETURNS text LANGUAGE plpython3u AS
$$ import sys; return sys.version $$;
SELECT pyver();
-- 3.14.5 (main, May 12 2026) [MINGW GCC 16.1.0 64 bit (AMD64)]
```

此坑与 AGE 本身无关，但会影响依赖 `plpython3u` 的扩展（如 Jev），见 §八之二。

### 坑 10：实例崩溃 `exception 0xC0000142`（2026-10-07 记录，原因未确认）

**现象**：日志出现

```
LOG:  autovacuum worker (PID 6128) was terminated by exception 0xC0000142
LOG:  terminating any other active server processes
LOG:  all server processes terminated; reinitializing
```

`0xC0000142` 是 Windows 的 `STATUS_DLL_INIT_FAILED`，表示进程初始化阶段 DLL 失败，**不能仅凭此码确定故障 DLL 或归因于 PL/Python**。扩展文件位于共享目录，不意味着 autovacuum 会自动加载该扩展。

**恢复边界**：历史上在确认实例归属后 `stop -m fast` 再启动，曾恢复连接并触发 WAL 恢复；但未核验业务数据完整性，不能声称已证明无数据丢失。操作须安排维护窗口，先核对数据目录、PID、日志占用与其他连接，不要重复启动或强杀所有 `postgres.exe`。

**完整日志复查（2026-10-07）**：当天至少五次 `0xC0000142`：06:37、06:43、07:25、07:57、09:51。其中 06:43 为 `client backend`，其余为 autovacuum worker。因此问题不局限于 autovacuum，也不只出现两次。

**预加载对照结果（2026-10-07）**：另建 UTF8/C locale 的隔离测试集群，使用同一 MinGW PostgreSQL 18.4 安装、独立端口 55433，不改动或重启原 5433 实例：

| 条件 | Jev 原始回归 | 40 次新会话 PL/Python 调用 | 实际 autovacuum | 崩溃 |
|---|---|---|---|---|
| 不预加载，09:59:51–10:08:13 CST | 4/4 通过 | 通过，4 路并发 | 发生，死元组归零 | 未复现 |
| `shared_preload_libraries=plpython3`，10:09:19–10:13:39 CST | 4/4 通过 | 通过，4 路并发 | 再次发生，死元组归零 | 未复现 |

**两组都通过，不能据此认定预加载是修复。** 观察窗口短且不等长，尚不能排除原集群配置、进程启动环境、资源限制或长时间运行因素。测试只使用本地 mock API，无真实外发数据；临时实例已正常停止，预加载仅为启动参数。

[PostgreSQL 18 官方文档](https://www.postgresql.org/docs/18/runtime-config-client.html#GUC-SHARED-PRELOAD-LIBRARIES)说明，Windows 的每个新服务端进程仍会重新加载预加载库。不要把预加载当成“一次加载后不再初始化 DLL”的办法。

**后续取证**：保留日志并定位 Windows 事件、故障模块、进程转储；对比 PATH、DLL 解析路径、启动方式和资源状态。本轮未取得可归因的 Windows 事件证据，未修改 WER 或注册表。不要在未定位时改业务 `shared_preload_libraries`、关闭 autovacuum，或反复 CREATE/DROP PL/Python 作为规避。扩展压力实验应继续使用独立实例。详细参数与结果见 `d:\odoochain\odoochain\doc\dev\postgres-extensions.md` §6。

**结论已改（2026-10-07 16:55）：崩溃与扩展无关，属环境级故障。**

决定性对照：用**同一** `2026-06-11` 二进制、**同一端口** 5433 新建一个 `initdb` 空集群（UTF8/C locale，不装任何扩展、无业务数据），运行约 25 分钟后同样以 `autovacuum worker ... exception 0xC0000142` 崩溃并 `reinitializing`。

因此 AGE、pgvector、Jev、PL/Python **均不是诱因**，数据目录也不是。这同时解释了预加载/不预加载两组对照为何都通过——当时系统尚未进入故障状态。

三次独立采集（PID 44000 / 43516 / 37496）模块数均为 47，`python` / `plpython` / `age` / `vector` 匹配均为 0；非系统模块只有 `postgres.exe` 与 MinGW 运行时。

**重启只能短暂恢复**：15:23 就绪→15:52 崩；重启→16:24 在启动后约 1 秒即崩（普通 client backend）；17:26 就绪→17:56 又不可连接。失败类型不局限于 autovacuum，也不需要长时间运行才触发。

**根因已定位（2026-10-07 转储分析）**：三份转储经 WinDbg 加载微软符号后结论一致——`WER.BlockedOn: AlpcPort`，`FAILURE_BUCKET_ID: APPLICATION_HANG_BlockedOn_AlpcPort_...postgres.exe`。主线程栈：

```
ntdll!NtAlpcSendWaitReceivePort    ← 无限等待
ntdll!CsrClientCallServer          ← 向 CSRSS 注册新进程
KERNELBASE!CreateProcessInternalW
kernel32!CreateProcessAStub
postgres!PostmasterMain
```

PostgreSQL 在 Windows 上无 `fork()`，每个后端都用 `CreateProcess` 创建，而该调用必须经 **ALPC 与 CSRSS** 通信。该通信阻塞后，postmaster 主线程无限等待——这正是「进程存活、仍监听、却不产出后端也不写日志」的原因。`0xC0000142` 是子进程初始化失败的**结果**，不是原因。

这也解释了为何独立进程创建正常（`postgres --version`、`initdb` 均 exit=0）：它们由 shell 发起，不经过已阻塞的 postmaster 主线程。

**与 AGE 及任何扩展无关**：栈上无扩展模块，三份转储模块数均 47，`python`/`plpython`/`age`/`vector` 匹配均为 0。

**不要再对比 MinGW 与 MSVC 版 PostgreSQL** —— 阻塞在 Windows 进程创建路径上，与编译器 ABI 无关。

排查方向应转向拦截 `CreateProcess` 的第三方组件（安全软件、备份代理、磁盘服务；本机 `WDDriveService` 持 10421 句柄，为首要怀疑对象），以及会话资源压力（会话 1 有 268 个进程）。缓解可考虑给 PG 目录加杀毒排除项、减少会话进程数，或改以服务方式（会话 0）运行。详细证据与后续步骤见 `d:\odoochain\odoochain\doc\dev\postgres-extensions.md` §6.2.2–6.4。

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
*最近更新：2026-10-07（新增 §八之二 与其他扩展共存；新增坑 8 `search_path` 缺失导致 `create_graph` 失败、坑 9 `plpython3u` 缺 `libpython3.14.dll`、坑 10 实例崩溃 `0xC0000142` 与恢复；修正坑 7 中关于 `search_path` 仅为省略前缀的说法）*
*历史更新：2026-08-26（升级到 AGE 1.8.0：合并 `apache/PG18`，5 处 MinGW 补丁自动保留；新增坑 5/坑 6、pacman 密钥环与代理说明；修正 Scoop 位置为 `d:\programs\scoop` 兼容写法）*
*编译与运行环境：Windows + MSYS2 MinGW64 + GCC 16.1.0 + PostgreSQL 18.4（MSYS2/MinGW，5433）*
*Scoop 路径：`SCOOP_ROOT` 优先取 `%SCOOP%`，其次 `d:\programs\scoop`，最后回退 `C:\Users\<用户名>\scoop`*
*已验证：编译 EXIT_CODE=0、安装 EXIT_CODE=0、扩展版本 1.8.0；Cypher 基础功能与 MERGE ON CREATE/ON MATCH 实测通过*
*2026-10-07 另测：AGE 1.8.0 与 pgvector 0.8.6、`plpython3u` 1.0、Jev 0.2.1 在同一库中共存且各自可用*
