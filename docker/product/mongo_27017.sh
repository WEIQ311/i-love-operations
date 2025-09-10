#!/bin/bash
pwd=`pwd`
docker run -d --name mongo -p 27017:27017 -v $pwd/data/mongo_27017_data:/data/db \
  -v $pwd/config/mongo_27017_config:/etc/mongo \
  -e MONGO_INITDB_ROOT_USERNAME=admin \
  -e MONGO_INITDB_ROOT_PASSWORD='Root)OIBFslo.12^3' \
  -e TZ=Asia/Shanghai --restart=always mongo
