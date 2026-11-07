#!/bin/bash

# MySQL数据库备份示例脚本
# 演示如何使用备份和恢复脚本

echo "==========================================="
echo "MySQL数据库备份示例"
echo "==========================================="

# 检查是否提供了数据库名称
if [ -z "$1" ]; then
    echo "用法: $0 <数据库名称> [备份目录]"
    echo "示例: $0 testdb"
    echo "示例: $0 testdb /data/backups"
    exit 1
fi

DATABASE_NAME=$1
BACKUP_DIR=${2:-"./backups"}

echo "数据库名称: $DATABASE_NAME"
echo "备份目录: $BACKUP_DIR"
echo ""

# 创建备份目录
mkdir -p "$BACKUP_DIR"

# 执行备份
echo "开始备份数据库: $DATABASE_NAME"
echo "./mysql_backup.sh -d $DATABASE_NAME -D $BACKUP_DIR --verbose"
./mysql_backup.sh -d "$DATABASE_NAME" -D "$BACKUP_DIR" --verbose

echo ""
echo "备份完成！"
echo ""

# 显示备份文件信息
echo "备份文件列表:"
ls -la "$BACKUP_DIR"/${DATABASE_NAME}_*.sql* 2>/dev/null || echo "未找到备份文件"

echo ""
echo "如需恢复数据库，请使用以下命令:"
echo "./mysql_restore.sh -d $DATABASE_NAME -s $BACKUP_DIR/<备份文件名> --verbose"