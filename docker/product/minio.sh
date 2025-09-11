#!/bin/bash
echo '启动minio'
MINIO_PORT=9000
docker run -p ${MINIO_PORT}:9000 -p 9001:9001 --name minio_$MINIO_PORT -d --restart=always -e "MINIO_ACCESS_KEY=admin" -e "MINIO_SECRET_KEY=Admin#$%^KON" \
 -v `pwd`config/minio:/root/.minio -v `pwd`/data/minio_data:/data  minio/minio:edge  server /data --console-address ":9001"
echo '启动成功'