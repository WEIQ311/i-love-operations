#!/bin/bash
echo '启动minio'
docker run -p 9000:9000 -p 9001:9001 --name minio_9000 -d --restart=always -e "MINIO_ACCESS_KEY=admin" -e "MINIO_SECRET_KEY=Admin#$%^KON" \
 -v `pwd`config/minio:/root/.minio -v `pwd`/data/minio_data:/data  minio/minio:edge  server /data --console-address ":9001"
echo '启动成功'