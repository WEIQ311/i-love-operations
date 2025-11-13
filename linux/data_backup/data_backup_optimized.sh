#!/bin/bash

# 数据备份脚本 - 优化版
# 功能：将/opt/soft/data目录加密备份到/data01目录，并生成压缩文件
# 版本：2.0
# 作者：系统管理员
# 日期：2025-11-14

set -euo pipefail  # 严格模式：遇到错误立即退出，未定义变量报错，管道错误也退出

# 配置参数 - 建议使用环境变量或配置文件
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SOURCE_DIR="${SOURCE_DIR:-/opt/soft/data}"
readonly BACKUP_DIR="${BACKUP_DIR:-/data01}"
readonly LOG_FILE="${LOG_FILE:-/var/log/data_backup.log}"
readonly DATE=$(date +%Y%m%d_%H%M%S)
readonly BACKUP_FILENAME="data_backup_${DATE}.tar.gz"
readonly BACKUP_FILENAME_ENCRYPTED="data_backup_${DATE}.tar.gz.enc"
readonly RETENTION_DAYS="${RETENTION_DAYS:-7}"
readonly MAX_LOG_SIZE="${MAX_LOG_SIZE:-10485760}"  # 10MB

# 安全配置 - 优先从环境变量读取
ENCRYPTION_PASSWORD="${BACKUP_ENCRYPTION_PASSWORD:-}"
if [[ -z "$ENCRYPTION_PASSWORD" ]]; then
    echo "错误：未设置加密密码！请设置环境变量 BACKUP_ENCRYPTION_PASSWORD"
    echo "示例：export BACKUP_ENCRYPTION_PASSWORD='your_secure_password'"
    exit 1
fi

# 检查依赖命令
readonly REQUIRED_COMMANDS=("tar" "openssl" "find" "du" "date")
for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "错误：缺少必需的命令 '$cmd'"
        exit 1
    fi
done

# 日志函数 - 支持日志级别和日志轮转
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] [$level] $message"
    
    # 输出到控制台
    echo "$log_entry"
    
    # 输出到日志文件
    echo "$log_entry" >> "$LOG_FILE"
    
    # 检查日志文件大小，超过限制则轮转
    if [[ -f "$LOG_FILE" ]] && [[ $(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE" 2>/dev/null || echo 0) -gt "$MAX_LOG_SIZE" ]]; then
        mv "$LOG_FILE" "${LOG_FILE}.old"
        touch "$LOG_FILE"
        chmod 640 "$LOG_FILE"
    fi
}

# 错误处理函数
error_exit() {
    local message="$1"
    local exit_code="${2:-1}"
    log_message "ERROR" "$message"
    exit "$exit_code"
}

# 信号处理函数
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_message "ERROR" "脚本异常退出 (退出码: $exit_code)"
    fi
    # 清理临时文件
    if [[ -f "${BACKUP_DIR}/${BACKUP_FILENAME}" ]]; then
        rm -f "${BACKUP_DIR}/${BACKUP_FILENAME}"
        log_message "INFO" "清理临时文件: ${BACKUP_FILENAME}"
    fi
}

# 设置信号处理
trap cleanup EXIT INT TERM

# 检查目录和权限
check_prerequisites() {
    log_message "INFO" "开始检查前提条件..."
    
    # 检查源目录
    if [[ ! -d "$SOURCE_DIR" ]]; then
        error_exit "源目录不存在: $SOURCE_DIR"
    fi
    
    # 检查备份目录
    if [[ ! -d "$BACKUP_DIR" ]]; then
        error_exit "备份目录不存在: $BACKUP_DIR"
    fi
    
    # 检查写权限
    if [[ ! -w "$BACKUP_DIR" ]]; then
        error_exit "没有备份目录的写权限: $BACKUP_DIR"
    fi
    
    # 检查源目录是否为空
    if [[ -z "$(ls -A "$SOURCE_DIR" 2>/dev/null)" ]]; then
        log_message "WARN" "源目录为空: $SOURCE_DIR"
    fi
    
    # 检查磁盘空间（至少需要源目录大小的1.5倍）
    local source_size=$(du -sb "$SOURCE_DIR" 2>/dev/null | cut -f1 || echo 0)
    local available_space=$(df -B1 "$BACKUP_DIR" 2>/dev/null | awk 'NR==2 {print $4}' || echo 0)
    local required_space=$((source_size * 3))  # 考虑压缩和加密的空间需求
    
    if [[ $available_space -lt $required_space ]]; then
        log_message "WARN" "磁盘空间可能不足。需要约 $((required_space / 1024 / 1024))MB，可用 $((available_space / 1024 / 1024))MB"
    fi
    
    log_message "INFO" "前提条件检查完成"
}

# 备份函数
perform_backup() {
    log_message "INFO" "开始备份数据..."
    
    # 创建临时压缩文件
    log_message "INFO" "正在压缩数据..."
    if ! tar -czf "${BACKUP_DIR}/${BACKUP_FILENAME}" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")" 2>/dev/null; then
        error_exit "压缩失败"
    fi
    
    local compressed_size=$(stat -c%s "${BACKUP_DIR}/${BACKUP_FILENAME}" 2>/dev/null || stat -f%z "${BACKUP_DIR}/${BACKUP_FILENAME}" 2>/dev/null || echo 0)
    log_message "INFO" "压缩完成，压缩文件大小: $((compressed_size / 1024))KB"
    
    # 加密压缩文件
    log_message "INFO" "正在加密备份文件..."
    if ! openssl enc -aes-256-cbc -salt -in "${BACKUP_DIR}/${BACKUP_FILENAME}" -out "${BACKUP_DIR}/${BACKUP_FILENAME_ENCRYPTED}" -pass pass:"$ENCRYPTION_PASSWORD" 2>/dev/null; then
        error_exit "加密失败"
    fi
    
    # 删除原始压缩文件
    rm -f "${BACKUP_DIR}/${BACKUP_FILENAME}"
    
    local encrypted_size=$(stat -c%s "${BACKUP_DIR}/${BACKUP_FILENAME_ENCRYPTED}" 2>/dev/null || stat -f%z "${BACKUP_DIR}/${BACKUP_FILENAME_ENCRYPTED}" 2>/dev/null || echo 0)
    log_message "INFO" "加密完成，加密文件大小: $((encrypted_size / 1024))KB"
    log_message "INFO" "备份成功: ${BACKUP_FILENAME_ENCRYPTED}"
    
    # 设置文件权限
    chmod 640 "${BACKUP_DIR}/${BACKUP_FILENAME_ENCRYPTED}"
}

# 清理旧备份
cleanup_old_backups() {
    log_message "INFO" "清理超过 $RETENTION_DAYS 天的旧备份文件..."
    
    local deleted_count=0
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]]; then
            rm -f "$file"
            log_message "INFO" "删除旧备份: $(basename "$file")"
            ((deleted_count++))
        fi
    done < <(find "$BACKUP_DIR" -name "data_backup_*.tar.gz.enc" -type f -mtime +$RETENTION_DAYS -print0 2>/dev/null)
    
    if [[ $deleted_count -gt 0 ]]; then
        log_message "INFO" "共删除 $deleted_count 个旧备份文件"
    else
        log_message "INFO" "没有需要清理的旧备份文件"
    fi
}

# 主函数
main() {
    log_message "INFO" "=== 数据备份脚本开始执行 ==="
    log_message "INFO" "源目录: $SOURCE_DIR"
    log_message "INFO" "备份目录: $BACKUP_DIR"
    log_message "INFO" "保留天数: $RETENTION_DAYS"
    
    check_prerequisites
    perform_backup
    cleanup_old_backups
    
    log_message "INFO" "=== 数据备份脚本执行完成 ==="
    
    # 显示解密说明
    echo ""
    echo "备份文件已加密，解密方法："
    echo "openssl enc -aes-256-cbc -d -in ${BACKUP_DIR}/${BACKUP_FILENAME_ENCRYPTED} -out ${BACKUP_DIR}/decrypted_backup.tar.gz -pass pass:'***隐藏密码***'"
    echo "请将上述命令中的 ***隐藏密码*** 替换为您的实际密码"
    echo ""
}

# 执行主函数
main "$@"