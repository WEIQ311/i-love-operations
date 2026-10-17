#!/bin/sh
 
echo '停止docker'
systemctl stop docker
echo '删除docker.service'
rm -f /etc/systemd/system/docker.service
echo '删除docker文件'
rm -rf /usr/bin/docker*
echo '重新加载配置文件'
systemctl daemon-reload
echo '卸载成功'
