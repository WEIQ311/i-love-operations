#!/bin/bash

# MySQL数据库备份恢复脚本
# 支持从备份文件恢复一个或多个数据库

set -e  # 遇到错误时退出

# 默认配置
DEFAULT_HOST="localhost"
DEFAULT_PORT="3306"
DEFAULT_USER="root"
DEFAULT_PASSWORD="password"
BACKUP_DIR="./backups"

# 显示帮助信息
show_help() {
    cat << EOF
MySQL数据库备份恢复脚本

用法: $0 [选项]

选项:
  -h, --host HOST         数据库主机地址 (默认: $DEFAULT_HOST)
  -P, --port PORT         数据库端口 (默认: $DEFAULT_PORT)
  -u, --username USER     用户名 (默认: $DEFAULT_USER)
  -p, --password PASS     密码 (默认: $DEFAULT_PASSWORD)
  -d, --database DB       要恢复的目标数据库名
  -s, --source SOURCE     备份源文件路径
  -v, --verbose           详细输出
  --help                  显示此帮助信息

示例:
  # 恢复单个数据库
  $0 -d testdb -s ./backups/testdb_20231201_120000.sql
  
  # 指定主机和端口
  $0 -h 192.168.1.100 -P 3306 -d testdb -s ./backups/testdb_20231201_120000.sql

EOF
}

# 解析命令行参数
HOST="$DEFAULT_HOST"
PORT="$DEFAULT_PORT"
USERNAME="$DEFAULT_USER"
PASSWORD="$DEFAULT_PASSWORD"
TARGET_DB=""
SOURCE_FILE=""
VERBOSE_FLAG=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--host)
            HOST="$2"
            shift 2
            ;;
        -P|--port)
            PORT="$2"
            shift 2
            ;;
        -u|--username)
            USERNAME="$2"
            shift 2
            ;;
        -p|--password)
            PASSWORD="$2"
            shift 2
            ;;
        -d|--database)
            TARGET_DB="$2"
            shift 2
            ;;
        -s|--source)
            SOURCE_FILE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE_FLAG="-v"
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 验证必要参数
if [[ -z "$TARGET_DB" ]]; then
    echo "错误: 必须指定目标数据库名 (-d 参数)"
    show_help
    exit 1
fi

if [[ -z "$SOURCE_FILE" ]]; then
    echo "错误: 必须指定备份源文件路径 (-s 参数)"
    show_help
    exit 1
fi

# 检查备份文件是否存在
if [[ ! -f "$SOURCE_FILE" ]]; then
    echo "错误: 备份文件不存在: $SOURCE_FILE"
    exit 1
fi

echo "开始恢复MySQL数据库..."
echo "主机: $HOST:$PORT"
echo "用户名: $USERNAME"
echo "目标数据库: $TARGET_DB"
echo "源备份文件: $SOURCE_FILE"

# 验证数据库连接
validate_connection() {
    local db=$1
    echo "验证数据库连接: $db"
    mysql -h "$HOST" -P "$PORT" -u "$USERNAME" -p"$PASSWORD" -e "USE $db; SELECT 1;" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "错误: 无法连接到数据库 $db"
        return 1
    fi
    echo "数据库 $db 连接成功"
}

# 检测备份文件格式
detect_format() {
    local file="$1"
    local ext="${file##*.}"
    
    if [[ "$ext" == "gz" ]]; then
        # 检查.gz文件是否是压缩的SQL文件
        if gunzip -t "$file" 2>/dev/null; then
            echo "compressed_sql"
        else
            echo "unknown"
        fi
    elif [[ "$ext" == "sql" ]]; then
        echo "sql"
    else
        # 检查文件开头是否是SQL内容
        if head -n 1 "$file" | grep -q "^-- MySQL dump"; then
            echo "sql"
        else
            echo "unknown"
        fi
    fi
}

# 执行数据库恢复
restore_database() {
    local db=$1
    local source_file=$2
    local format=$(detect_format "$source_file")
    
    echo "检测到备份文件格式: $format"
    
    case $format in
        "sql")
            echo "执行恢复命令: mysql -h '$HOST' -P '$PORT' -u '$USERNAME' -p*** -D '$db' < '$source_file'"
            mysql -h "$HOST" -P "$PORT" -u "$USERNAME" -p"$PASSWORD" -D "$db" < "$source_file"
            ;;
        "compressed_sql")
            echo "执行恢复命令: gunzip -c '$source_file' | mysql -h '$HOST' -P '$PORT' -u '$USERNAME' -p*** -D '$db'"
            gunzip -c "$source_file" | mysql -h "$HOST" -P "$PORT" -u "$USERNAME" -p"$PASSWORD" -D "$db"
            ;;
        *)
            echo "错误: 无法识别备份文件格式: $source_file"
            return 1
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        echo "数据库 $db 恢复成功"
    else
        echo "错误: 数据库 $db 恢复失败"
        return 1
    fi
}

# 验证目标数据库连接
if ! validate_connection "$TARGET_DB"; then
    echo "警告: 无法连接到目标数据库 $TARGET_DB"
    echo "请确保数据库存在且可访问"
    exit 1
fi

echo "----------------------------------------"
echo "开始恢复过程..."
restore_database "$TARGET_DB" "$SOURCE_FILE"
echo "----------------------------------------"

echo ""
echo "恢复任务完成！"
echo "恢复时间: $(date)"