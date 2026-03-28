# Doris 表副本数检测和修改工具

## 功能说明

合并的脚本工具，支持：
1. **检测**：检测Doris数据库中所有副本数为1的表
2. **修改**：将指定表的副本数修改为固定值（可配置变量）

## 脚本文件

1. **doris_replication.py** - Python版本（推荐）
2. **doris_replication.sh** - Bash版本

## 使用方法

### Python版本

#### 前置要求
```bash
pip install pymysql
```

#### 检测副本数为1的表
```bash
python doris_replication.py check -H 192.168.1.181 -P 9030 -u root -p root
```

#### 检测并直接修改
```bash
# 检测副本数为1的表，并直接修改为3
python doris_replication.py check -H 192.168.1.181 -P 9030 -u root -p root --alter 3
```

#### 修改表的副本数
```bash
# 从文件读取表列表并修改
python doris_replication.py alter -H 192.168.1.181 -P 9030 -u root -p root -f tables.txt -n 3

# 修改单个表
python doris_replication.py alter -H 192.168.1.181 -P 9030 -u root -p root -d test_db -t table1 -n 3

# 修改整个数据库的所有表
python doris_replication.py alter -H 192.168.1.181 -P 9030 -u root -p root -d test_db --all-tables -n 3

# 预览SQL（dry-run模式）
python doris_replication.py alter -H 192.168.1.181 -P 9030 -u root -p root -f tables.txt -n 3 --dry-run
```

### Bash版本

#### 前置要求
- 需要安装 MySQL 客户端工具（mysql命令）

#### 检测副本数为1的表
```bash
bash doris_replication.sh check -H 192.168.1.181 -P 9030 -u root -p root
```

#### 检测并直接修改
```bash
# 检测副本数为1的表，并直接修改为3
bash doris_replication.sh check -H 192.168.1.181 -P 9030 -u root -p root --alter 3
```

#### 修改表的副本数
```bash
# 从文件读取表列表并修改
bash doris_replication.sh alter -H 192.168.1.181 -P 9030 -u root -p root -f tables.txt -n 3

# 修改单个表
bash doris_replication.sh alter -H 192.168.1.181 -P 9030 -u root -p root -d test_db -t table1 -n 3

# 修改整个数据库的所有表
bash doris_replication.sh alter -H 192.168.1.181 -P 9030 -u root -p root -d test_db --all-tables -n 3
```

## 参数说明

### 通用参数
- `-H, --host`: Doris FE节点地址（默认: localhost）
- `-P, --port`: Doris FE查询端口（默认: 9030）
- `-u, --user`: 用户名（默认: root）
- `-p, --password`: 密码（默认: 空）

### 检测操作（check）
- `-o, --output`: 输出文件名（默认: doris_replication_one_tables_YYYYMMDD_HHMMSS.txt）
- `--alter NUM`: 检测后直接修改为指定副本数

### 修改操作（alter）
- `-n, --replication-num`: **目标副本数（必需）**
- `-f, --file`: 包含表列表的文件路径（格式：库名\t表名）
- `-d, --database`: 数据库名（与-t一起使用，或与--all-tables一起使用）
- `-t, --table`: 表名（需要与-d一起使用）
- `--all-tables`: 修改指定数据库下所有表的副本数（需要与-d一起使用）
- `-o, --output`: 结果输出文件（默认: alter_replication_result_YYYYMMDD_HHMMSS.txt）
- `--dry-run`: 仅显示将要执行的SQL，不实际执行

## 完整工作流程示例

### 方式1：检测后手动修改
```bash
# 1. 检测副本数为1的表
python doris_replication.py check -H 192.168.1.181 -P 9030 -u root -p root

# 2. 查看检测结果
cat doris_replication_one_tables_*.txt

# 3. 修改检测出的表
python doris_replication.py alter -H 192.168.1.181 -P 9030 -u root -p root \
  -f doris_replication_one_tables_*.txt -n 3
```

### 方式2：检测后直接修改（推荐）
```bash
# 一步完成：检测并直接修改为3
python doris_replication.py check -H 192.168.1.181 -P 9030 -u root -p root --alter 3
```

### 方式3：直接修改指定表
```bash
# 修改单个表
python doris_replication.py alter -H 192.168.1.181 -P 9030 -u root -p root \
  -d test_db -t table1 -n 3

# 修改整个数据库的所有表
python doris_replication.py alter -H 192.168.1.181 -P 9030 -u root -p root \
  -d test_db --all-tables -n 3
```

## 输出文件格式

### 检测结果文件
```
# Doris数据库副本数为1的表检测结果
# 检测时间: 2024-01-15 10:30:45
# 数据库地址: 192.168.1.181:9030
# 共找到 5 个副本数为1的表
# ============================================================

库名	表名
------------------------------------------------------------
test_db	table1
test_db	table2
prod_db	table3
...
```

### 修改结果文件
```
# Doris表副本数修改结果
# 修改时间: 2024-01-15 10:30:45
# 数据库地址: 192.168.1.181:9030
# 目标副本数: 3
# 共处理: 5 个表
# 成功: 4 个
# 失败: 1 个
# ============================================================

库名	表名	状态	错误信息
------------------------------------------------------------
test_db	table1	成功	-
test_db	table2	成功	-
prod_db	table3	成功	-
prod_db	table4	失败	Access denied
...
```

## 注意事项

1. **目标副本数（-n/--replication-num）是必需参数**，必须指定要修改为的副本数
2. 脚本会自动排除系统数据库（information_schema, sys, __internal_schema）
3. 修改操作会实际执行ALTER TABLE语句，建议先使用 `--dry-run` 模式预览
4. 如果表正在使用中，修改副本数可能需要一些时间
5. 建议在业务低峰期执行批量修改操作
6. 使用 `--alter` 参数可以检测后直接修改，无需中间文件

## 故障排查

### Python版本
- 如果提示 `pymysql` 未安装，运行: `pip install pymysql`
- 连接失败时检查网络、地址、端口、用户名密码和防火墙设置

### Bash版本
- 如果提示 `mysql` 命令未找到，需要安装 MySQL 客户端
- 连接问题排查同Python版本
