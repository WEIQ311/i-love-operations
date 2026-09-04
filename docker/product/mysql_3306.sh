#!/bin/bash
# MySQL启动脚本 - 优化版

# 配置参数 - 集中管理便于修改
MYSQL_PORT=3306
MYSQL_CONTAINER_NAME="mysql_${MYSQL_PORT}"
MYSQL_ROOT_PASSWORD="VZF0Vl0Z90T6"
MYSQL_VERSION="8.4.4"
CURRENT_DIR="$(pwd)"
DATA_DIR="${CURRENT_DIR}/data/mysql_data_${MYSQL_PORT}"

# 修复变量引用语法，避免可能的解析错误
export MYSQL_CONTAINER_NAME
export MYSQL_ROOT_PASSWORD
export MYSQL_PORT
export MYSQL_VERSION
export CURRENT_DIR
export DATA_DIR

# 创建数据目录（如果不存在）
mkdir -p "${DATA_DIR}" || {
    echo "错误：无法创建数据目录 ${DATA_DIR}，请检查权限！"
    exit 1
}

# 停止并移除已存在的同名容器
if [ "$(docker ps -aq -f name=${MYSQL_CONTAINER_NAME})" != "" ]; then
    echo "停止并移除已存在的容器: ${MYSQL_CONTAINER_NAME}"
    docker stop ${MYSQL_CONTAINER_NAME} > /dev/null
    docker rm ${MYSQL_CONTAINER_NAME} > /dev/null
fi

# 启动MySQL容器
echo "启动MySQL容器: ${MYSQL_CONTAINER_NAME} (端口: ${MYSQL_PORT})"
docker run \
    --name "${MYSQL_CONTAINER_NAME}" \
    -e "MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}" \
    -e "TZ=Asia/Shanghai" \
    -e "MYSQL_ROOT_HOST=%" \
    -v "${DATA_DIR}:/var/lib/mysql" \
    -p "${MYSQL_PORT}:3306" \
    -d \
    --restart=always \
    mysql:${MYSQL_VERSION} \
    --lower_case_table_names=1 \
    --collation_server=utf8_general_ci \
    --max_connections=5000 \
    --event_scheduler=ON \
    --sql_mode= \
    --log_timestamps=SYSTEM \
    --character-set-server=utf8 \
    --log_bin_trust_function_creators=1 \
    --transaction_isolation=READ-COMMITTED \
    --max_allowed_packet=104857600 \
    --server-id=127001 \
    --log-bin=/var/lib/mysql/mysql-bin

# 验证启动是否成功
sleep 3
if [ "$(docker ps -q -f name=${MYSQL_CONTAINER_NAME})" != "" ]; then
    echo "MySQL容器启动成功!"
    echo "连接信息: 端口=${MYSQL_PORT}, 用户名=root"
    echo "连接命令示例: mysql -h localhost -P ${MYSQL_PORT} -u root -p"
    echo "可以使用以下命令查看容器日志: docker logs ${MYSQL_CONTAINER_NAME}"
else
    echo "MySQL容器启动失败! 请查看日志: docker logs ${MYSQL_CONTAINER_NAME}"
    exit 1
fi
