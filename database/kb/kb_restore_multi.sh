#!/bin/bash

# 人大金仓数据库(KingbaseES)备份恢复脚本（支持多种压缩格式）
# 支持从各种压缩格式的备份文件恢复一个或多个数据库

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
人大金仓数据库(KingbaseES)备份恢复脚本（支持多种压缩格式）

用法: $0 [选项]

选项:
  -h, --host HOST         数据库主机地址 (默认: $DEFAULT_HOST)
  -p, --port PORT         数据库端口 (默认: $DEFAULT_PORT)
  -U, --username USER     用户名 (默认: $DEFAULT_USER)
  -W, --password PASS     密码 (默认: $DEFAULT_PASSWORD)
  -d, --database DB       要恢复的目标数据库名
  -s, --source SOURCE     备份源文件路径
  -v, --verbose           详细输出
  --clean                 恢复前清理数据库对象
  --no-owner              不恢复对象所有权信息
  --no-privileges         不恢复权限信息
  --help                  显示此帮助信息

示例:
  # 恢复custom格式的备份文件
  $0 -d testdb -s ./backups/testdb_20231201_120000.dmp
  
  # 恢复tar格式的备份文件
  $0 -d testdb -s ./backups/testdb_20231201_120000.tar
  
  # 恢复gzip压缩的备份文件
  $0 -d testdb -s ./backups/testdb_20231201_120000.dmp.gz
  
  # 恢复xz压缩的备份文件
  $0 -d testdb -s ./backups/testdb_20231201_120000.dmp.xz

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
            TARGET_DB="$2"
            shift 2
            ;;
        -s|--source)
            SOURCE_FILE="$2"
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
        --no-privileges)
            PRIVILEGES_FLAG="--no-privileges"
            shift
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

# 检测备份文件格式及压缩类型
detect_format_and_compression() {
    local file="$1"
    local ext="${file##*.}"
    local second_ext="${file%.*}"
    second_ext="${second_ext##*.}"
    
    # 检查是否是多重扩展名（如 .dmp.gz）
    if [[ "$ext" == "gz" || "$ext" == "xz" || "$ext" == "bz2" || "$ext" == "7z" ]]; then
        local compressed_ext="$ext"
        local base_ext="${file%.$ext}"
        base_ext="${base_ext##*.}"
        if [[ "$base_ext" == "dmp" || "$base_ext" == "tar" || "$base_ext" == "sql" ]]; then
            echo "${compressed_ext}_${base_ext}"
            return
        else
            echo "$compressed_ext"
            return
        fi
    fi
    
    # 检查单个扩展名
    case $ext in
        "dmp")
            echo "dmp"
            ;;
        "tar")
            echo "tar"
            ;;
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
            if head -c 100 "$file" | strings | grep -q "Custom DB dump"; then
                echo "dmp"
            elif head -c 100 "$file" | strings | grep -q "Tar DB dump"; then
                echo "tar"
            else
                echo "unknown"
            fi
            ;;
    esac
}

# 检查压缩工具是否可用
check_compression_tool() {
    local tool=$1
    case $tool in
        "xz")
            if ! command -v xz &> /dev/null; then
                echo "错误: xz 压缩工具不可用"
                exit 1
            fi
            ;;
        "pbzip2")
            if ! command -v pbzip2 &> /dev/null; then
                echo "错误: pbzip2 压缩工具不可用"
                exit 1
            fi
            ;;
        "7z")
            if ! command -v 7z &> /dev/null; then
                echo "错误: 7z 压缩工具不可用"
                exit 1
            fi
            ;;
        "gzip")
            if ! command -v gzip &> /dev/null; then
                echo "错误: gzip 压缩工具不可用"
                exit 1
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
    
    # 构建sys_restore命令选项
    local restore_options=""
    [[ -n "$CLEAN_FLAG" ]] && restore_options="$restore_options $CLEAN_FLAG"
    [[ -n "$OWNER_FLAG" ]] && restore_options="$restore_options $OWNER_FLAG"
    [[ -n "$PRIVILEGES_FLAG" ]] && restore_options="$restore_options $PRIVILEGES_FLAG"
    [[ -n "$VERBOSE_FLAG" ]] && restore_options="$restore_options $VERBOSE_FLAG"
    
    case $format in
        "dmp")
            # 恢复custom格式的备份文件
            echo "执行恢复命令: sys_restore -h '$HOST' -p '$PORT' -U '$USERNAME' -d '$db' $restore_options '$source_file'"
            PGPASSWORD="$PASSWORD" sys_restore -h "$HOST" -p "$PORT" -U "$USERNAME" -d "$db" $restore_options "$source_file"
            ;;
        "tar")
            # 恢复tar格式的备份文件
            echo "执行恢复命令: sys_restore -h '$HOST' -p '$PORT' -U '$USERNAME' -d '$db' $restore_options '$source_file'"
            PGPASSWORD="$PASSWORD" sys_restore -h "$HOST" -p "$PORT" -U "$USERNAME" -d "$db" $restore_options "$source_file"
            ;;
        "sql")
            # 恢复SQL格式的备份文件
            echo "执行恢复命令: ksql -h '$HOST' -p '$PORT' -U '$USERNAME' -d '$db' -f '$source_file'"
            PGPASSWORD="$PASSWORD" ksql -h "$HOST" -p "$PORT" -U "$USERNAME" -d "$db" -f "$source_file"
            ;;
        "gz_dmp")
            # 恢复gzip压缩的custom格式备份文件
            check_compression_tool "gzip"
            echo "执行恢复命令: gunzip -c '$source_file' | sys_restore -h '$HOST' -p '$PORT' -U '$USERNAME' -d '$db' $restore_options --format=custom"
            gunzip -c "$source_file" | PGPASSWORD="$PASSWORD" sys_restore -h "$HOST" -p "$PORT" -U "$USERNAME" -d "$db" $restore_options --format=custom
            ;;
        "gz_tar")
            # 恢复gzip压缩的tar格式备份文件
            check_compression_tool "gzip"
            echo "执行恢复命令: gunzip -c '$source_file' | sys_restore -h '$HOST' -p '$PORT' -U '$USERNAME' -d '$db' $restore_options --format=tar"
            gunzip -c "$source_file" | PGPASSWORD="$PASSWORD" sys_restore -h "$HOST" -p "$PORT" -U "$USERNAME" -d "$db" $restore_options --format=tar
            ;;
        "gz_sql")
            # 恢复gzip压缩的SQL格式备份文件
            check_compression_tool "gzip"
            echo "执行恢复命令: gunzip -c '$source_file' | ksql -h '$HOST' -p '$PORT' -U '$USERNAME' -d '$db'"
            gunzip -c "$source_file" | PGPASSWORD="$PASSWORD" ksql -h "$HOST" -p "$PORT" -U "$USERNAME" -d "$db"
            ;;
        "xz_dmp")
            # 恢复xz压缩的custom格式备份文件
            check_compression_tool "xz"
            echo "执行恢复命令: xz -dc '$source_file' | sys_restore -h '$HOST' -p '$PORT' -U '$USERNAME' -d '$db' $restore_options --format=custom"
            xz -dc "$source_file" | PGPASSWORD="$PASSWORD" sys_restore -h "$HOST" -p "$PORT" -U "$USERNAME" -d "$db" $restore_options --format=custom
            ;;
        "xz_tar")
            # 恢复xz压缩的tar格式备份文件
            check_compression_tool "xz"
            echo "执行恢复命令: xz -dc '$source_file' | sys_restore -h '$HOST' -p '$PORT' -U '$USERNAME' -d '$db' $restore_options --format=tar"
            xz -dc "$source_file" | PGPASSWORD="$PASSWORD" sys_restore -h "$HOST" -p "$PORT" -U "$USERNAME" -d "$db" $restore_options --format=tar
            ;;
        "xz_sql")
            # 恢复xz压缩的SQL格式备份文件
            check_compression_tool "xz"
            echo "执行恢复命令: xz -dc '$source_file' | ksql -h '$HOST' -p '$PORT' -U '$USERNAME' -d '$db'"
            xz -dc "$source_file" | PGPASSWORD="$PASSWORD" ksql -h "$HOST" -p "$PORT" -U "$USERNAME" -d "$db"
            ;;
        "bz2_dmp")
            # 恢复bz2压缩的custom格式备份文件
            check_compression_tool "pbzip2"
            echo "执行恢复命令: bzcat '$source_file' | sys_restore -h '$HOST' -p '$PORT' -U '$USERNAME' -d '$db' $restore_options --format=custom"
            bzcat "$source_file" | PGPASSWORD="$PASSWORD" sys_restore -h "$HOST" -p "$PORT" -U "$USERNAME" -d "$db" $restore_options --format=custom
            ;;
        "bz2_tar")
            # 恢复bz2压缩的tar格式备份文件
            check_compression_tool "pbzip2"
            echo "执行恢复命令: bzcat '$source_file' | sys_restore -h '$HOST' -p '$PORT' -U '$USERNAME' -d '$db' $restore_options --format=tar"
            bzcat "$source_file" | PGPASSWORD="$PASSWORD" sys_restore -h "$HOST" -p "$PORT" -U "$USERNAME" -d "$db" $restore_options --format=tar
            ;;
        "bz2_sql")
            # 恢复bz2压缩的SQL格式备份文件
            check_compression_tool "pbzip2"
            echo "执行恢复命令: bzcat '$source_file' | ksql -h '$HOST' -p '$PORT' -U '$USERNAME' -d '$db'"
            bzcat "$source_file" | PGPASSWORD="$PASSWORD" ksql -h "$HOST" -p "$PORT" -U "$USERNAME" -d "$db"
            ;;
        "7z_dmp")
            # 恢复7z压缩的custom格式备份文件
            check_compression_tool "7z"
            echo "执行恢复命令: 7z x -so '$source_file' | sys_restore -h '$HOST' -p '$PORT' -U '$USERNAME' -d '$db' $restore_options --format=custom"
            7z x -so "$source_file" | PGPASSWORD="$PASSWORD" sys_restore -h "$HOST" -p "$PORT" -U "$USERNAME" -d "$db" $restore_options --format=custom
            ;;
        "7z_tar")
            # 恢复7z压缩的tar格式备份文件
            check_compression_tool "7z"
            echo "执行恢复命令: 7z x -so '$source_file' | sys_restore -h '$HOST' -p '$PORT' -U '$USERNAME' -d '$db' $restore_options --format=tar"
            7z x -so "$source_file" | PGPASSWORD="$PASSWORD" sys_restore -h "$HOST" -p "$PORT" -U "$USERNAME" -d "$db" $restore_options --format=tar
            ;;
        "7z_sql")
            # 恢复7z压缩的SQL格式备份文件
            check_compression_tool "7z"
            echo "执行恢复命令: 7z x -so '$source_file' | ksql -h '$HOST' -p '$PORT' -U '$USERNAME' -d '$db'"
            7z x -so "$source_file" | PGPASSWORD="$PASSWORD" ksql -h "$HOST" -p "$PORT" -U "$USERNAME" -d "$db"
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