# HDFS 块管理工具模块

## 模块简介

本模块提供了一套用于HDFS（Hadoop分布式文件系统）块管理的工具脚本，主要用于诊断和修复HDFS集群中的块问题，包括缺失块、损坏文件等。这些工具适用于Hadoop 2.x版本及以上。

## 支持的Hadoop版本

- **Hadoop 2.x**：完全支持
- **Hadoop 3.x**：完全支持
- **Hadoop 1.x**：基本支持（部分命令可能需要调整）

## 工具脚本列表

| 脚本名称 | 功能描述 | 适用场景 |
|---------|---------|--------|
| `hdfs-block-diagnose.sh` | HDFS块诊断脚本，检查集群状态和块问题 | 日常巡检、问题定位 |
| `hdfs-block-repair.sh` | HDFS块修复脚本，修复缺失或损坏的块 | 块问题修复、数据恢复 |
| `hdfs-block-auto-repair.sh` | HDFS块自动修复脚本，自动处理块问题 | 自动化运维、定期执行 |

## 功能特性

- **全面的诊断**：检查HDFS集群状态、DataNode状态、块状态等
- **智能修复**：支持自动修复缺失块和损坏文件
- **多种处理方式**：提供移动损坏文件到/lost+found或删除损坏文件的选项
- **详细的日志**：记录完整的操作过程和结果
- **自动备份**：备份损坏文件列表，便于后续分析
- **安全模式处理**：自动检测和处理安全模式
- **块报告触发**：主动触发块报告，加速块状态更新

## 目录结构

```
hdfs/
├── hdfs-block-diagnose.sh   # HDFS块诊断脚本
├── hdfs-block-repair.sh      # HDFS块修复脚本
├── hdfs-block-auto-repair.sh # HDFS块自动修复脚本
└── README.md                 # 本说明文档
```

## 安装与配置

### 前置条件

1. **Hadoop环境**：已安装并配置好Hadoop集群
2. **权限**：执行脚本的用户需要有HDFS管理权限
3. **路径配置**：`hdfs`命令已添加到系统PATH中

### 配置说明

脚本中的主要配置参数：

| 配置项 | 描述 | 默认值 | 可修改位置 |
|-------|------|-------|----------|
| LOG_FILE | 日志文件路径 | /var/log/hdfs-block-*.log | 脚本开头 |
| BACKUP_DIR | 备份目录路径 | /tmp/hdfs-corrupt-backup-$(date +%Y%m%d_%H%M%S) | 脚本开头 |
| 等待时间 | 块报告和恢复等待时间 | 10-30秒 | 脚本中的sleep命令 |

### 权限设置

确保脚本具有执行权限：

```bash
chmod +x hdfs-block-*.sh
```

## 使用方法

### 1. 诊断HDFS块状态

使用`hdfs-block-diagnose.sh`脚本进行诊断：

```bash
# 执行诊断
./hdfs-block-diagnose.sh

# 查看诊断报告
cat /tmp/hdfs-block-report-*.txt

# 查看日志
cat /var/log/hdfs-block-diagnose.log
```

### 2. 手动修复HDFS块

使用`hdfs-block-repair.sh`脚本进行修复：

```bash
# 执行修复
./hdfs-block-repair.sh

# 根据提示选择处理方式：
# 1. 移动损坏文件到/lost+found（推荐）
# 2. 删除损坏文件（危险操作）
# 3. 仅查看，不处理
# 4. 退出

# 查看日志
cat /var/log/hdfs-block-repair.log
```

### 3. 自动修复HDFS块

使用`hdfs-block-auto-repair.sh`脚本进行自动修复：

```bash
# 执行自动修复
./hdfs-block-auto-repair.sh

# 查看日志
cat /var/log/hdfs-block-auto-repair.log
```

### 4. 定期执行

可以通过crontab设置定期执行自动修复脚本：

```bash
# 编辑crontab
crontab -e

# 添加定时任务（每天凌晨2点执行）
0 2 * * * /path/to/hdfs-block-auto-repair.sh
```

## 执行流程

### 诊断脚本执行流程

1. 检查HDFS集群状态
2. 检查缺失和损坏的块
3. 列出损坏的文件
4. 检查DataNode状态
5. 检查安全模式状态
6. 生成详细报告

### 修复脚本执行流程

1. 检查当前块状态
2. 触发块报告
3. 检查安全模式
4. 查找损坏的文件
5. 处理损坏的文件（根据用户选择）
6. 再次触发块报告
7. 检查修复后的状态
8. 检查集群健康状态

### 自动修复脚本执行流程

1. 检查当前状态
2. 触发块报告
3. 等待块恢复
4. 再次检查状态
5. 如有缺失块，尝试移动损坏文件
6. 最终检查
7. 生成完整报告

## 注意事项

1. **权限要求**：执行脚本的用户需要有HDFS管理权限
2. **数据安全**：修复过程中可能会删除损坏的文件，请谨慎操作
3. **集群影响**：执行块修复可能会对集群性能产生一定影响，建议在低峰期执行
4. **日志管理**：定期清理日志文件，避免磁盘空间占用过大
5. **备份重要数据**：在执行修复前，建议备份重要数据
6. **监控执行**：首次执行时建议监控执行过程，确保脚本正常运行
7. **版本兼容性**：确保使用的Hadoop版本支持脚本中的命令

## 常见问题处理

### 1. 脚本执行失败

**原因**：Hadoop环境未配置或权限不足
**解决方法**：
- 检查Hadoop环境变量配置
- 确保用户有HDFS管理权限
- 验证`hdfs`命令是否可正常执行

### 2. 块修复后仍有问题

**原因**：可能存在永久性损坏的文件或网络问题
**解决方法**：
- 检查网络连接和DataNode状态
- 考虑从备份恢复数据
- 对于重要数据，联系Hadoop支持团队

### 3. 安全模式无法退出

**原因**：集群启动时自动进入安全模式，可能由于DataNode未全部启动
**解决方法**：
- 检查所有DataNode是否正常启动
- 等待集群自动退出安全模式
- 如必要，可手动强制退出安全模式（谨慎使用）

### 4. 日志文件过大

**原因**：频繁执行脚本导致日志累积
**解决方法**：
- 定期清理日志文件
- 调整日志级别或日志保存策略

## 扩展与定制

### 1. 自定义日志路径

修改脚本中的`LOG_FILE`变量：

```bash
# 修改前
LOG_FILE="/var/log/hdfs-block-repair.log"

# 修改后
LOG_FILE="/path/to/custom/log/hdfs-block-repair.log"
```

### 2. 调整等待时间

根据集群大小和网络状况调整等待时间：

```bash
# 修改前
sleep 10

# 修改后（适用于大型集群）
sleep 30
```

### 3. 添加邮件通知

在脚本执行完成后添加邮件通知功能：

```bash
# 在脚本末尾添加
if [ "$AFTER_MISSING" == "0" ]; then
    echo "HDFS块修复成功" | mail -s "HDFS块修复完成" admin@example.com
else
    echo "HDFS块修复后仍有问题" | mail -s "HDFS块修复警告" admin@example.com
fi
```

### 4. 集成监控系统

将脚本执行结果集成到监控系统：

```bash
# 执行脚本并将结果写入监控系统
./hdfs-block-auto-repair.sh > /tmp/hdfs-repair-result.txt

# 解析结果并发送到监控系统
python send_to_monitor.py /tmp/hdfs-repair-result.txt
```

## 示例输出

### 诊断脚本示例输出

```
[2025-02-25 10:00:00] ========== HDFS块诊断开始 ==========
[2025-02-25 10:00:00] 报告文件：/tmp/hdfs-block-report-20250225_100000.txt

[2025-02-25 10:00:00] 1. 检查HDFS集群状态...
Configured Capacity: 107374182400 (100 GB)
Present Capacity: 85899345920 (80 GB)
DFS Remaining: 76357353472 (71 GB)
DFS Used: 9542007808 (9 GB)
DFS Used%: 11.11%
Under replicated blocks: 0
Blocks with corrupt replicas: 0
Missing blocks: 0
Missing blocks (with replication factor 1): 0

[2025-02-25 10:00:05] 2. 检查缺失和损坏的块...
Total blocks (validated): 10000 (avg. block size 102400 B)
Missing blocks: 0
CORRUPT FILES: 0
UNDER REPLICATED BLOCKS: 0

[2025-02-25 10:00:10] 3. 列出损坏的文件...

[2025-02-25 10:00:10] 4. 检查DataNode状态...
Live datanodes (3):
Name: 192.168.1.101:50010 (datanode1)
Hostname: datanode1
Decommission Status : Normal
Configured Capacity: 35791394133 (33.33 GB)
DFS Used: 3180669269 (2.96 GB)
Non DFS Used: 3579139413 (3.33 GB)
DFS Remaining: 29031585451 (27.04 GB)
DFS Used%: 8.89%
DFS Remaining%: 81.11%
Configured Cache Capacity: 0 (0 B)
Cache Used: 0 (0 B)
Cache Remaining: 0 (0 B)
Cache Used%: 100.00%
Cache Remaining%: 0.00%
Xceivers: 1024
Last contact: Fri Feb 25 10:00:00 CST 2025
...

[2025-02-25 10:00:15] 5. 检查安全模式状态...
Safe mode is OFF

[2025-02-25 10:00:15] ========== 诊断完成 ==========
[2025-02-25 10:00:15] 详细报告已保存到：/tmp/hdfs-block-report-20250225_100000.txt
[2025-02-25 10:00:15] 日志文件：/var/log/hdfs-block-diagnose.log

请查看报告文件获取详细信息：
  cat /tmp/hdfs-block-report-20250225_100000.txt
```

### 修复脚本示例输出

```
[2025-02-25 10:30:00] ========== HDFS块修复开始 ==========
[2025-02-25 10:30:00] 步骤1: 检查当前块状态...
[2025-02-25 10:30:05] 修复前 - 缺失块数: 5, 损坏文件数: 3

[2025-02-25 10:30:05] 步骤2: 触发块报告...
[2025-02-25 10:30:15] 步骤3: 检查安全模式...
[2025-02-25 10:30:15] 安全模式状态: Safe mode is OFF

[2025-02-25 10:30:15] 步骤4: 查找损坏的文件...
[2025-02-25 10:30:20] 发现 3 个损坏的文件

警告：发现损坏的文件！
请选择处理方式：
1. 移动损坏文件到/lost+found（推荐）
2. 删除损坏文件（危险操作）
3. 仅查看，不处理
4. 退出
请输入选项 (1-4): 1
[2025-02-25 10:30:30] 选择：移动损坏文件到/lost+found

[2025-02-25 10:30:40] 步骤5: 处理损坏的文件...
[2025-02-25 10:30:40] 备份损坏文件列表到: /tmp/hdfs-corrupt-backup-20250225_103000/corrupt_files.txt

[2025-02-25 10:30:50] 步骤6: 触发块报告...
[2025-02-25 10:31:00] 步骤7: 检查修复后的状态...
[2025-02-25 10:31:05] 修复后 - 缺失块数: 0, 损坏文件数: 0

[2025-02-25 10:31:05] 步骤8: 检查集群健康状态...
Total blocks (validated): 10000 (avg. block size 102400 B)
Missing blocks: 0
CORRUPT FILES: 0
UNDER REPLICATED BLOCKS: 0

[2025-02-25 10:31:05] ========== HDFS块修复完成 ==========
[2025-02-25 10:31:05] 修复前缺失块: 5 -> 修复后: 0
[2025-02-25 10:31:05] 修复前损坏文件: 3 -> 修复后: 0
[2025-02-25 10:31:05] 日志文件: /var/log/hdfs-block-repair.log
[2025-02-25 10:31:05] 备份目录: /tmp/hdfs-corrupt-backup-20250225_103000

✓ 所有块问题已修复！
```

## 最佳实践

### 1. 日常运维

- **定期诊断**：每周执行一次`hdfs-block-diagnose.sh`进行健康检查
- **自动修复**：每月执行一次`hdfs-block-auto-repair.sh`进行预防性修复
- **监控集成**：将诊断结果集成到监控系统，实时了解集群状态

### 2. 故障处理

- **快速定位**：使用`hdfs-block-diagnose.sh`快速定位块问题
- **谨慎修复**：对于重要数据，使用`hdfs-block-repair.sh`并选择移动到/lost+found
- **验证结果**：修复后再次执行诊断脚本，验证问题是否彻底解决

### 3. 大规模集群

- **分批处理**：对于大型集群，考虑分批执行修复操作
- **调整参数**：增加等待时间，确保块报告和恢复有足够时间完成
- **优化执行时间**：选择集群负载较低的时段执行修复操作

## 版本历史

| 版本 | 日期 | 变更内容 |
|------|------|--------|
| v1.0 | 2025-02-25 | 初始版本，发布三个核心脚本 |
| v1.1 | 2025-03-10 | 优化日志记录，增加错误处理 |
| v1.2 | 2025-04-01 | 改进安全模式处理，增加邮件通知选项 |

## 贡献

欢迎提交Issue和Pull Request，共同完善HDFS块管理工具。

## 许可证

本项目采用MIT许可证。