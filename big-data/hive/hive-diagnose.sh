#!/bin/bash

# Hive诊断脚本
# 功能：检查Hive服务状态和元数据
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

LOG_FILE="$LOG_DIR/hive-diagnose.log"
REPORT_FILE="$REPORT_DIR/hive-report-$(date +%Y%m%d_%H%M%S).txt"

log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_message "========== Hive诊断开始 =========="
log_message "报告文件：$REPORT_FILE"

log_message "\n1. 检查Hive版本..."
hive --version 2>&1 | tee -a "$REPORT_FILE"

log_message "\n2. 检查Hive服务状态..."
# 检查Hive Metastore服务
METASTORE_PID=$(jps 2>&1 | grep RunJar | grep metastore | awk '{print $1}')
if [ -n "$METASTORE_PID" ]; then
    log_message "Hive Metastore服务正在运行，PID: $METASTORE_PID"
else
    log_message "警告：Hive Metastore服务未运行"
fi

# 检查HiveServer2服务
HIVESERVER2_PID=$(jps 2>&1 | grep RunJar | grep hiveserver2 | awk '{print $1}')
if [ -n "$HIVESERVER2_PID" ]; then
    log_message "HiveServer2服务正在运行，PID: $HIVESERVER2_PID"
else
    log_message "警告：HiveServer2服务未运行"
fi

log_message "\n3. 检查Hive元数据连接..."
hive -e "SHOW DATABASES;" 2>&1 | tee -a "$REPORT_FILE"

log_message "\n4. 检查Hive表状态..."
hive -e "SHOW TABLES IN default;" 2>&1 | tee -a "$REPORT_FILE"

log_message "\n5. 检查Hive配置..."
hive -e "SET;" 2>&1 | grep -E "hive.metastore|hive.server2|javax.jdo.option" | tee -a "$REPORT_FILE"

log_message "\n6. 检查Hive日志配置..."
hive -e "SET hive.log.dir;" 2>&1 | tee -a "$REPORT_FILE"

log_message "\n========== Hive诊断完成 =========="
log_message "详细报告已保存到：$REPORT_FILE"
log_message "日志文件：$LOG_FILE"

echo -e "\n请查看报告文件获取详细信息："
echo "  cat $REPORT_FILE"
