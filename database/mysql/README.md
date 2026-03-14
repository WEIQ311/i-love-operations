# MySQL数据库备份工具

提供用于MySQL数据库全量备份和恢复的Shell脚本工具。

## 工具介绍

- `mysql_backup.sh`: MySQL数据库备份脚本
- `mysql_backup_ultra.sh`: MySQL数据库备份脚本（极致压缩版）
- `mysql_restore.sh`: MySQL数据库恢复脚本
- `mysql_restore_multi.sh`: MySQL数据库恢复脚本（支持多种压缩格式）

## 系统要求

- MySQL客户端工具 (mysqldump, mysql)
- Bash shell 环境 (如 Git Bash, WSL, 或 Linux/Mac)

## 使用方法

### 备份数据库

```bash
# 备份单个数据库
./mysql_backup.sh -d testdb

# 备份多个数据库
./mysql_backup.sh -d db1,db2,db3

# 指定主机和端口
./mysql_backup.sh -h 192.168.1.100 -p 3306 -d testdb

# 指定备份目录并压缩
./mysql_backup.sh -d testdb -D /data/backups --compress

# 排除特定表
./mysql_backup.sh -d testdb --exclude-table 'temp_*'

# 详细输出
./mysql_backup.sh -d testdb --verbose

# 极致压缩备份（使用xz压缩算法）
./mysql_backup_ultra.sh -d testdb -c xz

# 极致压缩备份（使用7z压缩算法）
./mysql_backup_ultra.sh -d testdb -c 7z
```

### 恢复数据库

```bash
# 恢复数据库
./mysql_restore.sh -d testdb -s ./backups/testdb_20231201_120000.sql

# 指定主机和端口
./mysql_restore.sh -h 192.168.1.100 -P 3306 -d testdb -s ./backups/testdb_20231201_120000.sql

# 详细输出
./mysql_restore.sh -d testdb -s ./backups/testdb_20231201_120000.sql --verbose

# 恢复gzip压缩的备份文件
./mysql_restore_multi.sh -d testdb -s ./backups/testdb_20231201_120000.sql.gz

# 恢复xz压缩的备份文件
./mysql_restore_multi.sh -d testdb -s ./backups/testdb_20231201_120000.sql.xz

# 恢复7z压缩的备份文件
./mysql_restore_multi.sh -d testdb -s ./backups/testdb_20231201_120000.sql.7z
```

### 参数说明

#### 备份参数

- `-h, --host HOST`: 数据库主机地址 (默认: localhost)
- `-p, --port PORT`: 数据库端口 (默认: 3306)
- `-u, --username USER`: 用户名 (默认: root)
- `-P, --password PASS`: 密码 (默认: password)
- `-d, --database DB`: 要备份的数据库名 (可指定多个，用逗号分隔)
- `-D, --directory DIR`: 备份文件存储目录 (默认: ./backups)
- `-c, --compress`: 压缩备份文件 (使用最高压缩比 -9，显著减少存储空间)
- `--exclude-table PATTERN`: 排除的表模式 (支持通配符)
- `--single-transaction`: 使用单一事务保证一致性
- `--routines`: 包含存储过程和函数
- `--triggers`: 包含触发器
- `--events`: 包含事件调度器事件
- `--verbose`: 详细输出

#### 恢复参数

- `-h, --host HOST`: 数据库主机地址 (默认: localhost)
- `-P, --port PORT`: 数据库端口 (默认: 3306)
- `-u, --username USER`: 用户名 (默认: root)
- `-p, --password PASS`: 密码 (默认: password)
- `-d, --database DB`: 要恢复的目标数据库名
- `-s, --source SOURCE`: 备份源文件路径
- `-v, --verbose`: 详细输出

## 配置文件

脚本会读取同目录下的 `.env` 文件获取默认数据库连接参数。

## 备份文件命名规则

备份文件按以下格式命名：
```
{数据库名}_{日期时间}.sql[.gz]
# 例如: testdb_20231201_120000.sql (未压缩)
# 例如: testdb_20231201_120000.sql.gz (压缩)
```

## 注意事项

1. 在执行备份或恢复操作前，请确保MySQL服务正在运行
2. 确保有足够的磁盘空间存放备份文件
3. 对于生产环境，在执行恢复操作前请先备份当前数据
4. 备份和恢复过程中保持网络连接稳定
5. 恢复操作会向目标数据库写入数据，请确保目标数据库已存在
6. 支持将一个库的备份恢复到另一个不同的库中