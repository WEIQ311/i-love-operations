#!/bin/bash

# Kafka诊断脚本
# 功能：检查Kafka集群状态和主题
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

LOG_FILE="$LOG_DIR/kafka-diagnose.log"
REPORT_FILE="$REPORT_DIR/kafka-report-$(date +%Y%m%d_%H%M%S).txt"
KAFKA_HOME=${KAFKA_HOME:-/opt/kafka}

log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_message "========== Kafka诊断开始 =========="
log_message "报告文件：$REPORT_FILE"
log_message "Kafka_HOME: $KAFKA_HOME"

log_message "\n1. 检查Kafka版本..."
$KAFKA_HOME/bin/kafka-topics.sh --version 2>&1 | tee -a "$REPORT_FILE"

log_message "\n2. 检查Kafka服务状态..."
# 检查Kafka broker进程
KAFKA_BROKER_PID=$(jps 2>&1 | grep Kafka | awk '{print $1}')
if [ -n "$KAFKA_BROKER_PID" ]; then
    log_message "Kafka broker正在运行，PID: $KAFKA_BROKER_PID"
else
    log_message "警告：Kafka broker未运行"
fi

log_message "\n3. 检查Kafka主题..."
$KAFKA_HOME/bin/kafka-topics.sh --list --bootstrap-server localhost:9092 2>&1 | tee -a "$REPORT_FILE"

log_message "\n4. 检查Kafka broker状态..."
$KAFKA_HOME/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092 2>&1 | head -20 | tee -a "$REPORT_FILE"

log_message "\n5. 检查Kafka消费者组..."
$KAFKA_HOME/bin/kafka-consumer-groups.sh --list --bootstrap-server localhost:9092 2>&1 | tee -a "$REPORT_FILE"

log_message "\n6. 检查Kafka配置..."
if [ -f "$KAFKA_HOME/config/server.properties" ]; then
    log_message "Kafka配置文件存在，检查关键配置..."
    grep -E "broker.id|listeners|log.dirs|zookeeper.connect" "$KAFKA_HOME/config/server.properties" 2>&1 | tee -a "$REPORT_FILE"
else
    log_message "警告：Kafka配置文件不存在"
fi

log_message "\n7. 检查ZooKeeper连接..."
# 检查ZooKeeper状态
if command -v zkCli.sh &> /dev/null; then
    zkCli.sh -server localhost:2181 ls /brokers/ids 2>&1 | tee -a "$REPORT_FILE"
elif [ -f "$KAFKA_HOME/bin/zookeeper-shell.sh" ]; then
    $KAFKA_HOME/bin/zookeeper-shell.sh localhost:2181 ls /brokers/ids 2>&1 | tee -a "$REPORT_FILE"
else
    log_message "警告：无法检查ZooKeeper连接"
fi

log_message "\n8. 测试Kafka生产和消费..."
# 创建测试主题
$KAFKA_HOME/bin/kafka-topics.sh --create --topic test-diagnostic --partitions 1 --replication-factor 1 --bootstrap-server localhost:9092 2>&1 | tee -a "$REPORT_FILE"

# 生产测试消息
log_message "生产测试消息..."
echo "Hello Kafka" | $KAFKA_HOME/bin/kafka-console-producer.sh --broker-list localhost:9092 --topic test-diagnostic 2>&1 | tee -a "$REPORT_FILE"

# 消费测试消息
log_message "消费测试消息..."
$KAFKA_HOME/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic test-diagnostic --from-beginning --max-messages 1 2>&1 | tee -a "$REPORT_FILE"

# 删除测试主题
$KAFKA_HOME/bin/kafka-topics.sh --delete --topic test-diagnostic --bootstrap-server localhost:9092 2>&1 | tee -a "$REPORT_FILE"

log_message "\n========== Kafka诊断完成 =========="
log_message "详细报告已保存到：$REPORT_FILE"
log_message "日志文件：$LOG_FILE"

echo -e "\n请查看报告文件获取详细信息："
echo "  cat $REPORT_FILE"
