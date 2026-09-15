#!/bin/bash

# MySQL数据库备份恢复脚本（支持多种压缩格式）
# 支持从各种压缩格式的备份文件恢复一个或多个数据库

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
MySQL数据库备份恢复脚本（支持多种压缩格式）

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
  # 恢复普通SQL文件
  $0 -d testdb -s ./backups/testdb_20231201_120000.sql
  
  # 恢复gzip压缩的SQL文件
  $0 -d testdb -s ./backups/testdb_20231201_120000.sql.gz
  
  # 恢复xz压缩的SQL文件
  $0 -d testdb -s ./backups/testdb_20231201_120000.sql.xz
  
  # 恢复7z压缩的SQL文件
  $0 -d testdb -s ./backups/testdb_20231201_120000.sql.7z

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

# 检测备份文件格式及压缩类型
detect_format_and_compression() {
    local file="$1"
    local ext="${file##*.}"
    local second_ext="${file%.*}"
    second_ext="${second_ext##*.}"
    
    # 检查是否是多重扩展名（如 .sql.gz）
    if [[ "$ext" == "gz" || "$ext" == "xz" || "$ext" == "bz2" || "$ext" == "7z" ]]; then
        local compressed_ext="$ext"
        local sql_ext="$second_ext"
        if [[ "$sql_ext" == "sql" ]]; then
            echo "${compressed_ext}_sql"
            return
        else
            echo "$compressed_ext"
            return
        fi
    fi
    
    # 检查单个扩展名
    case $ext in
        "sql")
            echo "sql"
            ;;
        "gz")
            echo "gz"
            ;;
        "xz")
            echo "xz"
            ;;
        "bz2")
            echo "bz2"
            ;;
        "7z")
            echo "7z"
            ;;
        *)
            # 尝试通过文件内容检测
            if head -n 1 "$file" | grep -q "^-- MySQL dump"; then
                echo "sql"
            else
                echo "unknown"
            fi
            ;;
    esac
}

# 执行数据库恢复
restore_database() {
    local db=$1
    local source_file=$2
    local format=$(detect_format_and_compression "$source_file")
    
    echo "检测到备份文件格式: $format"
    
    case $format in
        "sql")
            # 直接执行SQL文件
            echo "执行恢复命令: mysql -h '$HOST' -P '$PORT' -u '$USERNAME' -p*** -D '$db' < '$source_file'"
            mysql -h "$HOST" -P "$PORT" -u "$USERNAME" -p"$PASSWORD" -D "$db" < "$source_file"
            ;;
        "gz"|"_sql_gz")
            # 解压并执行gzip压缩的SQL文件
            echo "执行恢复命令: gunzip -c '$source_file' | mysql -h '$HOST' -P '$PORT' -u '$USERNAME' -p*** -D '$db'"
            gunzip -c "$source_file" | mysql -h "$HOST" -P "$PORT" -u "$USERNAME" -p"$PASSWORD" -D "$db"
            ;;
        "xz"|"_sql_xz")
            # 解压并执行xz压缩的SQL文件
            echo "执行恢复命令: xz -dc '$source_file' | mysql -h '$HOST' -P '$PORT' -u '$USERNAME' -p*** -D '$db'"
            xz -dc "$source_file" | mysql -h "$HOST" -P "$PORT" -u "$USERNAME" -p"$PASSWORD" -D "$db"
            ;;
        "bz2"|"_sql_bz2")
            # 解压并执行bz2压缩的SQL文件
            echo "执行恢复命令: bzcat '$source_file' | mysql -h '$HOST' -P '$PORT' -u '$USERNAME' -p*** -D '$db'"
            bzcat "$source_file" | mysql -h "$HOST" -P "$PORT" -u "$USERNAME" -p"$PASSWORD" -D "$db"
            ;;
        "7z"|"_sql_7z")
            # 解压并执行7z压缩的SQL文件
            echo "执行恢复命令: 7z x -so '$source_file' | mysql -h '$HOST' -P '$PORT' -u '$USERNAME' -p*** -D '$db'"
            7z x -so "$source_file" | mysql -h "$HOST" -P "$PORT" -u "$USERNAME" -p"$PASSWORD" -D "$db"
            ;;
        *)
            echo "错误: 无法识别备份文件格式: $source_file (检测格式: $format)"
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