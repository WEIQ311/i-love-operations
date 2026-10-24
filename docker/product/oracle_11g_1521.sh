#!/bin/bash
pwd=`pwd`
docker run --name oracle_11g_1521 -d --restart=always -p 8080:8080  -p 1521:1521 -e TZ=Asia/Shanghai \
-v $pwd/data/oracle_data_1521:/u01/app/oracle hub.c.163.com/springwen/oracle-xe-11g:latest
