#!/bin/bash
pwd=`pwd`
docker run --name redis_6379  -e TZ=Asia/Shanghai \
-p 6379:6379 -d --restart=always redis:7.2.3
