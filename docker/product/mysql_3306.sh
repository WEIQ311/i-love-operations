#!/bin/bash
pwd=`pwd`
docker run --name mysql_3306  -e MYSQL_ROOT_PASSWORD=')(^FGJLPRoot.123' -e TZ=Asia/Shanghai -e MYSQL_ROOT_HOST=% \
-v $pwd/data/mysql_data_3306:/var/lib/mysql \
-p 3306:3306 -d --restart=always mysql:5.7.44 \
--lower_case_table_names=1  --collation_server=utf8_general_ci \
--max_connections=5000 --event_scheduler=ON --sql_mode= --log_timestamps=SYSTEM \
--character-set-server=utf8 --log_bin_trust_function_creators=1 --transaction_isolation=READ-COMMITTED \
--max_allowed_packet=104857600  --expire_logs_days=7 --server-id=127001 --log-bin=/var/lib/mysql/mysql-bin
