#!/bin/bash

# HDFS块快速修复脚本（自动模式）
# 功能：自动修复HDFS集群中缺失或损坏的块
# 作者：系统管理员
# 日期：2025-02-25
# 注意：此脚本会自动移动损坏文件到/lost+found

# 获取脚本所在目录
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
# 上一层目录
PARENT_DIR=$(dirname "$SCRIPT_DIR")
LOG_DIR="$PARENT_DIR/logs"
REPORT_DIR="$PARENT_DIR/report"

# 创建目录
mkdir -p "$LOG_DIR" "$REPORT_DIR"

LOG_FILE="$LOG_DIR/hdfs-block-auto-repair.log"

log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_message "========== HDFS块自动修复开始 =========="

log_message "步骤1: 检查当前状态..."
BEFORE_STATUS=$(hdfs fsck / 2>&1 | grep -E "Missing blocks|CORRUPT FILES")
log_message "修复前状态:\n$BEFORE_STATUS"

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

log_message "\n步骤3: 等待块恢复..."
sleep 30

log_message "\n步骤4: 再次检查状态..."
AFTER_STATUS=$(hdfs fsck / 2>&1 | grep -E "Missing blocks|CORRUPT FILES")
log_message "等待后状态:\n$AFTER_STATUS"

AFTER_MISSING=$(hdfs fsck / 2>&1 | grep "Missing blocks:" | awk '{print $3}')

if [ "$AFTER_MISSING" != "0" ] && [ -n "$AFTER_MISSING" ]; then
    log_message "\n步骤5: 仍有缺失块，尝试移动损坏文件..."
    hdfs fsck / -move 2>&1 | tee -a "$LOG_FILE"
    sleep 10
    
    log_message "\n步骤6: 最终检查..."
    FINAL_STATUS=$(hdfs fsck / 2>&1 | grep -E "Missing blocks|CORRUPT FILES")
    log_message "最终状态:\n$FINAL_STATUS"
fi

log_message "\n步骤7: 生成完整报告..."
hdfs fsck / 2>&1 | tee -a "$LOG_FILE"

log_message "\n========== HDFS块自动修复完成 =========="
log_message "日志文件: $LOG_FILE"
