#!/bin/bash

# HBase诊断脚本
# 功能：检查HBase集群状态和表
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

LOG_FILE="$LOG_DIR/hbase-diagnose.log"
REPORT_FILE="$REPORT_DIR/hbase-report-$(date +%Y%m%d_%H%M%S).txt"
HBASE_HOME=${HBASE_HOME:-/opt/hbase}

log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_message "========== HBase诊断开始 =========="
log_message "报告文件：$REPORT_FILE"
log_message "HBASE_HOME: $HBASE_HOME"

log_message "\n1. 检查HBase版本..."
$HBASE_HOME/bin/hbase version 2>&1 | tee -a "$REPORT_FILE"

log_message "\n2. 检查HBase服务状态..."
# 检查HMaster进程
HMASTER_PID=$(jps 2>&1 | grep HMaster | awk '{print $1}')
if [ -n "$HMASTER_PID" ]; then
    log_message "HMaster正在运行，PID: $HMASTER_PID"
else
    log_message "警告：HMaster未运行"
fi

# 检查HRegionServer进程
HREGIONSERVER_PID=$(jps 2>&1 | grep HRegionServer | awk '{print $1}')
if [ -n "$HREGIONSERVER_PID" ]; then
    log_message "HRegionServer正在运行，PID: $HREGIONSERVER_PID"
else
    log_message "警告：HRegionServer未运行"
fi

log_message "\n3. 检查HBase表..."
$HBASE_HOME/bin/hbase shell -c "list" 2>&1 | tee -a "$REPORT_FILE"

log_message "\n4. 检查HBase集群状态..."
$HBASE_HOME/bin/hbase shell -c "status 'simple'" 2>&1 | tee -a "$REPORT_FILE"

log_message "\n5. 检查HBase配置..."
if [ -f "$HBASE_HOME/conf/hbase-site.xml" ]; then
    log_message "HBase配置文件存在，检查关键配置..."
    grep -E "hbase.rootdir|hbase.zookeeper.quorum|hbase.cluster.distributed" "$HBASE_HOME/conf/hbase-site.xml" 2>&1 | tee -a "$REPORT_FILE"
else
    log_message "警告：HBase配置文件不存在"
fi

log_message "\n6. 检查HBase日志配置..."
if [ -f "$HBASE_HOME/conf/log4j.properties" ]; then
    log_message "HBase日志配置文件存在"
    grep -E "log4j.appender.DRFA.File" "$HBASE_HOME/conf/log4j.properties" 2>&1 | tee -a "$REPORT_FILE"
else
    log_message "警告：HBase日志配置文件不存在"
fi

log_message "\n7. 检查ZooKeeper连接..."
$HBASE_HOME/bin/hbase zkcli ls /hbase 2>&1 | tee -a "$REPORT_FILE"

log_message "\n8. 测试HBase操作..."
# 创建测试表
$HBASE_HOME/bin/hbase shell -c "create 'test_diagnostic', 'cf'" 2>&1 | tee -a "$REPORT_FILE"

# 插入测试数据
$HBASE_HOME/bin/hbase shell -c "put 'test_diagnostic', 'row1', 'cf:col1', 'value1'" 2>&1 | tee -a "$REPORT_FILE"

# 读取测试数据
$HBASE_HOME/bin/hbase shell -c "get 'test_diagnostic', 'row1'" 2>&1 | tee -a "$REPORT_FILE"

# 删除测试表
$HBASE_HOME/bin/hbase shell -c "disable 'test_diagnostic'" 2>&1 | tee -a "$REPORT_FILE"
$HBASE_HOME/bin/hbase shell -c "drop 'test_diagnostic'" 2>&1 | tee -a "$REPORT_FILE"

log_message "\n========== HBase诊断完成 =========="
log_message "详细报告已保存到：$REPORT_FILE"
log_message "日志文件：$LOG_FILE"

echo -e "\n请查看报告文件获取详细信息："
echo "  cat $REPORT_FILE"
