#!/bin/bash

# ZooKeeper诊断脚本
# 功能：检查ZooKeeper集群状态和连接
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

LOG_FILE="$LOG_DIR/zookeeper-diagnose.log"
REPORT_FILE="$REPORT_DIR/zookeeper-report-$(date +%Y%m%d_%H%M%S).txt"
ZOOKEEPER_HOME=${ZOOKEEPER_HOME:-/opt/zookeeper}

log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_message "========== ZooKeeper诊断开始 =========="
log_message "报告文件：$REPORT_FILE"
log_message "ZOOKEEPER_HOME: $ZOOKEEPER_HOME"

log_message "\n1. 检查ZooKeeper版本..."
$ZOOKEEPER_HOME/bin/zkServer.sh version 2>&1 | tee -a "$REPORT_FILE"

log_message "\n2. 检查ZooKeeper服务状态..."
$ZOOKEEPER_HOME/bin/zkServer.sh status 2>&1 | tee -a "$REPORT_FILE"

# 检查ZooKeeper进程
ZOOKEEPER_PID=$(jps 2>&1 | grep QuorumPeerMain | awk '{print $1}')
if [ -n "$ZOOKEEPER_PID" ]; then
    log_message "ZooKeeper正在运行，PID: $ZOOKEEPER_PID"
else
    log_message "警告：ZooKeeper未运行"
fi

log_message "\n3. 检查ZooKeeper配置..."
if [ -f "$ZOOKEEPER_HOME/conf/zoo.cfg" ]; then
    log_message "ZooKeeper配置文件存在，检查关键配置..."
    grep -E "dataDir|clientPort|server." "$ZOOKEEPER_HOME/conf/zoo.cfg" 2>&1 | tee -a "$REPORT_FILE"
else
    log_message "警告：ZooKeeper配置文件不存在"
fi

log_message "\n4. 检查ZooKeeper连接..."
$ZOOKEEPER_HOME/bin/zkCli.sh -server localhost:2181 ls / 2>&1 | tee -a "$REPORT_FILE"

log_message "\n5. 检查ZooKeeper四字命令..."
# 检查ZooKeeper四字命令响应
if command -v nc &> /dev/null; then
    log_message "检查ZooKeeper四字命令响应..."
    echo stat | nc localhost 2181 2>&1 | tee -a "$REPORT_FILE"
    echo ruok | nc localhost 2181 2>&1 | tee -a "$REPORT_FILE"
    echo conf | nc localhost 2181 2>&1 | head -20 | tee -a "$REPORT_FILE"
    echo cons | nc localhost 2181 2>&1 | head -20 | tee -a "$REPORT_FILE"
else
    log_message "警告：无法检查ZooKeeper四字命令，nc命令未安装"
fi

log_message "\n6. 检查ZooKeeper日志..."
if [ -d "$ZOOKEEPER_HOME/logs" ]; then
    log_message "ZooKeeper日志目录存在，检查最近的日志..."
    ls -la "$ZOOKEEPER_HOME/logs" | tail -10 | tee -a "$REPORT_FILE"
else
    log_message "警告：ZooKeeper日志目录不存在"
fi

log_message "\n7. 检查ZooKeeper数据目录..."
if [ -f "$ZOOKEEPER_HOME/conf/zoo.cfg" ]; then
    DATA_DIR=$(grep dataDir "$ZOOKEEPER_HOME/conf/zoo.cfg" | awk -F= '{print $2}')
    if [ -d "$DATA_DIR" ]; then
        log_message "ZooKeeper数据目录存在: $DATA_DIR"
        ls -la "$DATA_DIR" | tail -10 | tee -a "$REPORT_FILE"
    else
        log_message "警告：ZooKeeper数据目录不存在: $DATA_DIR"
    fi
fi

log_message "\n========== ZooKeeper诊断完成 =========="
log_message "详细报告已保存到：$REPORT_FILE"
log_message "日志文件：$LOG_FILE"

echo -e "\n请查看报告文件获取详细信息："
echo "  cat $REPORT_FILE"
