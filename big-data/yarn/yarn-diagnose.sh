#!/bin/bash

# YARN诊断脚本
# 功能：检查YARN集群状态和资源使用情况
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

LOG_FILE="$LOG_DIR/yarn-diagnose.log"
REPORT_FILE="$REPORT_DIR/yarn-report-$(date +%Y%m%d_%H%M%S).txt"

log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_message "========== YARN诊断开始 =========="
log_message "报告文件：$REPORT_FILE"

log_message "\n1. 检查YARN集群状态..."
yarn node -list 2>&1 | tee -a "$REPORT_FILE"

log_message "\n2. 检查YARN资源使用情况..."
yarn top 2>&1 | head -30 | tee -a "$REPORT_FILE"

log_message "\n3. 检查应用程序状态..."
yarn application -list -appStates ALL 2>&1 | tee -a "$REPORT_FILE"

log_message "\n4. 检查ResourceManager状态..."
yarn rmadmin -getServiceState rm1 2>&1 | tee -a "$REPORT_FILE"

log_message "\n5. 检查NodeManager状态..."
yarn node -list -all 2>&1 | tee -a "$REPORT_FILE"

log_message "\n6. 检查YARN配置..."
yarn --config $HADOOP_CONF_DIR version 2>&1 | tee -a "$REPORT_FILE"

log_message "\n========== YARN诊断完成 =========="
log_message "详细报告已保存到：$REPORT_FILE"
log_message "日志文件：$LOG_FILE"

echo -e "\n请查看报告文件获取详细信息："
echo "  cat $REPORT_FILE"
