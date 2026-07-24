#!/bin/bash
# Hive(Kerberos)到Doris批量同步脚本
# 使用hive_to_doris_sync.py进行数据同步

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PYTHON_SCRIPT="${SCRIPT_DIR}/hive_to_doris_sync.py"
TABLE_FILE="${SCRIPT_DIR}/tables_to_sync.txt"
CONFIG_FILE="${SCRIPT_DIR}/hive_to_doris_config.ini"

DORIS_HOST="${DORIS_HOST:-192.168.1.181}"
DORIS_PORT="${DORIS_PORT:-9030}"
DORIS_USER="${DORIS_USER:-root}"
DORIS_PASSWORD="${DORIS_PASSWORD:-}"

HIVE_METASTORE="${HIVE_METASTORE:-thrift://hive-metastore:9083}"
HDFS_NAMENODE="${HDFS_NAMENODE:-}"
CATALOG_NAME="${CATALOG_NAME:-hive_catalog}"

KERBEROS_PRINCIPAL="${KERBEROS_PRINCIPAL:-}"
KERBEROS_KEYTAB="${KERBEROS_KEYTAB:-}"
KRB5_CONF="${KRB5_CONF:-/etc/krb5.conf}"
HIVE_PRINCIPAL="${HIVE_PRINCIPAL:-}"
HDFS_PRINCIPAL="${HDFS_PRINCIPAL:-}"

PARALLEL="${PARALLEL:-4}"
REPLICATION_NUM="${REPLICATION_NUM:-3}"
OUTPUT_DIR="${OUTPUT_DIR:-./sync_results}"

show_help() {
    cat << EOF
用法: $0 <命令> [选项]

命令:
  create-catalog    创建Hive Catalog（支持Kerberos）
  list-databases    列出Hive数据库
  list-tables       列出Hive表
  sync-table        同步单表
  batch-sync        批量同步表

环境变量:
  Doris配置:
    DORIS_HOST          Doris FE地址 (默认: 192.168.1.181)
    DORIS_PORT          Doris FE端口 (默认: 9030)
    DORIS_USER          Doris用户名 (默认: root)
    DORIS_PASSWORD      Doris密码

  Hive配置:
    HIVE_METASTORE      Hive Metastore URI (默认: thrift://hive-metastore:9083)
    HDFS_NAMENODE       HDFS NameNode地址
    CATALOG_NAME        Catalog名称 (默认: hive_catalog)

  Kerberos配置:
    KERBEROS_PRINCIPAL  Kerberos Principal
    KERBEROS_KEYTAB     Keytab文件路径
    KRB5_CONF           krb5.conf路径 (默认: /etc/krb5.conf)
    HIVE_PRINCIPAL      Hive Metastore Principal
    HDFS_PRINCIPAL      HDFS Principal

  同步配置:
    PARALLEL            并行度 (默认: 4)
    REPLICATION_NUM     Doris副本数 (默认: 3)
    OUTPUT_DIR          输出目录 (默认: ./sync_results)

示例:
  # 1. 创建Hive Catalog（带Kerberos）
  export KERBEROS_PRINCIPAL="hive@REALM.COM"
  export KERBEROS_KEYTAB="/etc/security/keytabs/hive.keytab"
  $0 create-catalog

  # 2. 列出Hive数据库
  $0 list-databases

  # 3. 列出Hive表
  $0 list-tables --hive-db default

  # 4. 同步单表
  $0 sync-table --hive-db default --hive-table test_table --doris-db doris_db

  # 5. 批量同步（先编辑tables_to_sync.txt）
  $0 batch-sync

EOF
}

check_python() {
    if ! command -v python3 &> /dev/null; then
        echo "错误: 未找到 python3"
        exit 1
    fi
    
    if ! python3 -c "import pymysql" 2>/dev/null; then
        echo "错误: 需要安装 pymysql"
        echo "请运行: pip install pymysql"
        exit 1
    fi
}

build_common_args() {
    args="--doris-host ${DORIS_HOST} --doris-port ${DORIS_PORT} --doris-user ${DORIS_USER}"
    if [ -n "${DORIS_PASSWORD}" ]; then
        args="${args} --doris-password ${DORIS_PASSWORD}"
    fi
    echo "${args}"
}

build_catalog_args() {
    args="--catalog-name ${CATALOG_NAME} --hive-metastore ${HIVE_METASTORE}"
    if [ -n "${HDFS_NAMENODE}" ]; then
        args="${args} --hdfs-namenode ${HDFS_NAMENODE}"
    fi
    echo "${args}"
}

build_kerberos_args() {
    args=""
    if [ -n "${KERBEROS_PRINCIPAL}" ]; then
        args="--kerberos-principal ${KERBEROS_PRINCIPAL}"
    fi
    if [ -n "${KERBEROS_KEYTAB}" ]; then
        args="${args} --kerberos-keytab ${KERBEROS_KEYTAB}"
    fi
    if [ -n "${KRB5_CONF}" ]; then
        args="${args} --krb5-conf ${KRB5_CONF}"
    fi
    if [ -n "${HIVE_PRINCIPAL}" ]; then
        args="${args} --hive-principal ${HIVE_PRINCIPAL}"
    fi
    if [ -n "${HDFS_PRINCIPAL}" ]; then
        args="${args} --hdfs-principal ${HDFS_PRINCIPAL}"
    fi
    echo "${args}"
}

create_catalog() {
    echo "=========================================="
    echo "创建Hive Catalog: ${CATALOG_NAME}"
    echo "=========================================="
    
    common_args=$(build_common_args)
    catalog_args=$(build_catalog_args)
    kerberos_args=$(build_kerberos_args)
    
    python3 "${PYTHON_SCRIPT}" create-catalog ${common_args} ${catalog_args} ${kerberos_args}
}

list_databases() {
    echo "=========================================="
    echo "列出Hive数据库"
    echo "=========================================="
    
    common_args=$(build_common_args)
    
    python3 "${PYTHON_SCRIPT}" list-databases ${common_args} --catalog-name ${CATALOG_NAME}
}

list_tables() {
    local hive_db="$1"
    
    if [ -z "${hive_db}" ]; then
        echo "错误: 需要指定 --hive-db"
        exit 1
    fi
    
    echo "=========================================="
    echo "列出Hive表: ${hive_db}"
    echo "=========================================="
    
    common_args=$(build_common_args)
    
    python3 "${PYTHON_SCRIPT}" list-tables ${common_args} --catalog-name ${CATALOG_NAME} --hive-db "${hive_db}"
}

sync_table() {
    local hive_db=""
    local hive_table=""
    local doris_db=""
    local doris_table=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --hive-db)
                hive_db="$2"
                shift 2
                ;;
            --hive-table)
                hive_table="$2"
                shift 2
                ;;
            --doris-db)
                doris_db="$2"
                shift 2
                ;;
            --doris-table)
                doris_table="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
    
    if [ -z "${hive_db}" ] || [ -z "${hive_table}" ] || [ -z "${doris_db}" ]; then
        echo "错误: 需要指定 --hive-db, --hive-table, --doris-db"
        exit 1
    fi
    
    echo "=========================================="
    echo "同步表: ${hive_db}.${hive_table} -> ${doris_db}.${doris_table:-$hive_table}"
    echo "=========================================="
    
    common_args=$(build_common_args)
    kerberos_args=$(build_kerberos_args)
    
    cmd="python3 ${PYTHON_SCRIPT} sync-table ${common_args} ${kerberos_args}"
    cmd="${cmd} --catalog-name ${CATALOG_NAME}"
    cmd="${cmd} --hive-db ${hive_db} --hive-table ${hive_table}"
    cmd="${cmd} --doris-db ${doris_db}"
    cmd="${cmd} --replication-num ${REPLICATION_NUM}"
    
    if [ -n "${doris_table}" ]; then
        cmd="${cmd} --doris-table ${doris_table}"
    fi
    
    eval ${cmd}
}

batch_sync() {
    if [ ! -f "${TABLE_FILE}" ]; then
        echo "错误: 表列表文件不存在: ${TABLE_FILE}"
        echo "请先创建表列表文件"
        exit 1
    fi
    
    table_count=$(grep -v '^#' "${TABLE_FILE}" | grep -v '^$' | wc -l)
    
    echo "=========================================="
    echo "批量同步表"
    echo "表列表文件: ${TABLE_FILE}"
    echo "表数量: ${table_count}"
    echo "并行度: ${PARALLEL}"
    echo "副本数: ${REPLICATION_NUM}"
    echo "=========================================="
    
    mkdir -p "${OUTPUT_DIR}"
    
    timestamp=$(date +"%Y%m%d_%H%M%S")
    output_file="${OUTPUT_DIR}/sync_result_${timestamp}.txt"
    
    common_args=$(build_common_args)
    kerberos_args=$(build_kerberos_args)
    
    python3 "${PYTHON_SCRIPT}" batch-sync ${common_args} ${kerberos_args} \
        --catalog-name ${CATALOG_NAME} \
        --table-file "${TABLE_FILE}" \
        --parallel ${PARALLEL} \
        --replication-num ${REPLICATION_NUM} \
        --output "${output_file}"
    
    echo ""
    echo "同步结果已保存到: ${output_file}"
}

if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

check_python

ACTION="$1"
shift

case "${ACTION}" in
    -h|--help)
        show_help
        ;;
    create-catalog)
        create_catalog
        ;;
    list-databases)
        list_databases
        ;;
    list-tables)
        list_tables "$@"
        ;;
    sync-table)
        sync_table "$@"
        ;;
    batch-sync)
        batch_sync
        ;;
    *)
        echo "未知命令: ${ACTION}"
        show_help
        exit 1
        ;;
esac
