#!/bin/bash
pwd=`pwd`
# 设置Redis密码
REDIS_PASSWORD="vSmVYk*4i{;U"
REDIS_PORT=6379
docker run --name redis_$REDIS_PORT  -e TZ=Asia/Shanghai \
-p $REDIS_PORT:6379 -d --restart=always \
redis:latest redis-server --requirepass $REDIS_PASSWORD