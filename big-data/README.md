# 大数据组件管理工具集

## 模块简介

本模块提供了一套用于管理和监控大数据生态系统各个组件的工具脚本，包括HDFS、YARN、MapReduce、Hive、Spark、Kafka、HBase和ZooKeeper等。这些工具适用于Hadoop 2.x及以上版本。

## 支持的组件

| 组件 | 功能描述 | 目录 | 脚本文件 |
|-----|---------|------|--------|
| HDFS | 分布式文件系统 | hdfs/ | hdfs-block-*.sh |
| YARN | 资源管理器 | yarn/ | yarn-diagnose.sh |
| MapReduce | 分布式计算框架 | mapreduce/ | mapreduce-diagnose.sh |
| Hive | 数据仓库工具 | hive/ | hive-diagnose.sh |
| Spark | 快速计算引擎 | spark/ | spark-diagnose.sh |
| Kafka | 消息队列系统 | kafka/ | kafka-diagnose.sh |
| HBase | 分布式数据库 | hbase/ | hbase-diagnose.sh |
| ZooKeeper | 分布式协调服务 | zookeeper/ | zookeeper-diagnose.sh |

## 目录结构

```
big-data/
├── hdfs/                # HDFS管理工具
│   ├── README.md
│   ├── hdfs-block-diagnose.sh
│   ├── hdfs-block-repair.sh
│   └── hdfs-block-auto-repair.sh
├── yarn/                # YARN管理工具
│   └── yarn-diagnose.sh
├── mapreduce/           # MapReduce管理工具
│   └── mapreduce-diagnose.sh
├── hive/                # Hive管理工具
│   └── hive-diagnose.sh
├── spark/               # Spark管理工具
│   └── spark-diagnose.sh
├── kafka/               # Kafka管理工具
│   └── kafka-diagnose.sh
├── hbase/               # HBase管理工具
│   └── hbase-diagnose.sh
├── zookeeper/           # ZooKeeper管理工具
│   └── zookeeper-diagnose.sh
└── README.md            # 本说明文档
```

## 功能特性

- **全面的诊断**：检查各个组件的状态、配置和运行情况
- **智能修复**：HDFS组件支持自动修复块问题
- **详细的日志**：记录完整的操作过程和结果
- **统一的格式**：所有脚本使用相同的日志格式和执行流程
- **错误处理**：添加了错误处理，确保脚本在各种情况下都能正常运行
- **版本兼容性**：适用于Hadoop 2.x及以上版本

## 安装与配置

### 前置条件

1. **大数据环境**：已安装并配置好相应的大数据组件
2. **权限**：执行脚本的用户需要有相应组件的管理权限
3. **路径配置**：相关组件的命令已添加到系统PATH中，或已设置相应的环境变量（如KAFKA_HOME、HBASE_HOME等）

### 配置说明

- **HDFS**：无需特殊配置，使用系统默认的Hadoop配置
- **YARN**：无需特殊配置，使用系统默认的Hadoop配置
- **MapReduce**：无需特殊配置，使用系统默认的Hadoop配置
- **Hive**：无需特殊配置，使用系统默认的Hive配置
- **Spark**：无需特殊配置，使用系统默认的Spark配置
- **Kafka**：可通过KAFKA_HOME环境变量指定Kafka安装目录
- **HBase**：可通过HBASE_HOME环境变量指定HBase安装目录
- **ZooKeeper**：可通过ZOOKEEPER_HOME环境变量指定ZooKeeper安装目录

### 权限设置

确保脚本具有执行权限：

```bash
chmod +x */*.sh
```

## 使用方法

### 执行诊断脚本

```bash
# 执行HDFS诊断
./hdfs/hdfs-block-diagnose.sh

# 执行YARN诊断
./yarn/yarn-diagnose.sh

# 执行MapReduce诊断
./mapreduce/mapreduce-diagnose.sh

# 执行Hive诊断
./hive/hive-diagnose.sh

# 执行Spark诊断
./spark/spark-diagnose.sh

# 执行Kafka诊断
./kafka/kafka-diagnose.sh

# 执行HBase诊断
./hbase/hbase-diagnose.sh

# 执行ZooKeeper诊断
./zookeeper/zookeeper-diagnose.sh
```

### 执行修复脚本

```bash
# 执行HDFS修复
./hdfs/hdfs-block-repair.sh

# 执行HDFS自动修复
./hdfs/hdfs-block-auto-repair.sh
```

### 定期执行

可以通过crontab设置定期执行诊断脚本：

```bash
# 编辑crontab
crontab -e

# 添加定时任务（每天凌晨2点执行HDFS诊断）
0 2 * * * /path/to/big-data/hdfs/hdfs-block-diagnose.sh

# 添加定时任务（每周日凌晨3点执行所有组件诊断）
0 3 * * 0 /path/to/big-data/hdfs/hdfs-block-diagnose.sh && /path/to/big-data/yarn/yarn-diagnose.sh && /path/to/big-data/hive/hive-diagnose.sh
```

## 日志管理

- **日志文件路径**：默认在各组件脚本所在目录的上一层目录的 `logs/` 子目录下，文件名格式为 `组件名-diagnose.log` 或 `组件名-repair.log`
- **报告文件路径**：默认在各组件脚本所在目录的上一层目录的 `report/` 子目录下，文件名包含时间戳
- **自动创建目录**：脚本会自动创建logs和report目录，无需手动创建
- **日志清理**：建议定期清理日志文件，避免磁盘空间占用过大

## 版本兼容性

| 组件 | Hadoop 2.x | Hadoop 3.x | 备注 |
|-----|------------|------------|------|
| HDFS | ✅ | ✅ | 完全支持 |
| YARN | ✅ | ✅ | 完全支持 |
| MapReduce | ✅ | ✅ | 完全支持 |
| Hive | ✅ | ✅ | 完全支持 |
| Spark | ✅ | ✅ | 完全支持 |
| Kafka | ✅ | ✅ | 完全支持 |
| HBase | ✅ | ✅ | 完全支持 |
| ZooKeeper | ✅ | ✅ | 完全支持 |

## 最佳实践

1. **日常巡检**：每周执行一次所有组件的诊断脚本
2. **问题定位**：当某个组件出现问题时，执行相应的诊断脚本
3. **定期修复**：每月执行一次HDFS修复脚本，确保数据完整性
4. **监控集成**：将诊断结果集成到监控系统，实时了解组件状态
5. **日志分析**：定期分析诊断日志，发现潜在问题

## 故障排查

### 常见问题

1. **脚本执行失败**：检查组件是否安装正确，环境变量是否配置
2. **权限不足**：确保执行脚本的用户有相应组件的管理权限
3. **命令未找到**：检查组件的命令是否添加到系统PATH中
4. **连接失败**：检查网络连接和组件服务是否正常运行

### 解决方案

- **检查环境变量**：确保HADOOP_HOME、JAVA_HOME等环境变量已正确设置
- **检查服务状态**：使用 `jps` 命令检查组件进程是否正在运行
- **检查网络连接**：确保组件之间的网络连接正常
- **查看详细日志**：检查组件的详细日志，了解具体错误信息
- **参考官方文档**：对于复杂问题，参考相应组件的官方文档

## 扩展与定制

### 添加新组件

1. **创建目录**：为新组件创建相应的目录
2. **创建脚本**：参考现有脚本的格式，创建新组件的诊断脚本
3. **添加到README**：在本README.md文件中添加新组件的信息

### 自定义脚本

- **修改日志路径**：修改脚本中的 `LOG_FILE` 变量
- **修改报告路径**：修改脚本中的 `REPORT_FILE` 变量
- **添加新功能**：根据需要添加新的诊断或修复功能

## 版本历史

| 版本 | 日期 | 变更内容 |
|------|------|--------|
| v1.0 | 2025-02-25 | 初始版本，发布HDFS、YARN、MapReduce、Hive、Spark、Kafka、HBase和ZooKeeper的诊断脚本 |

## 贡献

欢迎提交Issue和Pull Request，共同完善大数据组件管理工具集。

## 许可证

本项目采用MIT许可证。