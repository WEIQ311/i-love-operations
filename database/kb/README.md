# 人大金仓数据库(KingbaseES)备份工具

提供用于人大金仓数据库全量备份和恢复的Shell脚本工具。

## 工具介绍

- `kb_backup.sh`: 数据库备份脚本
- `kb_backup_ultra.sh`: 数据库备份脚本（极致压缩版）
- `kb_restore.sh`: 数据库恢复脚本
- `kb_restore_multi.sh`: 数据库恢复脚本（支持多种压缩格式）

## 系统要求

- 人大金仓数据库客户端工具 (sys_dump, sys_restore, ksql)
- Bash shell 环境 (如 Git Bash, WSL, 或 Linux/Mac)

## 使用方法

### 备份数据库

```bash
# 备份单个数据库
./kb_backup.sh -d testdb

# 备份多个数据库
./kb_backup.sh -d db1,db2,db3

# 指定主机和端口
./kb_backup.sh -h 192.168.1.100 -p 54321 -d testdb

# 指定备份目录和格式
./kb_backup.sh -d testdb -D /data/backups -f tar -c 9

# 排除特定表
./kb_backup.sh -d testdb --exclude-table 'temp_*'

# 详细输出
./kb_backup.sh -d testdb --verbose

# 极致压缩备份（使用xz压缩算法）
./kb_backup_ultra.sh -d testdb -c xz

# 极致压缩备份（使用7z压缩算法）
./kb_backup_ultra.sh -d testdb -c 7z
```

### 恢复数据库

```bash
# 恢复数据库
./kb_restore.sh -d testdb -s ./backups/testdb_20231201_120000.dmp

# 指定主机和端口
./kb_restore.sh -h 192.168.1.100 -p 54321 -d testdb -s ./backups/testdb_20231201_120000.dmp

# 恢复时清除现有对象
./kb_restore.sh -d testdb -s ./backups/testdb_20231201_120000.dmp --clean

# 恢复gzip压缩的备份文件
./kb_restore_multi.sh -d testdb -s ./backups/testdb_20231201_120000.dmp.gz

# 恢复xz压缩的备份文件
./kb_restore_multi.sh -d testdb -s ./backups/testdb_20231201_120000.dmp.xz

# 恢复7z压缩的备份文件
./kb_restore_multi.sh -d testdb -s ./backups/testdb_20231201_120000.dmp.7z
```
# 详细输出
./kb_restore.sh -d testdb -s ./backups/testdb_20231201_120000.dmp --verbose
```

### 参数说明

#### 备份参数

- `-h, --host HOST`: 数据库主机地址 (默认: localhost)
- `-p, --port PORT`: 数据库端口 (默认: 54321)
- `-U, --username USER`: 用户名 (默认: system)
- `-W, --password PASS`: 密码 (默认: manager)
- `-d, --database DB`: 要备份的数据库名 (可指定多个，用逗号分隔)
- `-D, --directory DIR`: 备份文件存储目录 (默认: ./backups)
- `-f, --format FORMAT`: 备份格式 (custom, tar, plain，默认: custom)
- `-c, --compress LEVEL`: 压缩级别 (0-9，默认: 9)，9为最高压缩比，显著减少存储空间
- `--exclude-table PATTERN`: 排除的表模式 (支持通配符)
- `--exclude-schema SCHEMA`: 排除的模式
- `--clean`: 在备份文件中添加清理命令
- `--no-owner`: 不备份对象所有权信息
- `--verbose`: 详细输出

#### 恢复参数

- `-h, --host HOST`: 数据库主机地址 (默认: localhost)
- `-p, --port PORT`: 数据库端口 (默认: 54321)
- `-U, --username USER`: 用户名 (默认: system)
- `-W, --password PASS`: 密码 (默认: manager)
- `-d, --database DB`: 要恢复的目标数据库名
- `-s, --source SOURCE`: 备份源文件路径
- `-c, --clean`: 恢复前清除目标数据库对象
- `-n, --no-owner`: 不恢复对象所有权信息
- `-x, --no-privileges`: 不恢复访问权限（GRANT/REVOKE命令）
- `-O, --no-acl`: 不恢复访问控制权限
- `-v, --verbose`: 详细输出
- `--single-transaction`: 作为单个事务恢复

## 配置文件

脚本会读取同目录下的 `.env` 文件获取默认数据库连接参数。

## 备份文件命名规则

备份文件按以下格式命名：
```
{数据库名}_{日期时间}.{格式后缀}
# 例如: testdb_20231201_120000.dmp
```

## 注意事项

1. 在执行备份或恢复操作前，请确保数据库服务正在运行
2. 确保有足够的磁盘空间存放备份文件
3. 对于生产环境，在执行恢复操作前请先备份当前数据
4. 备份和恢复过程中保持网络连接稳定
