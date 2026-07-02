#!/bin/bash

# 数据备份脚本（优化版）
# 功能：将/opt/docker-sh/app/目录备份到/data01目录，并生成压缩文件
# 优化：备份前清理旧文件、检查磁盘空间、验证备份完整性
# 作者：系统管理员
# 日期：2025-07-02
# 更新：2025-12-06

# 配置参数
SOURCE_DIR="/opt/docker-sh/app/"
BACKUP_DIR="/data01/docker-sh/app/"
LOG_FILE="/data01/docker-sh/log/app_backup.log"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILENAME="data_backup_${DATE}.tar.gz"
# 保留的备份文件数量（只保留最新的N个备份）
KEEP_BACKUPS=2
# 最小可用空间（GB），如果可用空间小于此值，将清理更多旧备份
MIN_FREE_SPACE_GB=300

# 日志函数
log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 获取目录的可用空间（GB）
get_free_space_gb() {
    local dir="$1"
    df -BG "$dir" | awk 'NR==2 {print $4}' | sed 's/G//'
}

# 获取目录大小（GB）
get_dir_size_gb() {
    local dir="$1"
    local size_bytes=""
    
    # 方法1：尝试使用 du -sb（最准确，获取字节数）
    size_bytes=$(du -sb "$dir" 2>/dev/null | awk '{print $1}')
    
    # 方法2：如果方法1失败，尝试使用 du -sk（获取KB）
    if [ -z "$size_bytes" ] || [ "$size_bytes" = "0" ]; then
        local size_kb=$(du -sk "$dir" 2>/dev/null | awk '{print $1}')
        if [ -n "$size_kb" ] && [ "$size_kb" -gt 0 ]; then
            # KB转换为字节，再转换为GB
            size_bytes=$((size_kb * 1024))
        fi
    fi
    
    # 方法3：如果前两种方法都失败，尝试使用 du -sm（获取MB）
    if [ -z "$size_bytes" ] || [ "$size_bytes" = "0" ]; then
        local size_mb=$(du -sm "$dir" 2>/dev/null | awk '{print $1}')
        if [ -n "$size_mb" ] && [ "$size_mb" -gt 0 ]; then
            # MB转换为字节，再转换为GB
            size_bytes=$((size_mb * 1024 * 1024))
        fi
    fi
    
    if [ -n "$size_bytes" ] && [ "$size_bytes" -gt 0 ]; then
        # 转换为GB（字节 / 1024 / 1024 / 1024）
        echo $((size_bytes / 1024 / 1024 / 1024))
    else
        echo "0"
    fi
}

# 检查目录是否存在
if [ ! -d "$SOURCE_DIR" ]; then
    log_message "错误：源目录 $SOURCE_DIR 不存在！"
    exit 1
fi

if [ ! -d "$BACKUP_DIR" ]; then
    log_message "错误：备份目录 $BACKUP_DIR 不存在！"
    exit 1
fi

# 创建日志文件目录
mkdir -p $(dirname "$LOG_FILE")

log_message "========== 备份任务开始 =========="

# 步骤1：清理失败的备份文件（大小为0的文件）
log_message "步骤1：清理失败的备份文件..."
FAILED_BACKUPS=$(find "$BACKUP_DIR" -name "data_backup_*.tar.gz" -type f -size 0)
if [ -n "$FAILED_BACKUPS" ]; then
    echo "$FAILED_BACKUPS" | while read -r file; do
        log_message "删除失败的备份文件：$(basename "$file")"
        rm -f "$file"
    done
else
    log_message "未发现失败的备份文件"
fi

# 步骤2：清理旧备份文件（只保留最新的N个）
log_message "步骤2：清理旧备份文件（保留最新 ${KEEP_BACKUPS} 个）..."
BACKUP_COUNT=$(find "$BACKUP_DIR" -name "data_backup_*.tar.gz" -type f | wc -l)
if [ "$BACKUP_COUNT" -gt "$KEEP_BACKUPS" ]; then
    # 按修改时间排序，删除最旧的文件
    find "$BACKUP_DIR" -name "data_backup_*.tar.gz" -type f -printf '%T@ %p\n' | \
        sort -n | \
        head -n -$KEEP_BACKUPS | \
        cut -d' ' -f2- | \
        while read -r file; do
            FILE_SIZE=$(du -h "$file" | cut -f1)
            log_message "删除旧备份：$(basename "$file") (大小: ${FILE_SIZE})"
            rm -f "$file"
        done
    log_message "已清理旧备份，当前保留 ${KEEP_BACKUPS} 个最新备份"
else
    log_message "当前备份数量：${BACKUP_COUNT}，无需清理"
fi

# 步骤3：检查磁盘空间
log_message "步骤3：检查磁盘空间..."
FREE_SPACE=$(get_free_space_gb "$BACKUP_DIR")
SOURCE_SIZE=$(get_dir_size_gb "$SOURCE_DIR")

log_message "备份目录可用空间：${FREE_SPACE} GB"

# 检查是否能获取源目录大小
if [ -n "$SOURCE_SIZE" ] && [ "$SOURCE_SIZE" != "0" ]; then
    log_message "源目录大小：${SOURCE_SIZE} GB"
    
    # 估算需要的空间（源目录大小的1.2倍，考虑压缩和临时文件）
    ESTIMATED_NEED=$((SOURCE_SIZE * 120 / 100))
    log_message "估算所需空间：${ESTIMATED_NEED} GB"
    
    if [ "$FREE_SPACE" -lt "$ESTIMATED_NEED" ]; then
        log_message "警告：可用空间 ${FREE_SPACE} GB 可能不足，估算需要 ${ESTIMATED_NEED} GB"
    else
        log_message "空间检查：可用空间充足"
    fi
else
    log_message "警告：无法获取源目录大小，跳过空间估算检查"
    ESTIMATED_NEED=0
fi

# 检查最小可用空间阈值
if [ "$FREE_SPACE" -lt "$MIN_FREE_SPACE_GB" ]; then
    log_message "警告：可用空间 ${FREE_SPACE} GB 低于最小阈值 ${MIN_FREE_SPACE_GB} GB，尝试清理更多旧备份..."
    # 只保留最新的1个备份
    find "$BACKUP_DIR" -name "data_backup_*.tar.gz" -type f -printf '%T@ %p\n' | \
        sort -n | \
        head -n -1 | \
        cut -d' ' -f2- | \
        while read -r file; do
            FILE_SIZE=$(du -h "$file" | cut -f1)
            log_message "紧急清理备份：$(basename "$file") (大小: ${FILE_SIZE})"
            rm -f "$file"
        done
    
    # 重新检查空间
    FREE_SPACE=$(get_free_space_gb "$BACKUP_DIR")
    log_message "清理后可用空间：${FREE_SPACE} GB"
    
    # 如果已估算所需空间，检查是否足够
    if [ "$ESTIMATED_NEED" -gt 0 ] && [ "$FREE_SPACE" -lt "$ESTIMATED_NEED" ]; then
        log_message "错误：清理后空间仍不足，无法完成备份！"
        exit 1
    fi
fi

# 步骤4：开始备份
log_message "步骤4：开始备份数据..."
log_message "源目录：${SOURCE_DIR}"
log_message "备份文件：${BACKUP_FILENAME}"

# 使用tar命令进行压缩备份，显示进度
tar -czf "${BACKUP_DIR}/${BACKUP_FILENAME}" "${SOURCE_DIR}" 2>&1 | while IFS= read -r line; do
    log_message "$line"
done

TAR_EXIT_CODE=${PIPESTATUS[0]}

# 步骤5：验证备份是否成功
if [ $TAR_EXIT_CODE -eq 0 ]; then
    # 检查备份文件是否存在且大小不为0
    if [ -f "${BACKUP_DIR}/${BACKUP_FILENAME}" ] && [ -s "${BACKUP_DIR}/${BACKUP_FILENAME}" ]; then
        BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_FILENAME}" | cut -f1)
        BACKUP_SIZE_BYTES=$(stat -c%s "${BACKUP_DIR}/${BACKUP_FILENAME}")
        log_message "备份成功：${BACKUP_FILENAME}"
        log_message "备份文件大小：${BACKUP_SIZE} (${BACKUP_SIZE_BYTES} 字节)"
        
        # 验证tar文件完整性
        if tar -tzf "${BACKUP_DIR}/${BACKUP_FILENAME}" > /dev/null 2>&1; then
            log_message "备份文件完整性验证：通过"
        else
            log_message "警告：备份文件完整性验证失败！"
        fi
    else
        log_message "错误：备份文件不存在或大小为0，备份失败！"
        rm -f "${BACKUP_DIR}/${BACKUP_FILENAME}"
        exit 1
    fi
else
    log_message "错误：tar命令执行失败，退出码：${TAR_EXIT_CODE}"
    # 删除可能创建的不完整备份文件
    rm -f "${BACKUP_DIR}/${BACKUP_FILENAME}"
    exit 1
fi

# 步骤6：最终清理（确保不超过保留数量）
log_message "步骤6：最终清理检查..."
CURRENT_COUNT=$(find "$BACKUP_DIR" -name "data_backup_*.tar.gz" -type f | wc -l)
if [ "$CURRENT_COUNT" -gt "$KEEP_BACKUPS" ]; then
    find "$BACKUP_DIR" -name "data_backup_*.tar.gz" -type f -printf '%T@ %p\n' | \
        sort -n | \
        head -n -$KEEP_BACKUPS | \
        cut -d' ' -f2- | \
        while read -r file; do
            FILE_SIZE=$(du -h "$file" | cut -f1)
            log_message "最终清理：$(basename "$file") (大小: ${FILE_SIZE})"
            rm -f "$file"
        done
fi

FINAL_FREE_SPACE=$(get_free_space_gb "$BACKUP_DIR")
log_message "备份后可用空间：${FINAL_FREE_SPACE} GB"
log_message "========== 备份任务完成 =========="
exit 0
