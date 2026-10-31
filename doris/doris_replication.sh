#!/bin/bash

# Doris表副本数检测和修改工具
# 支持检测副本数为1的表，以及修改表的副本数

# 默认参数
ACTION=""
HOST="localhost"
PORT=9030
USER="root"
PASSWORD=""
REPLICATION_NUM=""
FILE=""
DATABASE=""
TABLE=""
ALL_TABLES=false
OUTPUT_FILE=""
DRY_RUN=false
ALTER_AFTER_CHECK=false

# 解析命令行参数
show_help() {
    cat << EOF
用法: $0 <check|alter> [选项]

操作:
  check  检测副本数为1的表
  alter  修改表的副本数

检测选项:
  -H, --host HOST        Doris FE节点地址 (默认: localhost)
  -P, --port PORT        Doris FE查询端口 (默认: 9030)
  -u, --user USER        用户名 (默认: root)
  -p, --password PASS    密码 (默认: 空)
  -o, --output FILE      输出文件名
  --alter NUM            检测后直接修改为指定副本数

修改选项:
  -H, --host HOST        Doris FE节点地址 (默认: localhost)
  -P, --port PORT        Doris FE查询端口 (默认: 9030)
  -u, --user USER        用户名 (默认: root)
  -p, --password PASS    密码 (默认: 空)
  -n, --replication-num NUM  目标副本数 (必需)
  -f, --file FILE        包含表列表的文件路径
  -d, --database DB       数据库名
  -t, --table TABLE      表名
  --all-tables           修改指定数据库下所有表
  -o, --output FILE      结果输出文件
  --dry-run              仅显示SQL，不实际执行

示例:
  # 检测副本数为1的表
  $0 check -H 192.168.1.181 -P 9030 -u root -p root
  
  # 检测并直接修改为3
  $0 check -H 192.168.1.181 -P 9030 -u root -p root --alter 3
  
  # 从文件读取表列表并修改副本数为3
  $0 alter -H 192.168.1.181 -P 9030 -u root -p root -f tables.txt -n 3
  
  # 修改单个表
  $0 alter -H 192.168.1.181 -P 9030 -u root -p root -d test_db -t table1 -n 3
EOF
}

# 解析操作类型
if [ $# -eq 0 ]; then
    show_help
    exit 1
fi

ACTION="$1"
shift

# 解析其他参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -H|--host)
            HOST="$2"
            shift 2
            ;;
        -P|--port)
            PORT="$2"
            shift 2
            ;;
        -u|--user)
            USER="$2"
            shift 2
            ;;
        -p|--password)
            PASSWORD="$2"
            shift 2
            ;;
        -n|--replication-num)
            REPLICATION_NUM="$2"
            shift 2
            ;;
        -f|--file)
            FILE="$2"
            shift 2
            ;;
        -d|--database)
            DATABASE="$2"
            shift 2
            ;;
        -t|--table)
            TABLE="$2"
            shift 2
            ;;
        --all-tables)
            ALL_TABLES=true
            shift
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --alter)
            ALTER_AFTER_CHECK="$2"
            shift 2
            ;;
        -h|--help)
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

# 检查mysql客户端
if ! command -v mysql &> /dev/null; then
    echo "错误: 未找到 mysql 客户端"
    exit 1
fi

# 构建mysql连接命令
if [ -z "$PASSWORD" ]; then
    MYSQL_CMD="mysql -h${HOST} -P${PORT} -u${USER} -sN"
else
    MYSQL_CMD="mysql -h${HOST} -P${PORT} -u${USER} -p${PASSWORD} -sN"
fi

# 执行检测操作
if [ "$ACTION" = "check" ]; then
    echo "正在连接Doris数据库 ${HOST}:${PORT}..."
    if ! $MYSQL_CMD -e "SELECT 1" &>/dev/null; then
        echo "错误: 无法连接到Doris数据库"
        exit 1
    fi
    echo "连接成功!"
    
    # 获取所有数据库
    DATABASES=$($MYSQL_CMD -e "SHOW DATABASES" 2>/dev/null | grep -v -E "^(information_schema|sys|__internal_schema)$")
    echo "找到 $(echo "$DATABASES" | wc -l) 个数据库"
    
    # 生成输出文件名
    if [ -z "$OUTPUT_FILE" ]; then
        TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
        OUTPUT_FILE="doris_replication_one_tables_${TIMESTAMP}.txt"
    fi
    
    # 检测副本数为1的表
    echo "正在检测所有表的副本数..."
    TEMP_RESULT=$(mktemp)
    TOTAL_COUNT=0
    
    for DB in $DATABASES; do
        echo "  检查数据库: $DB"
        TABLES=$($MYSQL_CMD -D"$DB" -e "SHOW TABLES" 2>/dev/null)
        DB_COUNT=0
        
        for TABLE_NAME in $TABLES; do
            CREATE_SQL=$($MYSQL_CMD -D"$DB" -e "SHOW CREATE TABLE \`$TABLE_NAME\`" 2>/dev/null | cut -f2)
            if echo "$CREATE_SQL" | grep -qE '("replication_num"|'"'"'replication_num'"'"')\s*=\s*["'"'"']?1["'"'"']?'; then
                echo "$DB	$TABLE_NAME" >> "$TEMP_RESULT"
                TOTAL_COUNT=$((TOTAL_COUNT + 1))
                DB_COUNT=$((DB_COUNT + 1))
            fi
        done
        
        if [ $DB_COUNT -gt 0 ]; then
            echo "    找到 $DB_COUNT 个副本数为1的表"
        fi
    done
    
    # 写入结果文件
    TIMESTAMP_NOW=$(date +"%Y-%m-%d %H:%M:%S")
    {
        echo "# Doris数据库副本数为1的表检测结果"
        echo "# 检测时间: ${TIMESTAMP_NOW}"
        echo "# 数据库地址: ${HOST}:${PORT}"
        echo "# 共找到 ${TOTAL_COUNT} 个副本数为1的表"
        echo "# ============================================================"
        echo ""
        if [ $TOTAL_COUNT -gt 0 ]; then
            echo "库名	表名"
            echo "------------------------------------------------------------"
            cat "$TEMP_RESULT"
        else
            echo "未找到副本数为1的表"
        fi
    } > "$OUTPUT_FILE"
    
    echo ""
    echo "检测完成! 共找到 $TOTAL_COUNT 个副本数为1的表"
    echo "结果已保存到: $OUTPUT_FILE"
    
    # 如果指定了--alter，直接修改
    if [ -n "$ALTER_AFTER_CHECK" ] && [ $TOTAL_COUNT -gt 0 ]; then
        echo ""
        echo "开始修改表的副本数为 $ALTER_AFTER_CHECK..."
        SUCCESS_COUNT=0
        FAIL_COUNT=0
        
        CURRENT=0
        while IFS=$'\t' read -r db_name table_name; do
            CURRENT=$((CURRENT + 1))
            echo -n "[$CURRENT/$TOTAL_COUNT] 处理 $db_name.$table_name... "
            
            SQL="ALTER TABLE \`$table_name\` SET (\"replication_num\" = \"$ALTER_AFTER_CHECK\")"
            ERROR_OUTPUT=$($MYSQL_CMD -D"$db_name" -e "$SQL" 2>&1)
            
            if [ $? -eq 0 ]; then
                echo "✓ 成功"
                SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            else
                echo "✗ 失败: $ERROR_OUTPUT"
                FAIL_COUNT=$((FAIL_COUNT + 1))
            fi
        done < "$TEMP_RESULT"
        
        echo ""
        echo "修改完成! 成功: $SUCCESS_COUNT, 失败: $FAIL_COUNT"
    fi
    
    rm -f "$TEMP_RESULT"

# 执行修改操作
elif [ "$ACTION" = "alter" ]; then
    if [ -z "$REPLICATION_NUM" ]; then
        echo "错误: 必须指定目标副本数 (-n/--replication-num)"
        exit 1
    fi
    
    # 准备表列表
    TEMP_TABLES=$(mktemp)
    
    if [ -n "$FILE" ]; then
        grep -v "^#" "$FILE" | grep -v "^库名" | grep -v "^-" | grep -v "^$" | awk '{print $1"\t"$2}' > "$TEMP_TABLES"
        TABLE_COUNT=$(wc -l < "$TEMP_TABLES" | tr -d ' ')
        echo "从文件 '$FILE' 读取到 $TABLE_COUNT 个表"
    elif [ -n "$DATABASE" ] && [ -n "$TABLE" ]; then
        echo "$DATABASE	$TABLE" > "$TEMP_TABLES"
        TABLE_COUNT=1
    elif [ -n "$DATABASE" ] && [ "$ALL_TABLES" = true ]; then
        echo "正在获取数据库 '$DATABASE' 下的所有表..."
        if ! $MYSQL_CMD -e "SELECT 1" &>/dev/null; then
            echo "错误: 无法连接到Doris数据库"
            exit 1
        fi
        $MYSQL_CMD -D"$DATABASE" -e "SHOW TABLES" 2>/dev/null | awk -v db="$DATABASE" '{print db"\t"$1}' > "$TEMP_TABLES"
        TABLE_COUNT=$(wc -l < "$TEMP_TABLES" | tr -d ' ')
        echo "找到 $TABLE_COUNT 个表"
    else
        echo "错误: 必须指定 -f/--file, -d/-t, 或 -d/--all-tables"
        exit 1
    fi
    
    if [ -z "$OUTPUT_FILE" ]; then
        TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
        OUTPUT_FILE="alter_replication_result_${TIMESTAMP}.txt"
    fi
    
    echo "正在连接Doris数据库 ${HOST}:${PORT}..."
    if ! $MYSQL_CMD -e "SELECT 1" &>/dev/null; then
        echo "错误: 无法连接到Doris数据库"
        exit 1
    fi
    echo "连接成功!"
    
    echo ""
    echo "开始修改表的副本数为 $REPLICATION_NUM..."
    echo "共需要处理 $TABLE_COUNT 个表"
    echo ""
    
    SUCCESS_COUNT=0
    FAIL_COUNT=0
    TEMP_RESULT=$(mktemp)
    
    CURRENT=0
    while IFS=$'\t' read -r db_name table_name; do
        CURRENT=$((CURRENT + 1))
        echo -n "[$CURRENT/$TABLE_COUNT] 处理 $db_name.$table_name... "
        
        SQL="ALTER TABLE \`$table_name\` SET (\"replication_num\" = \"$REPLICATION_NUM\")"
        
        if [ "$DRY_RUN" = true ]; then
            echo ""
            echo "  SQL: $SQL"
            echo "$db_name	$table_name	DRY-RUN	$SQL" >> "$TEMP_RESULT"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            ERROR_OUTPUT=$($MYSQL_CMD -D"$db_name" -e "$SQL" 2>&1)
            if [ $? -eq 0 ]; then
                echo "✓ 成功"
                echo "$db_name	$table_name	成功	-" >> "$TEMP_RESULT"
                SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            else
                echo "✗ 失败: $ERROR_OUTPUT"
                echo "$db_name	$table_name	失败	$ERROR_OUTPUT" >> "$TEMP_RESULT"
                FAIL_COUNT=$((FAIL_COUNT + 1))
            fi
        fi
    done < "$TEMP_TABLES"
    
    # 写入结果文件
    TIMESTAMP_NOW=$(date +"%Y-%m-%d %H:%M:%S")
    {
        echo "# Doris表副本数修改结果"
        echo "# 修改时间: ${TIMESTAMP_NOW}"
        echo "# 数据库地址: ${HOST}:${PORT}"
        echo "# 目标副本数: ${REPLICATION_NUM}"
        echo "# 共处理: ${TABLE_COUNT} 个表"
        echo "# 成功: ${SUCCESS_COUNT} 个"
        echo "# 失败: ${FAIL_COUNT} 个"
        echo "# ============================================================"
        echo ""
        if [ "$DRY_RUN" = true ]; then
            echo "库名	表名	状态	SQL语句"
        else
            echo "库名	表名	状态	错误信息"
        fi
        echo "------------------------------------------------------------"
        cat "$TEMP_RESULT"
    } > "$OUTPUT_FILE"
    
    echo ""
    echo "修改完成! 成功: $SUCCESS_COUNT, 失败: $FAIL_COUNT"
    if [ "$DRY_RUN" = true ]; then
        echo "注意: 这是DRY-RUN模式，未实际执行修改"
    fi
    echo "结果已保存到: $OUTPUT_FILE"
    
    rm -f "$TEMP_TABLES" "$TEMP_RESULT"
else
    echo "错误: 未知操作 '$ACTION'，请使用 'check' 或 'alter'"
    show_help
    exit 1
fi
