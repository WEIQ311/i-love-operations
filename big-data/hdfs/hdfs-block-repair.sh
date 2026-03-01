#!/bin/bash

# HDFS块修复脚本
# 功能：修复HDFS集群中缺失或损坏的块
# 作者：系统管理员
# 日期：2025-02-25
# 警告：此脚本会删除损坏的文件，请谨慎使用！

# 获取脚本所在目录
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
# 上一层目录
PARENT_DIR=$(dirname "$SCRIPT_DIR")
LOG_DIR="$PARENT_DIR/logs"
REPORT_DIR="$PARENT_DIR/report"

# 创建目录
mkdir -p "$LOG_DIR" "$REPORT_DIR"

LOG_FILE="$LOG_DIR/hdfs-block-repair.log"
BACKUP_DIR="$REPORT_DIR/hdfs-corrupt-backup-$(date +%Y%m%d_%H%M%S)"

log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_message "========== HDFS块修复开始 =========="

log_message "步骤1: 检查当前块状态..."
BEFORE_MISSING=$(hdfs fsck / 2>&1 | grep "Missing blocks:" | awk '{print $3}')
BEFORE_CORRUPT=$(hdfs fsck / 2>&1 | grep "CORRUPT FILES:" | awk '{print $3}')
log_message "修复前 - 缺失块数: $BEFORE_MISSING, 损坏文件数: $BEFORE_CORRUPT"

log_message "\n步骤2: 触发块报告..."
# 尝试获取第一个DataNode的主机和端口
DATANODE=$(hdfs dfsadmin -report 2>&1 | grep -A 1 "Live datanodes" | grep -E "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+")
if [ -n "$DATANODE" ]; then
    # 提取主机和端口
    DATANODE_ADDR=$(echo "$DATANODE" | awk '{print $2}')
    log_message "获取到DataNode地址: $DATANODE_ADDR"
    hdfs dfsadmin -triggerBlockReport "$DATANODE_ADDR" 2>&1 | tee -a "$LOG_FILE"
else
    log_message "警告: 无法获取DataNode地址，跳过触发块报告"
fi
sleep 10

log_message "\n步骤3: 检查安全模式..."
SAFE_MODE=$(hdfs dfsadmin -safemode get 2>&1)
log_message "安全模式状态: $SAFE_MODE"

if [[ "$SAFE_MODE" == *"ON"* ]]; then
    log_message "集群处于安全模式，等待自动退出..."
    hdfs dfsadmin -safemode wait
    log_message "已退出安全模式"
fi

log_message "\n步骤4: 查找损坏的文件..."
mkdir -p "$BACKUP_DIR"
hdfs fsck / -list-corruptfileblocks 2>&1 > "$BACKUP_DIR/corrupt_files.txt"
cat "$BACKUP_DIR/corrupt_files.txt"

CORRUPT_COUNT=$(grep -c "^/user\|^/tmp\|^/hbase\|^/hive" "$BACKUP_DIR/corrupt_files.txt" 2>/dev/null || echo "0")
log_message "发现 $CORRUPT_COUNT 个损坏的文件"

if [ "$CORRUPT_COUNT" -gt 0 ]; then
    log_message "\n步骤5: 处理损坏的文件..."
    log_message "备份损坏文件列表到: $BACKUP_DIR/corrupt_files.txt"
    
    echo -e "\n警告：发现损坏的文件！"
    echo "请选择处理方式："
    echo "1. 移动损坏文件到/lost+found（推荐）"
    echo "2. 删除损坏文件（危险操作）"
    echo "3. 仅查看，不处理"
    echo "4. 退出"
    read -p "请输入选项 (1-4): " choice
    
    case $choice in
        1)
            log_message "选择：移动损坏文件到/lost+found"
            hdfs fsck / -move 2>&1 | tee -a "$LOG_FILE"
            ;;
        2)
            log_message "选择：删除损坏文件"
            read -p "确认删除损坏文件吗？(yes/no): " confirm
            if [ "$confirm" == "yes" ]; then
                hdfs fsck / -delete 2>&1 | tee -a "$LOG_FILE"
                log_message "已删除损坏文件"
            else
                log_message "取消删除操作"
            fi
            ;;
        3)
            log_message "选择：仅查看，不处理"
            cat "$BACKUP_DIR/corrupt_files.txt"
            ;;
        4)
            log_message "退出修复"
            exit 0
            ;;
        *)
            log_message "无效选项，退出"
            exit 1
            ;;
    esac
fi

log_message "\n步骤6: 触发块恢复..."
# 尝试获取第一个DataNode的主机和端口
DATANODE=$(hdfs dfsadmin -report 2>&1 | grep -A 1 "Live datanodes" | grep -E "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+")
if [ -n "$DATANODE" ]; then
    # 提取主机和端口
    DATANODE_ADDR=$(echo "$DATANODE" | awk '{print $2}')
    log_message "获取到DataNode地址: $DATANODE_ADDR"
    hdfs dfsadmin -triggerBlockReport "$DATANODE_ADDR" 2>&1 | tee -a "$LOG_FILE"
else
    log_message "警告: 无法获取DataNode地址，跳过触发块报告"
fi
sleep 15

log_message "\n步骤7: 检查修复后的状态..."
AFTER_MISSING=$(hdfs fsck / 2>&1 | grep "Missing blocks:" | awk '{print $3}')
AFTER_CORRUPT=$(hdfs fsck / 2>&1 | grep "CORRUPT FILES:" | awk '{print $3}')
log_message "修复后 - 缺失块数: $AFTER_MISSING, 损坏文件数: $AFTER_CORRUPT"

log_message "\n步骤8: 检查集群健康状态..."
hdfs fsck / 2>&1 | grep -E "Total blocks|Missing blocks|CORRUPT|UNDER REPLICATED" | tee -a "$LOG_FILE"

log_message "\n========== HDFS块修复完成 =========="
log_message "修复前缺失块: $BEFORE_MISSING -> 修复后: $AFTER_MISSING"
log_message "修复前损坏文件: $BEFORE_CORRUPT -> 修复后: $AFTER_CORRUPT"
log_message "日志文件: $LOG_FILE"
log_message "备份目录: $BACKUP_DIR"

if [ "$AFTER_MISSING" == "0" ] && [ "$AFTER_CORRUPT" == "0" ]; then
    log_message "\n✓ 所有块问题已修复！"
    exit 0
else
    log_message "\n✗ 仍有块问题存在，建议手动检查"
    exit 1
fi
