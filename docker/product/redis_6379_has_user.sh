#!/bin/bash
# Redis启动脚本 - 支持用户名和密码认证

# 配置参数
REDIS_USER="admin"
REDIS_PASSWORD="rJXoWdOKZE9G"
REDIS_PORT=6388
REDIS_CONTAINER_NAME="redis_${REDIS_PORT}"
REDIS_IMAGE="redis:latest"
CONFIG_DIR="$(pwd)/redis_config"
ACL_CONFIG_FILE="${CONFIG_DIR}/redis-acl.conf"

# 创建配置目录
mkdir -p "${CONFIG_DIR}"

# 创建Redis ACL配置文件 - 使用变量替换但只保留有效配置行
# 先构建配置内容到变量中，然后写入文件以确保变量正确替换
ACL_CONFIG="user ${REDIS_USER} on >${REDIS_PASSWORD} ~* &* +@all"
# 写入配置文件，确保只包含有效的用户配置行
echo "${ACL_CONFIG}" > "${ACL_CONFIG_FILE}"

# 停止并移除已存在的容器
if [ $(docker ps -aq -f name=${REDIS_CONTAINER_NAME}) ]; then
    echo "停止并移除已存在的容器: ${REDIS_CONTAINER_NAME}"
    docker stop ${REDIS_CONTAINER_NAME} > /dev/null
    docker rm ${REDIS_CONTAINER_NAME} > /dev/null
fi

# 启动Redis容器
echo "启动Redis容器: ${REDIS_CONTAINER_NAME} (端口: ${REDIS_PORT})"
docker run \
    --name ${REDIS_CONTAINER_NAME} \
    -e TZ=Asia/Shanghai \
    -v "${ACL_CONFIG_FILE}:/usr/local/etc/redis/redis-acl.conf" \
    -p ${REDIS_PORT}:6379 \
    -d \
    --restart=always \
    ${REDIS_IMAGE} redis-server --aclfile /usr/local/etc/redis/redis-acl.conf

# 验证启动是否成功
sleep 2
if [ $(docker ps -q -f name=${REDIS_CONTAINER_NAME}) ]; then
    echo "Redis容器启动成功!"
    echo "连接信息: 端口=${REDIS_PORT}, 用户名=${REDIS_USER}, 密码=${REDIS_PASSWORD}"
    echo "连接命令示例: redis-cli -h localhost -p ${REDIS_PORT} -u ${REDIS_USER} -a ${REDIS_PASSWORD}"
else
    echo "Redis容器启动失败! 请查看日志: docker logs ${REDIS_CONTAINER_NAME}"
fi
