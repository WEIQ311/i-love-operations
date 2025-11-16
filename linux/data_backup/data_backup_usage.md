# 数据备份脚本使用说明

## 概述

这是一个经过优化的数据备份脚本，支持加密备份、日志管理、错误处理和自动清理功能。

## 功能特性

- ✅ **加密备份**：使用AES-256-CBC算法加密备份文件
- ✅ **日志管理**：支持日志级别、日志轮转和大小控制
- ✅ **错误处理**：完善的错误检测和处理机制
- ✅ **安全检查**：目录权限、磁盘空间、依赖检查
- ✅ **自动清理**：自动删除超过保留期限的旧备份
- ✅ **环境配置**：支持通过环境变量进行配置

## 安装和配置

### 1. 基本安装

```bash
# 复制脚本到系统目录
sudo cp data_backup_optimized.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/data_backup_optimized.sh

# 创建必要的目录
sudo mkdir -p /opt/soft/data /data01 /var/log
```

### 2. 环境变量配置

建议在`/etc/profile.d/backup.sh`中设置环境变量：

```bash
# 备份配置
export SOURCE_DIR="/opt/soft/data"           # 源目录
export BACKUP_DIR="/data01"                  # 备份目录
export LOG_FILE="/var/log/data_backup.log"   # 日志文件
export RETENTION_DAYS=7                      # 保留天数
export MAX_LOG_SIZE=10485760                 # 日志文件最大大小(字节)

# 安全配置（重要！）
export BACKUP_ENCRYPTION_PASSWORD="your_strong_password_here"
```

### 3. 密码安全建议

**重要**：不要在脚本中硬编码密码！

推荐的密码管理方式：

1. **环境变量**（推荐）：
   ```bash
   export BACKUP_ENCRYPTION_PASSWORD="$(openssl rand -base64 32)"
   ```

2. **配置文件**（权限600）：
   ```bash
   # /etc/backup.conf (权限设置为600)
   BACKUP_ENCRYPTION_PASSWORD="your_password"
   ```

3. **密码管理器**：
   ```bash
   export BACKUP_ENCRYPTION_PASSWORD="$(pass show backup/password)"
   ```

## 使用方法

### 基本使用

```bash
# 直接执行脚本
sudo /usr/local/bin/data_backup_optimized.sh

# 或者设置环境变量后执行
export BACKUP_ENCRYPTION_PASSWORD="your_password"
sudo -E /usr/local/bin/data_backup_optimized.sh
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

### 高级配置

支持的环境变量：

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| SOURCE_DIR | 源目录路径 | /opt/soft/data |
| BACKUP_DIR | 备份目录路径 | /data01 |
| LOG_FILE | 日志文件路径 | /var/log/data_backup.log |
| RETENTION_DAYS | 备份保留天数 | 7 |
| MAX_LOG_SIZE | 日志文件最大大小 | 10485760 (10MB) |
| BACKUP_ENCRYPTION_PASSWORD | 加密密码 | 必需设置 |

## 备份文件管理

### 备份文件命名

备份文件采用以下命名格式：
```
data_backup_YYYYMMDD_HHMMSS.tar.gz.enc
```

例如：`data_backup_20240702_143022.tar.gz.enc`

### 解密备份文件

```bash
# 解密备份文件
openssl enc -aes-256-cbc -d -in data_backup_20240702_143022.tar.gz.enc -out decrypted_backup.tar.gz -pass pass:'your_password'

# 解压解密后的文件
tar -xzf decrypted_backup.tar.gz
```

### 验证备份完整性

```bash
# 检查加密文件是否完整
openssl enc -aes-256-cbc -d -in backup.tar.gz.enc -pass pass:'password' | tar -tzf - >/dev/null 2>&1

# 如果命令成功执行，说明文件完整
if [ $? -eq 0 ]; then
    echo "备份文件完整"
else
    echo "备份文件可能损坏"
fi
```

## 监控和故障排除

### 查看日志

```bash
# 查看最新日志
tail -f /var/log/data_backup.log

# 查看错误日志
grep "ERROR" /var/log/data_backup.log

# 查看最近7天的备份记录
grep "备份成功" /var/log/data_backup.log | tail -7
```

### 常见问题和解决方案

#### 1. 权限问题

**问题**：`错误：没有备份目录的写权限`

**解决**：
```bash
sudo chown root:root /data01
sudo chmod 755 /data01
```

#### 2. 磁盘空间不足

**问题**：`磁盘空间可能不足`

**解决**：
```bash
# 检查磁盘空间
df -h /data01

# 手动清理旧备份
find /data01 -name "data_backup_*.tar.gz.enc" -mtime +3 -delete
```

#### 3. 缺少依赖

**问题**：`错误：缺少必需的命令 'openssl'`

**解决**：
```bash
# Ubuntu/Debian
sudo apt-get install openssl coreutils

# CentOS/RHEL
sudo yum install openssl coreutils
```

#### 4. 密码问题

**问题**：`错误：未设置加密密码！`

**解决**：
```bash
# 设置环境变量
export BACKUP_ENCRYPTION_PASSWORD="your_secure_password"

# 验证设置
echo $BACKUP_ENCRYPTION_PASSWORD
```

## 性能优化

### 大文件备份优化

对于大型数据目录，可以考虑：

1. **使用pigz进行并行压缩**（如果可用）：
   ```bash
   # 修改备份命令
   tar -I pigz -cf backup.tar.gz /source/dir
   ```

2. **分卷备份**：
   ```bash
   # 分卷为100MB的文件
   tar -czf - /source/dir | split -b 100m - backup.tar.gz.part.
   ```

### 备份时间优化

1. **使用nice降低CPU优先级**：
   ```bash
   nice -n 19 /usr/local/bin/data_backup_optimized.sh
   ```

2. **使用ionice降低I/O优先级**：
   ```bash
   ionice -c 3 /usr/local/bin/data_backup_optimized.sh
   ```

## 安全最佳实践

1. **密码管理**
   - 使用强密码（至少16位，包含大小写字母、数字、特殊字符）
   - 定期更换密码
   - 不要在版本控制系统中存储密码

2. **文件权限**
   - 备份脚本权限：755
   - 配置文件权限：600
   - 备份文件权限：640

3. **网络安全**
   - 如果备份到远程位置，使用安全的传输协议（如scp、rsync over ssh）
   - 考虑使用VPN或专用网络进行备份传输

4. **定期测试**
   - 定期验证备份文件的完整性
   - 定期测试恢复过程
   - 记录恢复时间和步骤

## 恢复流程

### 完整恢复步骤

1. **找到最新的备份文件**：
   ```bash
   ls -lt /data01/data_backup_*.tar.gz.enc | head -1
   ```

2. **解密备份文件**：
   ```bash
   openssl enc -aes-256-cbc -d -in backup.tar.gz.enc -out backup.tar.gz -pass pass:'password'
   ```

3. **验证解密文件**：
   ```bash
   tar -tzf backup.tar.gz >/dev/null 2>&1 && echo "文件有效" || echo "文件损坏"
   ```

4. **解压到指定位置**：
   ```bash
   # 解压到原始位置
   sudo tar -xzf backup.tar.gz -C /opt/soft/
   
   # 或者解压到临时位置
   sudo tar -xzf backup.tar.gz -C /tmp/
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
- [ ] 检查日志文件大小
- [ ] 测试恢复流程
- [ ] 更新密码（建议每3-6个月）
- [ ] 检查定时任务状态

## 技术支持

如果遇到问题，请提供以下信息：

1. 操作系统版本：`lsb_release -a`
2. 脚本版本：查看脚本头部的版本信息
3. 错误日志：`grep ERROR /var/log/data_backup.log`
4. 系统资源：`df -h` 和 `free -h`
5. 相关配置文件内容

---

**最后更新**：2025年11月14日  
**脚本版本**：2.0