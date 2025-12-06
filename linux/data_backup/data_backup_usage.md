# 数据备份脚本使用说明

## 概述

这是一个经过优化的数据备份脚本，用于将/opt/docker-sh/app/目录备份到/data01/docker-sh/app/目录，并生成压缩文件。脚本支持日志管理、错误处理、磁盘空间检查和自动清理功能。

## 功能特性

- ✅ **日志管理**：详细的日志记录，包括备份过程的各个步骤
- ✅ **错误处理**：完善的错误检测和处理机制
- ✅ **磁盘空间检查**：自动检查备份目录的可用空间
- ✅ **自动清理**：自动删除旧备份文件，只保留最新的N个
- ✅ **备份完整性验证**：验证生成的备份文件是否完整
- ✅ **失败备份清理**：自动清理大小为0的失败备份文件

## 安装和配置

### 1. 基本安装

```bash
# 复制脚本到系统目录
sudo cp data_backup_optimized.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/data_backup_optimized.sh

# 创建必要的目录
sudo mkdir -p /opt/docker-sh/app/ /data01/docker-sh/app/ /data01/docker-sh/log/
```

### 2. 脚本配置

脚本的配置参数位于脚本内部，可直接编辑脚本进行修改：

```bash
# 编辑脚本
vi /usr/local/bin/data_backup_optimized.sh

# 修改以下配置参数
SOURCE_DIR="/opt/docker-sh/app/"           # 源目录
BACKUP_DIR="/data01/docker-sh/app/"          # 备份目录
LOG_FILE="/data01/docker-sh/log/app_backup.log"   # 日志文件
KEEP_BACKUPS=2                               # 保留的备份文件数量
MIN_FREE_SPACE_GB=300                        # 最小可用空间（GB）
```

## 使用方法

### 基本使用

```bash
# 直接执行脚本
sudo /usr/local/bin/data_backup_optimized.sh
```

### 定时任务配置

编辑crontab文件：

```bash
sudo crontab -e
```

添加以下行（每天凌晨2点执行）：

```bash
# 数据备份任务
0 2 * * * /usr/local/bin/data_backup_optimized.sh >/dev/null 2>&1
```

## 备份文件管理

### 备份文件命名

备份文件采用以下命名格式：
```
data_backup_YYYYMMDD_HHMMSS.tar.gz
```

例如：`data_backup_20250702_143022.tar.gz`

### 验证备份完整性

```bash
# 检查备份文件是否完整
tar -tzf /data01/docker-sh/app/data_backup_20250702_143022.tar.gz > /dev/null 2>&1

# 如果命令成功执行，说明文件完整
if [ $? -eq 0 ]; then
    echo "备份文件完整"
else
    echo "备份文件可能损坏"
fi
```

### 手动清理旧备份

```bash
# 手动清理旧备份（保留最新的3个）
find /data01/docker-sh/app/ -name "data_backup_*.tar.gz" -type f -printf '%T@ %p\n' | \
    sort -n | \
    head -n -3 | \
    cut -d' ' -f2- | \
    xargs rm -f
```

## 监控和故障排除

### 查看日志

```bash
# 查看最新日志
tail -f /data01/docker-sh/log/app_backup.log

# 查看错误日志
grep "ERROR" /data01/docker-sh/log/app_backup.log

# 查看最近的备份记录
grep "备份成功" /data01/docker-sh/log/app_backup.log
```

### 常见问题和解决方案

#### 1. 权限问题

**问题**：`错误：备份目录 /data01/docker-sh/app/ 不存在！`

**解决**：
```bash
sudo mkdir -p /data01/docker-sh/app/
sudo chown root:root /data01/docker-sh/app/
sudo chmod 755 /data01/docker-sh/app/
```

#### 2. 磁盘空间不足

**问题**：`错误：清理后空间仍不足，无法完成备份！`

**解决**：
```bash
# 检查磁盘空间
df -h /data01

# 手动清理更多旧备份
find /data01/docker-sh/app/ -name "data_backup_*.tar.gz" -type f -printf '%T@ %p\n' | \
    sort -n | \
    head -n -1 | \
    cut -d' ' -f2- | \
    xargs rm -f
```

#### 3. 源目录不存在

**问题**：`错误：源目录 /opt/docker-sh/app/ 不存在！`

**解决**：
```bash
# 检查源目录是否存在
ls -la /opt/docker-sh/app/

# 如果不存在，创建源目录
mkdir -p /opt/docker-sh/app/
```

## 脚本工作流程

1. **清理失败的备份文件**：自动删除大小为0的备份文件
2. **清理旧备份文件**：只保留最新的N个备份文件
3. **检查磁盘空间**：验证备份目录是否有足够的可用空间
4. **开始备份**：使用tar命令进行压缩备份
5. **验证备份完整性**：检查生成的备份文件是否完整
6. **最终清理**：确保备份文件数量不超过保留限制

## 性能优化

### 大文件备份优化

对于大型数据目录，可以考虑：

1. **使用pigz进行并行压缩**（如果可用）：
   ```bash
   # 修改脚本中的备份命令
   tar -I pigz -cf "${BACKUP_DIR}/${BACKUP_FILENAME}" "${SOURCE_DIR}"
   ```

2. **降低备份任务的优先级**：
   ```bash
   # 使用nice降低CPU优先级
   nice -n 19 /usr/local/bin/data_backup_optimized.sh
   
   # 使用ionice降低I/O优先级
   ionice -c 3 /usr/local/bin/data_backup_optimized.sh
   ```

## 恢复流程

### 完整恢复步骤

1. **找到最新的备份文件**：
   ```bash
   ls -lt /data01/docker-sh/app/data_backup_*.tar.gz | head -1
   ```

2. **解压备份文件**：
   ```bash
   # 解压到原始位置
sudo tar -xzf /data01/docker-sh/app/data_backup_20250702_143022.tar.gz -C /
   
   # 或者解压到临时位置
sudo tar -xzf /data01/docker-sh/app/data_backup_20250702_143022.tar.gz -C /tmp/
   ```

## 更新和维护

### 脚本更新

```bash
# 备份当前脚本
cp /usr/local/bin/data_backup_optimized.sh /usr/local/bin/data_backup_optimized.sh.bak

# 更新脚本（替换为新版本）
sudo cp data_backup_optimized.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/data_backup_optimized.sh
```

### 定期检查项

- [ ] 检查磁盘空间使用情况
- [ ] 验证备份文件完整性
- [ ] 检查日志文件内容
- [ ] 测试恢复流程
- [ ] 根据需要调整保留的备份数量

## 技术支持

如果遇到问题，请提供以下信息：

1. 操作系统版本：`lsb_release -a`
2. 脚本版本：查看脚本头部的版本信息
3. 错误日志：`grep ERROR /data01/docker-sh/log/app_backup.log`
4. 系统资源：`df -h /data01`

---

**最后更新**：2025-12-06  
**脚本版本**：2.0