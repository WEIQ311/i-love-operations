# 数据库监控模块

## 模块简介

本模块是一个全面的数据库监控系统，支持多种数据库类型的监控，包括连接状态、性能指标、资源使用情况等。通过统一的调度器，可以同时监控多个数据库实例，并提供阈值告警和监控结果存储功能。

## 支持的数据库类型

- **MySQL**：关系型数据库
- **PostgreSQL**：开源关系型数据库
- **达梦数据库 (DM)**：国产关系型数据库
- **金仓数据库 (Kingbase)**：国产关系型数据库
- **Oracle**：商业关系型数据库
- **SQL Server**：微软关系型数据库
- **MongoDB**：NoSQL数据库

## 功能特性

- **多数据库支持**：统一监控多种类型的数据库
- **全面的监控指标**：包括连接状态、连接数、QPS、慢查询、缓存命中率、表空间使用情况、进程列表和复制状态等
- **阈值告警**：根据预设阈值生成告警信息
- **监控结果存储**：将监控结果保存为JSON文件，按日期分目录存储
- **并发执行**：支持并发执行多个数据库监控任务，提高监控效率
- **灵活的配置**：通过配置文件管理多个数据库实例
- **连接测试**：支持测试数据库连接是否正常

## 目录结构

```
database/
├── dm/                # 达梦数据库监控
│   ├── __init__.py
│   └── dm_monitor.py
├── kb/                # 金仓数据库监控
│   ├── __init__.py
│   └── kb_monitor.py
├── mongodb/           # MongoDB监控
│   ├── __init__.py
│   └── mongodb_monitor.py
├── mssql/             # SQL Server监控
│   ├── __init__.py
│   └── mssql_monitor.py
├── mysql/             # MySQL监控
│   ├── __init__.py
│   └── mysql_monitor.py
├── oracle/            # Oracle监控
│   ├── __init__.py
│   └── oracle_monitor.py
├── pg/                # PostgreSQL监控
│   ├── __init__.py
│   └── postgresql_monitor.py
├── scheduler/         # 监控调度器
│   ├── README.md
│   ├── __init__.py
│   ├── config.json
│   ├── monitor_to_db.py
│   ├── monitor_to_db_config.json
│   ├── scheduler.py
│   └── monitor/        # 监控结果存储目录
├── __init__.py
└── requirements.txt   # 依赖包配置
```

## 安装与依赖

### 安装依赖

```bash
# 进入模块目录
cd /path/to/database

# 安装依赖
pip install -r requirements.txt
```

### 依赖说明

| 依赖包 | 用途 | 对应数据库 |
|-------|------|-----------|
| python-dotenv | 环境变量管理 | 通用 |
| pymysql | MySQL驱动 | MySQL |
| psycopg2-binary | PostgreSQL驱动 | PostgreSQL/金仓 |
| oracledb | Oracle驱动 | Oracle |
| pyodbc | SQL Server驱动 | SQL Server |
| pymongo | MongoDB驱动 | MongoDB |
| dmPython | 达梦数据库驱动 | 达梦数据库 |

## 配置说明

### 环境变量配置

可以通过环境变量配置监控参数，优先级低于配置文件。主要环境变量包括：

- **数据库连接配置**：如 `MYSQL_HOST`、`POSTGRES_USER` 等
- **监控阈值**：如 `MAX_CONNECTIONS_THRESHOLD`、`MAX_QPS_THRESHOLD` 等
- **监控间隔**：`MONITOR_INTERVAL`
- **告警配置**：`ALERT_ENABLED`、`ALERT_EMAIL`

### 调度器配置

在 `scheduler/config.json` 文件中配置数据库实例：

```json
{
  "concurrent_execution": true,
  "database_instances": [
    {
      "type": "mysql",
      "name": "mysql_prod",
      "enabled": true,
      "config": {
        "host": "localhost",
        "port": 3306,
        "user": "root",
        "password": "password",
        "database": "information_schema"
      }
    },
    {
      "type": "postgresql",
      "name": "postgres_prod",
      "enabled": true,
      "config": {
        "host": "localhost",
        "port": 5432,
        "user": "postgres",
        "password": "postgres",
        "database": "postgres"
      }
    }
    // 其他数据库实例配置...
  ]
}
```

## 使用方法

### 单个数据库监控

可以直接运行对应数据库的监控脚本：

```bash
# 监控MySQL
python mysql/mysql_monitor.py

# 监控PostgreSQL
python pg/postgresql_monitor.py

# 监控其他数据库类似...
```

### 批量监控（使用调度器）

使用调度器可以同时监控多个数据库实例：

```bash
# 进入调度器目录
cd scheduler

# 运行调度器
python scheduler.py
```

### 定时执行

可以通过系统的定时任务工具（如crontab）定期执行监控：

```bash
# 编辑crontab
crontab -e

# 添加定时任务（每5分钟执行一次）
*/5 * * * * cd /path/to/database/scheduler && python scheduler.py
```

## 监控指标说明

### 通用指标

| 指标 | 说明 | 单位 |
|-----|------|------|
| connection_status | 数据库连接状态 | 布尔值 |
| connection_stats | 连接统计信息 | - |
| qps | 每秒查询数 | 次/秒 |
| slow_queries | 慢查询数 | 条 |
| cache_hit_rate | 缓存命中率 | % |
| tablespace_usage | 表空间使用情况 | % |
| process_list | 数据库进程列表 | - |
| replication_status | 复制状态（主从/副本） | - |

### 各数据库特有指标

- **MySQL**：InnoDB缓存命中率、查询缓存命中率、主从复制延迟等
- **PostgreSQL**：共享缓冲区命中率、复制延迟等
- **Oracle**：SGA使用情况、PGA使用情况等
- **MongoDB**：集合大小、索引使用情况等

## 告警机制

系统会根据预设阈值生成告警信息，主要告警类型包括：

- **连接数使用率过高**：超过设置的阈值
- **QPS过高**：超过设置的阈值
- **存在慢查询**：检测到慢查询
- **缓存命中率过低**：低于设置的阈值
- **表空间使用率过高**：超过设置的阈值
- **复制状态异常**：主从复制或副本状态异常

告警信息会在控制台输出，同时可以扩展邮件发送功能。

## 监控结果存储

监控结果会以JSON格式存储在 `scheduler/monitor/` 目录下，按日期分目录存储。每个监控结果文件包含：

- 时间戳
- 监控时间
- 实例名称
- 监控指标数据
- 告警信息
- 阈值配置

## 示例配置

### 完整的配置文件示例

```json
{
  "concurrent_execution": true,
  "database_instances": [
    {
      "type": "mysql",
      "name": "mysql_prod",
      "enabled": true,
      "config": {
        "host": "localhost",
        "port": 3306,
        "user": "root",
        "password": "password",
        "database": "information_schema"
      }
    },
    {
      "type": "postgresql",
      "name": "postgres_prod",
      "enabled": true,
      "config": {
        "host": "localhost",
        "port": 5432,
        "user": "postgres",
        "password": "postgres",
        "database": "postgres"
      }
    },
    {
      "type": "dm",
      "name": "dm_prod",
      "enabled": true,
      "config": {
        "host": "localhost",
        "port": 5236,
        "user": "SYSDBA",
        "password": "SYSDBA",
        "database": "SYSTEM"
      }
    },
    {
      "type": "kb",
      "name": "kb_prod",
      "enabled": true,
      "config": {
        "host": "localhost",
        "port": 54321,
        "user": "system",
        "password": "manager",
        "database": "test"
      }
    },
    {
      "type": "oracle",
      "name": "oracle_prod",
      "enabled": true,
      "config": {
        "host": "localhost",
        "port": 1521,
        "user": "system",
        "password": "oracle",
        "sid": "ORCL"
      }
    },
    {
      "type": "mssql",
      "name": "mssql_prod",
      "enabled": true,
      "config": {
        "host": "localhost",
        "port": 1433,
        "user": "sa",
        "password": "Password123",
        "database": "master"
      }
    },
    {
      "type": "mongodb",
      "name": "mongodb_prod",
      "enabled": true,
      "config": {
        "host": "localhost",
        "port": 27017,
        "user": "",
        "password": "",
        "database": "admin"
      }
    }
  ]
}
```

## 注意事项

1. **权限配置**：监控用户需要有足够的权限获取数据库状态信息
2. **网络连接**：确保监控服务器可以访问目标数据库
3. **性能影响**：监控操作会对数据库产生一定的性能影响，建议合理设置监控间隔
4. **安全考虑**：配置文件中包含数据库密码，建议适当保护
5. **存储管理**：监控结果会占用磁盘空间，建议定期清理或归档
6. **依赖安装**：某些数据库驱动可能需要额外的系统依赖（如Oracle客户端）

## 扩展与定制

### 添加新的数据库监控

1. 在对应目录创建监控脚本（如 `newdb/newdb_monitor.py`）
2. 实现监控类，参考现有监控脚本的结构
3. 在 `scheduler.py` 中的 `DB_TYPE_MAPPING` 中添加数据库类型映射
4. 在配置文件中添加数据库实例配置

### 自定义监控指标

可以在对应数据库的监控脚本中添加自定义监控指标，修改 `get_*` 方法和 `run_monitor` 方法。

### 告警扩展

可以扩展 `send_alert` 方法，添加邮件、短信等告警方式。

## 故障排查

### 常见问题

1. **数据库连接失败**：检查网络连接、用户名密码、防火墙设置
2. **监控脚本执行失败**：检查依赖包安装、Python版本兼容性
3. **告警信息不准确**：调整阈值配置，根据实际情况设置合理的阈值
4. **监控结果存储失败**：检查目录权限、磁盘空间

### 日志查看

调度器执行日志会输出到控制台和 `scheduler.log` 文件中，可以通过查看日志排查问题。

## 版本历史

- **v1.0**：初始版本，支持MySQL、PostgreSQL、达梦、金仓、Oracle、SQL Server、MongoDB监控

## 贡献

欢迎提交Issue和Pull Request，共同完善数据库监控模块。

## 许可证

本项目采用MIT许可证。