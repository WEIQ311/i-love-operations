#!/bin/bash

# HDFS块诊断脚本
# 功能：诊断HDFS集群中的块问题
# 作者：系统管理员
# 日期：2025-02-25

# 获取脚本所在目录
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
# 上一层目录
PARENT_DIR=$(dirname "$SCRIPT_DIR")
LOG_DIR="$PARENT_DIR/logs"
REPORT_DIR="$PARENT_DIR/report"

# 创建目录
mkdir -p "$LOG_DIR" "$REPORT_DIR"

LOG_FILE="$LOG_DIR/hdfs-block-diagnose.log"
REPORT_FILE="$REPORT_DIR/hdfs-block-report-$(date +%Y%m%d_%H%M%S).txt"

log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_message "========== HDFS块诊断开始 =========="
log_message "报告文件：$REPORT_FILE"

log_message "\n1. 检查HDFS集群状态..."
hdfs dfsadmin -report > "$REPORT_FILE" 2>&1
cat "$REPORT_FILE"

log_message "\n2. 检查缺失和损坏的块..."
hdfs fsck / 2>&1 | tee -a "$REPORT_FILE" | grep -E "Total blocks|Missing blocks|CORRUPT|UNDER REPLICATED"

log_message "\n3. 列出损坏的文件..."
hdfs fsck / -list-corruptfileblocks 2>&1 | tee -a "$REPORT_FILE"

log_message "\n4. 检查DataNode状态..."
hdfs dfsadmin -report 2>&1 | grep -A 5 "Live datanodes" | tee -a "$REPORT_FILE"

log_message "\n5. 检查安全模式状态..."
hdfs dfsadmin -safemode get 2>&1 | tee -a "$REPORT_FILE"

log_message "\n========== 诊断完成 =========="
log_message "详细报告已保存到：$REPORT_FILE"
log_message "日志文件：$LOG_FILE"

echo -e "\n请查看报告文件获取详细信息："
echo "  cat $REPORT_FILE"
