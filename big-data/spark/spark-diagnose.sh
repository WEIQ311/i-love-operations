#!/bin/bash

# Spark诊断脚本
# 功能：检查Spark集群状态和作业
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

LOG_FILE="$LOG_DIR/spark-diagnose.log"
REPORT_FILE="$REPORT_DIR/spark-report-$(date +%Y%m%d_%H%M%S).txt"

log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_message "========== Spark诊断开始 =========="
log_message "报告文件：$REPORT_FILE"

log_message "\n1. 检查Spark版本..."
spark-submit --version 2>&1 | tee -a "$REPORT_FILE"

log_message "\n2. 检查Spark服务状态..."
# 检查Spark Master服务
SPARK_MASTER_PID=$(jps 2>&1 | grep Master | awk '{print $1}')
if [ -n "$SPARK_MASTER_PID" ]; then
    log_message "Spark Master服务正在运行，PID: $SPARK_MASTER_PID"
else
    log_message "警告：Spark Master服务未运行"
fi

# 检查Spark Worker服务
SPARK_WORKER_PID=$(jps 2>&1 | grep Worker | awk '{print $1}')
if [ -n "$SPARK_WORKER_PID" ]; then
    log_message "Spark Worker服务正在运行，PID: $SPARK_WORKER_PID"
else
    log_message "警告：Spark Worker服务未运行"
fi

log_message "\n3. 检查Spark配置..."
spark-submit --help 2>&1 | head -30 | tee -a "$REPORT_FILE"

log_message "\n4. 检查Spark作业历史..."
# 检查Spark历史服务器
SPARK_HISTORY_PID=$(jps 2>&1 | grep HistoryServer | awk '{print $1}')
if [ -n "$SPARK_HISTORY_PID" ]; then
    log_message "Spark历史服务器正在运行，PID: $SPARK_HISTORY_PID"
else
    log_message "警告：Spark历史服务器未运行"
fi

log_message "\n5. 检查Spark资源使用情况..."
# 尝试访问Spark Master Web UI获取信息
if command -v curl &> /dev/null; then
    SPARK_MASTER_UI="http://localhost:8080"
    log_message "尝试获取Spark Master UI信息..."
    curl -s "$SPARK_MASTER_UI" | grep -E "Workers|Cores|Memory" | head -10 | tee -a "$REPORT_FILE"
fi

log_message "\n6. 运行Spark示例作业..."
# 运行一个简单的Spark示例作业
log_message "运行Spark Pi示例作业..."
spark-submit --class org.apache.spark.examples.SparkPi --master local[2] $SPARK_HOME/examples/jars/spark-examples_*.jar 10 2>&1 | tee -a "$REPORT_FILE"

log_message "\n========== Spark诊断完成 =========="
log_message "详细报告已保存到：$REPORT_FILE"
log_message "日志文件：$LOG_FILE"

echo -e "\n请查看报告文件获取详细信息："
echo "  cat $REPORT_FILE"
