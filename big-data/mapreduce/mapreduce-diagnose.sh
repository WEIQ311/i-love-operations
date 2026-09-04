#!/bin/bash

# MapReduce诊断脚本
# 功能：检查MapReduce作业状态和历史记录
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

LOG_FILE="$LOG_DIR/mapreduce-diagnose.log"
REPORT_FILE="$REPORT_DIR/mapreduce-report-$(date +%Y%m%d_%H%M%S).txt"

log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_message "========== MapReduce诊断开始 =========="
log_message "报告文件：$REPORT_FILE"

log_message "\n1. 检查MapReduce历史服务器状态..."
# 检查历史服务器进程
HISTORY_SERVER_PID=$(jps 2>&1 | grep JobHistoryServer | awk '{print $1}')
if [ -n "$HISTORY_SERVER_PID" ]; then
    log_message "MapReduce历史服务器正在运行，PID: $HISTORY_SERVER_PID"
else
    log_message "警告：MapReduce历史服务器未运行"
fi

log_message "\n2. 检查MapReduce配置..."
yarn --config $HADOOP_CONF_DIR classpath 2>&1 | head -10 | tee -a "$REPORT_FILE"

log_message "\n3. 检查最近的作业历史..."
yarn application -list -appStates FINISHED -count 10 2>&1 | tee -a "$REPORT_FILE"

log_message "\n4. 检查作业计数器..."
# 获取最近完成的作业ID
RECENT_JOB=$(yarn application -list -appStates FINISHED -count 1 2>&1 | grep application_ | awk '{print $1}')
if [ -n "$RECENT_JOB" ]; then
    log_message "获取作业 $RECENT_JOB 的计数器..."
    yarn application -status "$RECENT_JOB" 2>&1 | tee -a "$REPORT_FILE"
else
    log_message "没有找到最近完成的作业"
fi

log_message "\n5. 检查MapReduce队列状态..."
yarn queue -status default 2>&1 | tee -a "$REPORT_FILE"

log_message "\n========== MapReduce诊断完成 =========="
log_message "详细报告已保存到：$REPORT_FILE"
log_message "日志文件：$LOG_FILE"

echo -e "\n请查看报告文件获取详细信息："
echo "  cat $REPORT_FILE"
