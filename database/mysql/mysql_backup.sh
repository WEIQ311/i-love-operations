#!/bin/bash

# MySQL数据库全量备份脚本
# 支持备份一个或多个数据库

set -e  # 遇到错误时退出

# 默认配置
DEFAULT_HOST="localhost"
DEFAULT_PORT="3306"
DEFAULT_USER="root"
DEFAULT_PASSWORD="password"
BACKUP_DIR="./backups"
DATE=$(date +"%Y%m%d_%H%M%S")
COMPRESSION_LEVEL=9  # 默认最高压缩级别

# 显示帮助信息
show_help() {
    cat << EOF
MySQL数据库全量备份脚本

用法: $0 [选项]

选项:
  -h, --host HOST         数据库主机地址 (默认: $DEFAULT_HOST)
  -p, --port PORT         数据库端口 (默认: $DEFAULT_PORT)
  -u, --username USER     用户名 (默认: $DEFAULT_USER)
  -P, --password PASS     密码 (默认: $DEFAULT_PASSWORD)
  -d, --database DB       要备份的数据库名 (可指定多个，用逗号分隔)
  -D, --directory DIR     备份文件存储目录 (默认: $BACKUP_DIR)
  -c, --compress          压缩备份文件 (使用最高压缩比 -9)
  --exclude-table PATTERN 排除的表模式 (支持通配符)
  --single-transaction    使用单一事务保证一致性
  --routines              包含存储过程和函数
  --triggers              包含触发器
  --events                包含事件调度器事件
  --verbose               详细输出
  --help                  显示此帮助信息

示例:
  # 备份单个数据库
  $0 -d testdb
  
  # 备份多个数据库
  $0 -d db1,db2,db3
  
  # 指定主机和端口
  $0 -h 192.168.1.100 -p 3306 -d testdb
  
  # 指定备份目录并压缩
  $0 -d testdb -D /data/backups --compress
  
  # 排除特定表
  $0 -d testdb --exclude-table 'temp_*'
  
  # 详细输出
  $0 -d testdb --verbose

EOF
}

# 解析命令行参数
HOST="$DEFAULT_HOST"
PORT="$DEFAULT_PORT"
USERNAME="$DEFAULT_USER"
PASSWORD="$DEFAULT_PASSWORD"
DATABASES=""
BACKUP_DIR="$BACKUP_DIR"
COMPRESS_FLAG=""
EXCLUDE_TABLE=""
SINGLE_TRANSACTION_FLAG="--single-transaction"
ROUTINES_FLAG="--routines"
TRIGGERS_FLAG="--triggers"
EVENTS_FLAG="--events"
VERBOSE_FLAG=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--host)
            HOST="$2"
            shift 2
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -u|--username)
            USERNAME="$2"
            shift 2
            ;;
        -P|--password)
            PASSWORD="$2"
            shift 2
            ;;
        -d|--database)
            DATABASES="$2"
            shift 2
            ;;
        -D|--directory)
            BACKUP_DIR="$2"
            shift 2
            ;;
        -c|--compress)
            COMPRESS_FLAG="--compress"
            shift
            ;;
        --exclude-table)
            EXCLUDE_TABLE="$2"
            shift 2
            ;;
        --single-transaction)
            SINGLE_TRANSACTION_FLAG="--single-transaction"
            shift
            ;;
        --routines)
            ROUTINES_FLAG="--routines"
            shift
            ;;
        --triggers)
            TRIGGERS_FLAG="--triggers"
            shift
            ;;
        --events)
            EVENTS_FLAG="--events"
            shift
            ;;
        --verbose)
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
if [[ -z "$DATABASES" ]]; then
    echo "错误: 必须指定至少一个数据库名 (-d 参数)"
    show_help
    exit 1
fi

# 创建备份目录
mkdir -p "$BACKUP_DIR"

echo "开始备份MySQL数据库..."
echo "主机: $HOST:$PORT"
echo "用户名: $USERNAME"
echo "备份目录: $BACKUP_DIR"

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

# 执行数据库备份
backup_database() {
    local db=$1
    local backup_file="${BACKUP_DIR}/${db}_${DATE}.sql"
    
    echo "开始备份数据库: $db"
    
    echo "执行备份命令: mysqldump -h '$HOST' -P '$PORT' -u '$USERNAME' -p*** --single-transaction --routines --triggers --events --opt '$db' | gzip -9 > ${backup_file}.gz"
    # 使用极致压缩 - 最高压缩比
    mysqldump -h "$HOST" -P "$PORT" -u "$USERNAME" -p"$PASSWORD" \
        --single-transaction --routines --triggers --events --opt \
        "$db" | gzip -$COMPRESSION_LEVEL > "${backup_file}.gz"
    backup_file="${backup_file}.gz"
    
    if [ $? -eq 0 ]; then
        echo "数据库 $db 备份成功: $backup_file"
        # 显示备份文件大小
        if [[ -f "$backup_file" ]]; then
            echo "备份文件大小: $(du -h "$backup_file" | cut -f1)"
        fi
    else
        echo "错误: 数据库 $db 备份失败"
        return 1
    fi
}

# 如果指定了多个数据库，则分割处理
IFS=',' read -ra DB_ARRAY <<< "$DATABASES"

# 验证所有数据库连接
for db in "${DB_ARRAY[@]}"; do
    db=$(echo $db | xargs)  # 去除首尾空格
    if ! validate_connection "$db"; then
        echo "跳过数据库: $db"
        continue
    fi
done

# 备份所有数据库
for db in "${DB_ARRAY[@]}"; do
    db=$(echo $db | xargs)  # 去除首尾空格
    echo "----------------------------------------"
    if validate_connection "$db"; then
        backup_database "$db"
    else
        echo "跳过数据库: $db"
    fi
    echo "----------------------------------------"
done

echo ""
echo "备份任务完成！"
echo "备份文件位置: $BACKUP_DIR"
echo "备份时间: $(date)"