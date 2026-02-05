# 数据库监控调度器

统一调度管理多个数据库实例的监控任务，支持并发执行，自动处理错误和日志记录，并将监控数据入库存储。

## 功能特点

- **多数据库支持**：支持 MySQL、PostgreSQL、达梦、金仓、Oracle、SQL Server、MongoDB
- **多实例管理**：可配置多个相同类型的数据库实例（如多个 MySQL 实例）
- **并发执行**：支持并发执行多个数据库监控任务，提高效率
- **灵活配置**：通过 JSON 配置文件管理所有数据库实例
- **错误处理**：完善的错误处理和日志记录机制
- **标准化输出**：所有监控结果以 JSON 格式保存
- **监控数据入库**：支持将监控结果存储到目标数据库中
- **持续监控模式**：支持持续监控目录，实时处理新的监控文件
- **统一监控目录**：所有监控结果统一存储在调度器目录的 `monitor` 子目录中

## 目录结构

```
database/scheduler/
├── scheduler.py               # 主调度器脚本
├── config.json                # 数据库实例配置文件
├── monitor_to_db.py           # 监控数据入库脚本
├── monitor_to_db_config.json  # 监控数据入库配置文件
├── scheduler.log              # 日志文件
├── monitor/                   # 监控结果存储目录
│   └── 2026-02-04/            # 按日期分目录
│       ├── mysql_prod_20260204_171555.json
│       ├── postgres_prod_20260204_171559.json
│       └── ...
└── README.md                  # 本说明文件
```

## 安装依赖

使用统一的依赖管理文件安装所有依赖：

```bash
# 在 database 目录下运行
pip install -r requirements.txt
```

## 配置说明

### 1. 数据库实例配置 (`config.json`)

编辑 `config.json` 文件配置数据库实例：

```json
{
  "concurrent_execution": true, // 是否并发执行
  "database_instances": [
    {
      "type": "mysql",          // 数据库类型
      "name": "mysql_prod",     // 实例名称
      "enabled": true,          // 是否启用
      "config": {
        "host": "localhost",    // 主机地址
        "port": 3306,            // 端口
        "user": "root",         // 用户名
        "password": "password",  // 密码
        "database": "information_schema" // 数据库名
      }
    },
    // 更多数据库实例...
  ]
}
```

### 2. 监控数据入库配置 (`monitor_to_db_config.json`)

编辑 `monitor_to_db_config.json` 文件配置监控数据入库参数：

```json
{
  "db_type": "mysql",           // 目标数据库类型
  "host": "localhost",          // 主机地址
  "port": 3306,                  // 端口
  "user": "root",               // 用户名
  "password": "password",        // 密码
  "database": "monitor",         // 数据库名
  "sid": "ORCL"                  // Oracle 数据库 SID（其他数据库可忽略）
}
```

### 支持的数据库类型

| 数据库类型 | 配置前缀 | 默认端口 |
|-----------|----------|----------|
| mysql     | MYSQL    | 3306     |
| postgresql| POSTGRES | 5432     |
| dm        | DM       | 5236     |
| kb        | KB       | 54321    |
| oracle    | ORACLE   | 1521     |
| mssql     | MSSQL    | 1433     |
| mongodb   | MONGO    | 27017    |

## 使用方法

### 1. 运行调度器

```bash
# 在 scheduler 目录下运行（单次执行）
python scheduler.py

# 在 Linux 上使用 crontab 定时执行（推荐）
# 例如，每5分钟执行一次
# */5 * * * * cd /path/to/i-love-operations/database/scheduler && python scheduler.py >> scheduler.log 2>&1
```

### 2. 运行监控数据入库脚本

#### 2.1 一次性入库模式

```bash
# 在 scheduler 目录下运行
python monitor_to_db.py
```

#### 2.2 持续监控模式

```bash
# 在 scheduler 目录下运行，每30秒检查一次新文件
python monitor_to_db.py --continuous --interval 30
```

### 3. 查看监控结果

- 监控结果会实时输出到控制台
- 详细日志记录在 `scheduler.log` 文件中
- 所有数据库实例的监控结果统一保存在 `scheduler/monitor` 目录中，并按日期分目录存储
- 监控数据入库后，可在目标数据库的 `monitor_main` 和 `monitor_alerts` 表中查看

## 配置示例

### 配置多个 MySQL 实例

```json
{
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
      "type": "mysql",
      "name": "mysql_staging",
      "enabled": true,
      "config": {
        "host": "localhost",
        "port": 3307,
        "user": "root",
        "password": "password",
        "database": "information_schema"
      }
    }
  ]
}
```

### 配置混合数据库实例

```json
{
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

## 常见问题

### 1. 数据库连接失败

- 检查数据库实例的配置信息是否正确
- 检查数据库服务是否正常运行
- 检查网络连接是否畅通
- 检查数据库用户权限是否足够

### 2. 调度器运行缓慢

- 减少并发执行的数据库实例数量
- 检查系统资源使用情况

### 3. 监控结果未生成

- 检查 `scheduler/monitor` 目录是否存在且有写权限
- 检查磁盘空间是否充足

### 4. 监控数据入库失败

- 检查 `monitor_to_db_config.json` 配置是否正确
- 检查目标数据库服务是否正常运行
- 检查目标数据库用户是否有创建表和插入数据的权限

## 扩展说明

### 添加新的数据库类型

1. 在 `database` 目录下创建新的数据库监控目录
2. 实现标准的监控接口（参考现有数据库监控实现）
3. 在 `scheduler.py` 中的 `DB_TYPE_MAPPING` 中添加新数据库类型

### 自定义监控阈值

每个数据库实例的监控阈值可以在对应数据库目录的 `.env` 文件中配置。

## 运行环境

- Python 3.6+
- 对应数据库的 Python 驱动
- 操作系统：Windows、Linux、macOS

## 注意事项

- 确保所有数据库驱动已正确安装
- 配置文件中的密码等敏感信息请妥善保管
- 建议在生产环境中使用适当的日志轮转机制
- 对于大量数据库实例，建议调整并发执行的最大工作线程数
- 持续监控模式下，建议将脚本作为后台服务运行
