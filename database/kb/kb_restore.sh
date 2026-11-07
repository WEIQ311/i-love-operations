#!/bin/bash

# 人大金仓数据库(KingbaseES)备份恢复脚本
# 支持从备份文件恢复一个或多个数据库

set -e  # 遇到错误时退出

# 默认配置
DEFAULT_HOST="localhost"
DEFAULT_PORT="54321"
DEFAULT_USER="system"
DEFAULT_PASSWORD="manager"
BACKUP_DIR="./backups"

# 显示帮助信息
show_help() {
    cat << EOF
人大金仓数据库(KingbaseES)备份恢复脚本

用法: $0 [选项]

选项:
  -h, --host HOST         数据库主机地址 (默认: $DEFAULT_HOST)
  -p, --port PORT         数据库端口 (默认: $DEFAULT_PORT)
  -U, --username USER     用户名 (默认: $DEFAULT_USER)
  -W, --password PASS     密码 (默认: $DEFAULT_PASSWORD)
  -d, --database DB       要恢复的目标数据库名
  -s, --source SOURCE     备份源文件路径
  -c, --clean             恢复前清除目标数据库对象
  -n, --no-owner          不恢复对象所有权信息
  -x, --no-privileges     不恢复访问权限（GRANT/REVOKE命令）
  -O, --no-acl            不恢复访问控制权限
  -v, --verbose           详细输出
  --single-transaction    作为单个事务恢复
  --help                  显示此帮助信息

示例:
  # 恢复单个数据库
  $0 -d testdb -s ./backups/testdb_20231201_120000.dmp
  
  # 指定主机和端口
  $0 -h 192.168.1.100 -p 54321 -d testdb -s ./backups/testdb_20231201_120000.dmp
  
  # 恢复时清除现有对象
  $0 -d testdb -s ./backups/testdb_20231201_120000.dmp --clean

EOF
}

# 解析命令行参数
HOST="$DEFAULT_HOST"
PORT="$DEFAULT_PORT"
USERNAME="$DEFAULT_USER"
PASSWORD="$DEFAULT_PASSWORD"
TARGET_DB=""
SOURCE_FILE=""
CLEAN_FLAG=""
OWNER_FLAG=""
PRIVILEGES_FLAG=""
ACL_FLAG=""
VERBOSE_FLAG=""
SINGLE_TRANSACTION_FLAG=""

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
            TARGET_DB="$2"
            shift 2
            ;;
        -s|--source)
            SOURCE_FILE="$2"
            shift 2
            ;;
        -c|--clean)
            CLEAN_FLAG="--clean"
            shift
            ;;
        -n|--no-owner)
            OWNER_FLAG="--no-owner"
            shift
            ;;
        -x|--no-privileges)
            PRIVILEGES_FLAG="--no-privileges"
            shift
            ;;
        -O|--no-acl)
            ACL_FLAG="--no-acl"
            shift
            ;;
        -v|--verbose)
            VERBOSE_FLAG="--verbose"
            shift
            ;;
        --single-transaction)
            SINGLE_TRANSACTION_FLAG="--single-transaction"
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

echo "开始恢复人大金仓数据库..."
echo "主机: $HOST:$PORT"
echo "用户名: $USERNAME"
echo "目标数据库: $TARGET_DB"
echo "源备份文件: $SOURCE_FILE"

# 验证数据库连接
validate_connection() {
    local db=$1
    echo "验证数据库连接: $db"
    PGPASSWORD="$PASSWORD" psql -h "$HOST" -p "$PORT" -U "$USERNAME" -d "$db" -c "SELECT 1;" > /dev/null 2>&1
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
    
    case $ext in
        "dmp")
            echo "custom"
            ;;
        "tar")
            echo "tar"
            ;;
        "sql")
            echo "plain"
            ;;
        *)
            # 尝试通过文件内容检测
            if head -c 20 "$file" | strings | grep -q "Custom DB dump"; then
                echo "custom"
            elif head -c 20 "$file" | strings | grep -q "Tar DB dump"; then
                echo "tar"
            else
                echo "plain"
            fi
            ;;
    esac
}

# 执行数据库恢复
restore_database() {
    local db=$1
    local source_file=$2
    local format=$(detect_format "$source_file")
    
    echo "检测到备份文件格式: $format"
    
    # 构建sys_restore或ksql命令
    case $format in
        "custom"|"tar")
            # 使用sys_restore
            CMD="PGPASSWORD='$PASSWORD' sys_restore $VERBOSE_FLAG -h '$HOST' -p '$PORT' -U '$USERNAME'"
            CMD="$CMD $CLEAN_FLAG $OWNER_FLAG $PRIVILEGES_FLAG $ACL_FLAG $SINGLE_TRANSACTION_FLAG"
            CMD="$CMD -d '$db' '$source_file'"
            ;;
        "plain")
            # 使用ksql
            CMD="PGPASSWORD='$PASSWORD' ksql $VERBOSE_FLAG -h '$HOST' -p '$PORT' -U '$USERNAME' -d '$db' -f '$source_file'"
            ;;
        *)
            echo "错误: 无法识别备份文件格式: $source_file"
            return 1
            ;;
    esac
    
    echo "执行恢复命令: $CMD"
    eval $CMD
    
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