#!/bin/bash

# 人大金仓数据库(KingbaseES)全量备份脚本
# 支持备份一个或多个数据库

set -e  # 遇到错误时退出

# 默认配置
DEFAULT_HOST="localhost"
DEFAULT_PORT="54321"
DEFAULT_USER="system"
DEFAULT_PASSWORD="manager"
BACKUP_DIR="./backups"
DATE=$(date +"%Y%m%d_%H%M%S")

# 显示帮助信息
show_help() {
    cat << EOF
人大金仓数据库(KingbaseES)全量备份脚本

用法: $0 [选项]

选项:
  -h, --host HOST         数据库主机地址 (默认: $DEFAULT_HOST)
  -p, --port PORT         数据库端口 (默认: $DEFAULT_PORT)
  -U, --username USER     用户名 (默认: $DEFAULT_USER)
  -W, --password PASS     密码 (默认: $DEFAULT_PASSWORD)
  -d, --database DB       要备份的数据库名 (可指定多个，用逗号分隔)
  -D, --directory DIR     备份文件存储目录 (默认: $BACKUP_DIR)
  -f, --format FORMAT     备份格式 (custom, tar, plain, 或者 db4 默认: custom)
  -c, --compress          压缩级别 (0-9，默认: 6)
  --exclude-table PATTERN 排除的表模式 (支持通配符)
  --exclude-schema SCHEMA 排除的模式
  --clean                 在备份文件中添加清理命令
  --no-owner              不备份对象所有权信息
  --verbose               详细输出
  --help                  显示此帮助信息

示例:
  # 备份单个数据库
  $0 -d testdb
  
  # 备份多个数据库
  $0 -d db1,db2,db3
  
  # 指定主机和端口
  $0 -h 192.168.1.100 -p 54321 -d testdb
  
  # 指定备份目录和格式
  $0 -d testdb -D /data/backups -f tar -c 9
  
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
FORMAT="custom"
COMPRESS_LEVEL=9
EXCLUDE_TABLE=""
EXCLUDE_SCHEMA=""
CLEAN_FLAG=""
OWNER_FLAG=""
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
        -U|--username)
            USERNAME="$2"
            shift 2
            ;;
        -W|--password)
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
        -f|--format)
            FORMAT="$2"
            shift 2
            ;;
        -c|--compress)
            COMPRESS_LEVEL="$2"
            shift 2
            ;;
        --exclude-table)
            EXCLUDE_TABLE="$2"
            shift 2
            ;;
        --exclude-schema)
            EXCLUDE_SCHEMA="$2"
            shift 2
            ;;
        --clean)
            CLEAN_FLAG="--clean"
            shift
            ;;
        --no-owner)
            OWNER_FLAG="--no-owner"
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

echo "开始备份人大金仓数据库..."
echo "主机: $HOST:$PORT"
echo "用户名: $USERNAME"
echo "备份目录: $BACKUP_DIR"
echo "备份格式: $FORMAT"
echo "压缩级别: $COMPRESS_LEVEL"

# 验证数据库连接
validate_connection() {
    local db=$1
    echo "验证数据库连接: $db"
    PGPASSWORD="$PASSWORD" psql -h "$HOST" -p "$PORT" -U "$USERNAME" -d "$db" -c "SELECT version();" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "错误: 无法连接到数据库 $db"
        return 1
    fi
    echo "数据库 $db 连接成功"
}

# 执行数据库备份
backup_database() {
    local db=$1
    local backup_file="${BACKUP_DIR}/${db}_${DATE}"
    
    echo "开始备份数据库: $db"
    
    # 根据备份格式确定文件扩展名
    case $FORMAT in
        "custom")
            backup_file="${backup_file}.dmp"
            ;;
        "tar")
            backup_file="${backup_file}.tar"
            ;;
        "plain")
            backup_file="${backup_file}.sql"
            ;;
        *)
            backup_file="${backup_file}.dmp"
            ;;
    esac
    
    # 构建sys_dump命令
    CMD="PGPASSWORD='$PASSWORD' sys_dump $VERBOSE_FLAG -h '$HOST' -p '$PORT' -U '$USERNAME'"
    
    # 添加格式参数
    case $FORMAT in
        "custom")
            CMD="$CMD -Fc"
            ;;
        "tar")
            CMD="$CMD -Ft"
            ;;
        "plain")
            CMD="$CMD -Fp"
            ;;
    esac
    
    # 添加压缩参数（仅对custom格式有效）
    if [[ "$FORMAT" == "custom" ]] && [[ $COMPRESS_LEVEL -ge 0 ]] && [[ $COMPRESS_LEVEL -le 9 ]]; then
        CMD="$CMD -Z $COMPRESS_LEVEL"
    fi
    
    # 添加其他选项
    CMD="$CMD $CLEAN_FLAG $OWNER_FLAG"
    
    # 添加排除选项
    if [[ -n "$EXCLUDE_TABLE" ]]; then
        CMD="$CMD --exclude-table='$EXCLUDE_TABLE'"
    fi
    
    if [[ -n "$EXCLUDE_SCHEMA" ]]; then
        CMD="$CMD --exclude-schema='$EXCLUDE_SCHEMA'"
    fi
    
    # 指定数据库和输出文件
    CMD="$CMD -d '$db' -f '$backup_file'"
    
    echo "执行备份命令: $CMD"
    eval $CMD
    
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