#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Hive(Kerberos) 到 Doris 数据同步工具
支持：
1. 自动创建Doris Catalog（支持Kerberos认证）
2. 自动同步表结构
3. 批量数据同步
4. 增量同步（按分区）
"""

import sys
import os
import argparse
import subprocess
import json
import time
import re
from datetime import datetime
from typing import List, Dict, Tuple, Optional
from concurrent.futures import ThreadPoolExecutor, as_completed
import threading

try:
    import pymysql
except ImportError:
    print("错误: 需要安装 pymysql 库")
    print("请运行: pip install pymysql")
    sys.exit(1)


class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'


def print_info(msg: str):
    print(f"{Colors.OKBLUE}[INFO]{Colors.ENDC} {msg}")


def print_success(msg: str):
    print(f"{Colors.OKGREEN}[SUCCESS]{Colors.ENDC} {msg}")


def print_warning(msg: str):
    print(f"{Colors.WARNING}[WARNING]{Colors.ENDC} {msg}")


def print_error(msg: str):
    print(f"{Colors.FAIL}[ERROR]{Colors.ENDC} {msg}")


class HiveToDorisSync:
    """Hive到Doris同步工具主类"""
    
    HIVE_TO_DORIS_TYPE_MAP = {
        'tinyint': 'TINYINT',
        'smallint': 'SMALLINT',
        'int': 'INT',
        'integer': 'INT',
        'bigint': 'BIGINT',
        'float': 'FLOAT',
        'double': 'DOUBLE',
        'decimal': 'DECIMAL',
        'numeric': 'DECIMAL',
        'string': 'STRING',
        'varchar': 'VARCHAR',
        'char': 'CHAR',
        'boolean': 'BOOLEAN',
        'date': 'DATE',
        'timestamp': 'DATETIME',
        'datetime': 'DATETIME',
        'binary': 'STRING',
        'array': 'STRING',
        'map': 'STRING',
        'struct': 'STRING',
    }
    
    def __init__(self, doris_config: Dict, hive_config: Dict, kerberos_config: Dict = None):
        self.doris_config = doris_config
        self.hive_config = hive_config
        self.kerberos_config = kerberos_config
        self.doris_conn = None
        self.catalog_name = hive_config.get('catalog_name', 'hive_catalog')
        self._lock = threading.Lock()
        
    def connect_doris(self) -> bool:
        """连接Doris数据库"""
        try:
            self.doris_conn = pymysql.connect(
                host=self.doris_config['host'],
                port=self.doris_config['port'],
                user=self.doris_config['user'],
                password=self.doris_config.get('password', ''),
                charset='utf8mb4',
                connect_timeout=30
            )
            print_success(f"成功连接Doris: {self.doris_config['host']}:{self.doris_config['port']}")
            return True
        except Exception as e:
            print_error(f"连接Doris失败: {e}")
            return False
    
    def close(self):
        """关闭连接"""
        if self.doris_conn:
            self.doris_conn.close()
    
    def execute_sql(self, sql: str, fetch: bool = False) -> Tuple[bool, any]:
        """执行SQL语句"""
        try:
            with self._lock:
                with self.doris_conn.cursor() as cursor:
                    cursor.execute(sql)
                    if fetch:
                        return True, cursor.fetchall()
                    self.doris_conn.commit()
                    return True, None
        except Exception as e:
            return False, str(e)
    
    def init_kerberos(self) -> bool:
        """初始化Kerberos认证"""
        if not self.kerberos_config:
            return True
            
        try:
            principal = self.kerberos_config.get('principal')
            keytab = self.kerberos_config.get('keytab')
            krb5_conf = self.kerberos_config.get('krb5_conf', '/etc/krb5.conf')
            
            if krb5_conf and os.path.exists(krb5_conf):
                os.environ['KRB5_CONFIG'] = krb5_conf
            
            if principal and keytab:
                cmd = f"kinit -kt {keytab} {principal}"
                result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
                if result.returncode != 0:
                    print_error(f"Kerberos认证失败: {result.stderr}")
                    return False
                print_success(f"Kerberos认证成功: {principal}")
            return True
        except Exception as e:
            print_error(f"Kerberos认证异常: {e}")
            return False
    
    def create_hive_catalog(self) -> bool:
        """创建Hive Catalog（支持Kerberos）"""
        print_info(f"创建Hive Catalog: {self.catalog_name}")
        
        hive_metastore_uris = self.hive_config.get('metastore_uris', '')
        hdfs_namenode = self.hive_config.get('hdfs_namenode', '')
        
        catalog_props = {
            'type': 'hms',
            'hive.metastore.uris': hive_metastore_uris,
        }
        
        if hdfs_namenode:
            catalog_props['hadoop.username'] = self.hive_config.get('hadoop_user', 'hive')
        
        if self.kerberos_config:
            catalog_props.update({
                'authentication': 'kerberos',
                'hive.metastore.kerberos.principal': self.kerberos_config.get('hive_principal', ''),
                'hive.metastore.kerberos.keytab': self.kerberos_config.get('keytab', ''),
                'hdfs.kerberos.principal': self.kerberos_config.get('hdfs_principal', ''),
                'hdfs.kerberos.keytab': self.kerberos_config.get('keytab', ''),
            })
        
        drop_sql = f"DROP CATALOG IF EXISTS {self.catalog_name}"
        self.execute_sql(drop_sql)
        
        props_str = ', '.join([f"'{k}' = '{v}'" for k, v in catalog_props.items()])
        create_sql = f"CREATE CATALOG {self.catalog_name} PROPERTIES ({props_str})"
        
        success, err = self.execute_sql(create_sql)
        if success:
            print_success(f"Hive Catalog创建成功: {self.catalog_name}")
            return True
        else:
            print_error(f"Hive Catalog创建失败: {err}")
            return False
    
    def get_hive_databases(self) -> List[str]:
        """获取Hive数据库列表"""
        sql = f"SHOW DATABASES FROM {self.catalog_name}"
        success, result = self.execute_sql(sql, fetch=True)
        if success:
            return [row[0] for row in result]
        return []
    
    def get_hive_tables(self, hive_db: str) -> List[str]:
        """获取Hive数据库中的表列表"""
        sql = f"SHOW TABLES FROM {self.catalog_name}.{hive_db}"
        success, result = self.execute_sql(sql, fetch=True)
        if success:
            return [row[0] for row in result]
        return []
    
    def get_hive_table_schema(self, hive_db: str, hive_table: str) -> Tuple[bool, str]:
        """获取Hive表的建表语句"""
        sql = f"SHOW CREATE TABLE {self.catalog_name}.{hive_db}.{hive_table}"
        success, result = self.execute_sql(sql, fetch=True)
        if success and result:
            return True, result[0][1]
        return False, ""
    
    def convert_hive_type_to_doris(self, hive_type: str) -> str:
        """将Hive类型转换为Doris类型"""
        hive_type_lower = hive_type.lower().strip()
        
        if hive_type_lower.startswith('decimal') or hive_type_lower.startswith('numeric'):
            match = re.match(r'(?:decimal|numeric)\((\d+),\s*(\d+)\)', hive_type_lower)
            if match:
                return f"DECIMAL({match.group(1)}, {match.group(2)})"
            return "DECIMAL(38, 18)"
        
        if hive_type_lower.startswith('varchar'):
            match = re.match(r'varchar\((\d+)\)', hive_type_lower)
            if match:
                length = int(match.group(1))
                if length > 65533:
                    return "STRING"
                return f"VARCHAR({length})"
            return "VARCHAR(65533)"
        
        if hive_type_lower.startswith('char'):
            match = re.match(r'char\((\d+)\)', hive_type_lower)
            if match:
                length = int(match.group(1))
                return f"CHAR({length})"
            return "CHAR(255)"
        
        if hive_type_lower.startswith('array') or hive_type_lower.startswith('map') or hive_type_lower.startswith('struct'):
            return "STRING"
        
        return self.HIVE_TO_DORIS_TYPE_MAP.get(hive_type_lower, 'STRING')
    
    def get_hive_table_columns(self, hive_db: str, hive_table: str) -> List[Dict]:
        """获取Hive表的列信息"""
        sql = f"DESC {self.catalog_name}.{hive_db}.{hive_table}"
        success, result = self.execute_sql(sql, fetch=True)
        
        columns = []
        if success:
            for row in result:
                col_name = row[0]
                col_type = row[1]
                if col_name and not col_name.startswith('#'):
                    doris_type = self.convert_hive_type_to_doris(col_type)
                    columns.append({
                        'name': col_name,
                        'hive_type': col_type,
                        'doris_type': doris_type
                    })
        return columns
    
    def get_hive_table_partitions(self, hive_db: str, hive_table: str) -> List[Dict]:
        """获取Hive表的分区信息"""
        sql = f"SHOW PARTITIONS FROM {self.catalog_name}.{hive_db}.{hive_table}"
        success, result = self.execute_sql(sql, fetch=True)
        
        partitions = []
        if success:
            for row in result:
                if row:
                    partitions.append({'partition_spec': row[0]})
        return partitions
    
    def create_doris_database(self, doris_db: str) -> bool:
        """创建Doris数据库"""
        sql = f"CREATE DATABASE IF NOT EXISTS `{doris_db}`"
        success, err = self.execute_sql(sql)
        return success
    
    def generate_doris_create_table_sql(self, hive_db: str, hive_table: str, 
                                         doris_db: str, doris_table: str,
                                         replication_num: int = 3,
                                         primary_keys: List[str] = None,
                                         partition_cols: List[str] = None) -> str:
        """生成Doris建表SQL"""
        columns = self.get_hive_table_columns(hive_db, hive_table)
        
        if not columns:
            return ""
        
        col_defs = []
        for col in columns:
            col_defs.append(f"`{col['name']}` {col['doris_type']}")
        
        col_str = ",\n    ".join(col_defs)
        
        if primary_keys:
            pk_str = ", ".join([f"`{k}`" for k in primary_keys])
            table_type = "UNIQUE KEY"
            key_clause = f"{table_type}({pk_str})"
        else:
            key_clause = "DUPLICATE KEY"
        
        partition_clause = ""
        if partition_cols:
            pass
        
        create_sql = f"""CREATE TABLE IF NOT EXISTS `{doris_db}`.`{doris_table}` (
    {col_str}
) ENGINE=OLAP
{key_clause}
PARTITION BY RANGE(`{partition_cols[0] if partition_cols else columns[0]['name']}`) ()
DISTRIBUTED BY HASH(`{columns[0]['name']}`) BUCKETS AUTO
PROPERTIES (
    "replication_num" = "{replication_num}",
    "enable_unique_key_merge_on_write" = "true"
)"""
        return create_sql
    
    def create_doris_table_like_hive(self, hive_db: str, hive_table: str,
                                      doris_db: str, doris_table: str = None,
                                      replication_num: int = 3) -> Tuple[bool, str]:
        """在Doris中创建与Hive表结构相同的表"""
        if doris_table is None:
            doris_table = hive_table
        
        columns = self.get_hive_table_columns(hive_db, hive_table)
        
        if not columns:
            return False, "无法获取Hive表列信息"
        
        col_defs = []
        for col in columns:
            col_defs.append(f"`{col['name']}` {col['doris_type']}")
        
        col_str = ",\n    ".join(col_defs)
        
        create_sql = f"""CREATE TABLE IF NOT EXISTS `{doris_db}`.`{doris_table}` (
    {col_str}
) ENGINE=OLAP
DUPLICATE KEY(`{columns[0]['name']}`)
DISTRIBUTED BY HASH(`{columns[0]['name']}`) BUCKETS AUTO
PROPERTIES (
    "replication_num" = "{replication_num}"
)"""
        
        success, err = self.execute_sql(create_sql)
        if success:
            return True, create_sql
        return False, err
    
    def sync_table_data(self, hive_db: str, hive_table: str,
                        doris_db: str, doris_table: str = None,
                        columns: List[str] = None,
                        where_clause: str = None) -> Tuple[bool, Dict]:
        """同步单表数据"""
        if doris_table is None:
            doris_table = hive_table
        
        print_info(f"开始同步数据: {hive_db}.{hive_table} -> {doris_db}.{doris_table}")
        
        if columns:
            col_str = ", ".join([f"`{c}`" for c in columns])
        else:
            col_str = "*"
        
        sql = f"""INSERT INTO `{doris_db}`.`{doris_table}` ({col_str})
SELECT {col_str} FROM {self.catalog_name}.{hive_db}.{hive_table}"""
        
        if where_clause:
            sql += f" WHERE {where_clause}"
        
        start_time = time.time()
        success, err = self.execute_sql(sql)
        elapsed = time.time() - start_time
        
        result = {
            'hive_db': hive_db,
            'hive_table': hive_table,
            'doris_db': doris_db,
            'doris_table': doris_table,
            'success': success,
            'elapsed': elapsed,
            'error': err if not success else None
        }
        
        if success:
            print_success(f"数据同步完成: {hive_db}.{hive_table} -> {doris_db}.{doris_table} (耗时: {elapsed:.2f}秒)")
        else:
            print_error(f"数据同步失败: {hive_db}.{hive_table} -> {doris_db}.{doris_table}, 错误: {err}")
        
        return success, result
    
    def sync_table_data_by_partition(self, hive_db: str, hive_table: str,
                                      doris_db: str, doris_table: str = None,
                                      partition_col: str = None,
                                      partition_values: List[str] = None) -> Tuple[bool, List[Dict]]:
        """按分区同步数据（增量同步）"""
        if doris_table is None:
            doris_table = hive_table
        
        print_info(f"开始分区同步: {hive_db}.{hive_table}")
        
        results = []
        
        if not partition_values:
            partitions = self.get_hive_table_partitions(hive_db, hive_table)
            partition_values = [p['partition_spec'] for p in partitions]
        
        if not partition_values:
            print_warning(f"未找到分区信息，执行全量同步")
            return self.sync_table_data(hive_db, hive_table, doris_db, doris_table)
        
        for partition_value in partition_values:
            where_clause = f"`{partition_col}` = '{partition_value}'"
            success, result = self.sync_table_data(
                hive_db, hive_table, doris_db, doris_table,
                where_clause=where_clause
            )
            results.append(result)
        
        all_success = all(r['success'] for r in results)
        return all_success, results
    
    def get_table_row_count(self, db: str, table: str, from_hive: bool = False) -> int:
        """获取表行数"""
        if from_hive:
            sql = f"SELECT COUNT(*) FROM {self.catalog_name}.{db}.{table}"
        else:
            sql = f"SELECT COUNT(*) FROM `{db}`.`{table}`"
        
        success, result = self.execute_sql(sql, fetch=True)
        if success and result:
            return result[0][0]
        return -1
    
    def verify_data(self, hive_db: str, hive_table: str,
                    doris_db: str, doris_table: str = None) -> Tuple[bool, Dict]:
        """验证数据一致性"""
        if doris_table is None:
            doris_table = hive_table
        
        print_info(f"验证数据一致性: {hive_db}.{hive_table} <-> {doris_db}.{doris_table}")
        
        hive_count = self.get_table_row_count(hive_db, hive_table, from_hive=True)
        doris_count = self.get_table_row_count(doris_db, doris_table, from_hive=False)
        
        result = {
            'hive_count': hive_count,
            'doris_count': doris_count,
            'match': hive_count == doris_count
        }
        
        if hive_count == doris_count:
            print_success(f"数据验证通过: Hive({hive_count}) = Doris({doris_count})")
        else:
            print_warning(f"数据不一致: Hive({hive_count}) != Doris({doris_count})")
        
        return result['match'], result
    
    def batch_sync_tables(self, table_list: List[Dict], 
                          parallel: int = 1,
                          create_table: bool = True,
                          verify: bool = True,
                          replication_num: int = 3) -> Dict:
        """批量同步多表"""
        print_info(f"开始批量同步 {len(table_list)} 张表, 并行度: {parallel}")
        
        results = {
            'total': len(table_list),
            'success': 0,
            'failed': 0,
            'skipped': 0,
            'details': []
        }
        
        def sync_single_table(table_info: Dict) -> Dict:
            hive_db = table_info['hive_db']
            hive_table = table_info['hive_table']
            doris_db = table_info.get('doris_db', hive_db)
            doris_table = table_info.get('doris_table', hive_table)
            
            detail = {
                'hive_db': hive_db,
                'hive_table': hive_table,
                'doris_db': doris_db,
                'doris_table': doris_table,
                'status': 'pending',
                'message': ''
            }
            
            try:
                if create_table:
                    success, msg = self.create_doris_table_like_hive(
                        hive_db, hive_table, doris_db, doris_table, replication_num
                    )
                    if not success:
                        detail['status'] = 'failed'
                        detail['message'] = f"建表失败: {msg}"
                        return detail
                
                success, sync_result = self.sync_table_data(
                    hive_db, hive_table, doris_db, doris_table
                )
                
                if success:
                    if verify:
                        match, verify_result = self.verify_data(
                            hive_db, hive_table, doris_db, doris_table
                        )
                        if match:
                            detail['status'] = 'success'
                            detail['message'] = '同步并验证成功'
                        else:
                            detail['status'] = 'warning'
                            detail['message'] = f"同步成功但数据不一致: Hive({verify_result['hive_count']}) != Doris({verify_result['doris_count']})"
                    else:
                        detail['status'] = 'success'
                        detail['message'] = '同步成功'
                else:
                    detail['status'] = 'failed'
                    detail['message'] = sync_result.get('error', '未知错误')
                    
            except Exception as e:
                detail['status'] = 'failed'
                detail['message'] = str(e)
            
            return detail
        
        if parallel > 1:
            with ThreadPoolExecutor(max_workers=parallel) as executor:
                futures = {executor.submit(sync_single_table, t): t for t in table_list}
                for future in as_completed(futures):
                    detail = future.result()
                    results['details'].append(detail)
                    if detail['status'] == 'success':
                        results['success'] += 1
                    elif detail['status'] == 'warning':
                        results['success'] += 1
                    else:
                        results['failed'] += 1
        else:
            for table_info in table_list:
                detail = sync_single_table(table_info)
                results['details'].append(detail)
                if detail['status'] == 'success':
                    results['success'] += 1
                elif detail['status'] == 'warning':
                    results['success'] += 1
                else:
                    results['failed'] += 1
        
        print_info(f"批量同步完成: 成功 {results['success']}, 失败 {results['failed']}")
        return results
    
    def export_sync_result(self, results: Dict, output_file: str):
        """导出同步结果"""
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(f"# Hive到Doris同步结果\n")
            f.write(f"# 同步时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"# 总表数: {results['total']}\n")
            f.write(f"# 成功: {results['success']}\n")
            f.write(f"# 失败: {results['failed']}\n")
            f.write(f"# ============================================================\n\n")
            
            f.write("Hive库\tHive表\tDoris库\tDoris表\t状态\t消息\n")
            f.write("-" * 80 + "\n")
            
            for detail in results['details']:
                f.write(f"{detail['hive_db']}\t{detail['hive_table']}\t")
                f.write(f"{detail['doris_db']}\t{detail['doris_table']}\t")
                f.write(f"{detail['status']}\t{detail['message']}\n")
        
        print_success(f"同步结果已导出到: {output_file}")


def parse_table_file(file_path: str) -> List[Dict]:
    """从文件解析表列表"""
    tables = []
    with open(file_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#') or line.startswith('库名') or line.startswith('-'):
                continue
            parts = re.split(r'\s+', line)
            if len(parts) >= 2:
                table_info = {
                    'hive_db': parts[0],
                    'hive_table': parts[1],
                    'doris_db': parts[2] if len(parts) > 2 else parts[0],
                    'doris_table': parts[3] if len(parts) > 3 else parts[1]
                }
                tables.append(table_info)
    return tables


def main():
    parser = argparse.ArgumentParser(
        description='Hive(Kerberos)到Doris数据同步工具',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  # 创建Hive Catalog
  python hive_to_doris_sync.py create-catalog \\
    --doris-host 192.168.1.181 --doris-port 9030 --doris-user root \\
    --hive-metastore "thrift://hive-metastore:9083" \\
    --kerberos-principal "hive@REALM" --kerberos-keytab "/path/to/hive.keytab"
  
  # 同步单表
  python hive_to_doris_sync.py sync-table \\
    --doris-host 192.168.1.181 --doris-port 9030 \\
    --hive-db default --hive-table test_table \\
    --doris-db doris_db
  
  # 批量同步
  python hive_to_doris_sync.py batch-sync \\
    --doris-host 192.168.1.181 --doris-port 9030 \\
    --table-file tables.txt --parallel 4
  
  # 查看Hive数据库列表
  python hive_to_doris_sync.py list-databases \\
    --doris-host 192.168.1.181 --doris-port 9030
        """
    )
    
    subparsers = parser.add_subparsers(dest='action', help='操作类型')
    
    common_parser = argparse.ArgumentParser(add_help=False)
    common_parser.add_argument('--doris-host', required=True, help='Doris FE地址')
    common_parser.add_argument('--doris-port', type=int, default=9030, help='Doris FE查询端口')
    common_parser.add_argument('--doris-user', default='root', help='Doris用户名')
    common_parser.add_argument('--doris-password', default='', help='Doris密码')
    
    catalog_parser = argparse.ArgumentParser(add_help=False)
    catalog_parser.add_argument('--catalog-name', default='hive_catalog', help='Catalog名称')
    catalog_parser.add_argument('--hive-metastore', required=True, help='Hive Metastore URI')
    catalog_parser.add_argument('--hdfs-namenode', help='HDFS NameNode地址')
    catalog_parser.add_argument('--hadoop-user', default='hive', help='Hadoop用户名')
    
    kerberos_parser = argparse.ArgumentParser(add_help=False)
    kerberos_parser.add_argument('--kerberos-principal', help='Kerberos Principal')
    kerberos_parser.add_argument('--kerberos-keytab', help='Kerberos Keytab文件路径')
    kerberos_parser.add_argument('--krb5-conf', default='/etc/krb5.conf', help='krb5.conf路径')
    kerberos_parser.add_argument('--hive-principal', help='Hive Metastore Principal')
    kerberos_parser.add_argument('--hdfs-principal', help='HDFS Principal')
    
    create_catalog_parser = subparsers.add_parser('create-catalog', 
        parents=[common_parser, catalog_parser, kerberos_parser],
        help='创建Hive Catalog')
    
    list_db_parser = subparsers.add_parser('list-databases', 
        parents=[common_parser],
        help='列出Hive数据库')
    list_db_parser.add_argument('--catalog-name', default='hive_catalog', help='Catalog名称')
    
    list_table_parser = subparsers.add_parser('list-tables', 
        parents=[common_parser],
        help='列出Hive表')
    list_table_parser.add_argument('--catalog-name', default='hive_catalog', help='Catalog名称')
    list_table_parser.add_argument('--hive-db', required=True, help='Hive数据库名')
    
    sync_table_parser = subparsers.add_parser('sync-table', 
        parents=[common_parser, kerberos_parser],
        help='同步单表')
    sync_table_parser.add_argument('--catalog-name', default='hive_catalog', help='Catalog名称')
    sync_table_parser.add_argument('--hive-db', required=True, help='Hive数据库名')
    sync_table_parser.add_argument('--hive-table', required=True, help='Hive表名')
    sync_table_parser.add_argument('--doris-db', required=True, help='Doris数据库名')
    sync_table_parser.add_argument('--doris-table', help='Doris表名(默认与Hive表名相同)')
    sync_table_parser.add_argument('--create-table', action='store_true', default=True, help='自动创建Doris表')
    sync_table_parser.add_argument('--verify', action='store_true', default=True, help='验证数据一致性')
    sync_table_parser.add_argument('--replication-num', type=int, default=3, help='Doris表副本数')
    
    batch_sync_parser = subparsers.add_parser('batch-sync', 
        parents=[common_parser, kerberos_parser],
        help='批量同步表')
    batch_sync_parser.add_argument('--catalog-name', default='hive_catalog', help='Catalog名称')
    batch_sync_parser.add_argument('--table-file', required=True, help='表列表文件')
    batch_sync_parser.add_argument('--parallel', type=int, default=1, help='并行度')
    batch_sync_parser.add_argument('--create-table', action='store_true', default=True, help='自动创建Doris表')
    batch_sync_parser.add_argument('--verify', action='store_true', default=False, help='验证数据一致性')
    batch_sync_parser.add_argument('--replication-num', type=int, default=3, help='Doris表副本数')
    batch_sync_parser.add_argument('--output', help='结果输出文件')
    
    args = parser.parse_args()
    
    if not args.action:
        parser.print_help()
        sys.exit(1)
    
    doris_config = {
        'host': args.doris_host,
        'port': args.doris_port,
        'user': args.doris_user,
        'password': args.doris_password
    }
    
    kerberos_config = None
    if hasattr(args, 'kerberos_principal') and args.kerberos_principal:
        kerberos_config = {
            'principal': args.kerberos_principal,
            'keytab': args.kerberos_keytab,
            'krb5_conf': args.krb5_conf,
            'hive_principal': getattr(args, 'hive_principal', ''),
            'hdfs_principal': getattr(args, 'hdfs_principal', '')
        }
    
    hive_config = {
        'catalog_name': getattr(args, 'catalog_name', 'hive_catalog')
    }
    
    if hasattr(args, 'hive_metastore'):
        hive_config['metastore_uris'] = args.hive_metastore
        hive_config['hdfs_namenode'] = args.hdfs_namenode
        hive_config['hadoop_user'] = args.hadoop_user
    
    sync_tool = HiveToDorisSync(doris_config, hive_config, kerberos_config)
    
    if not sync_tool.connect_doris():
        sys.exit(1)
    
    try:
        if args.action == 'create-catalog':
            if kerberos_config:
                if not sync_tool.init_kerberos():
                    sys.exit(1)
            if not sync_tool.create_hive_catalog():
                sys.exit(1)
                
        elif args.action == 'list-databases':
            databases = sync_tool.get_hive_databases()
            print(f"\nHive数据库列表 (共 {len(databases)} 个):")
            for db in databases:
                print(f"  - {db}")
                
        elif args.action == 'list-tables':
            tables = sync_tool.get_hive_tables(args.hive_db)
            print(f"\n{args.hive_db} 表列表 (共 {len(tables)} 个):")
            for table in tables:
                print(f"  - {table}")
                
        elif args.action == 'sync-table':
            if kerberos_config:
                if not sync_tool.init_kerberos():
                    sys.exit(1)
            
            if args.create_table:
                success, msg = sync_tool.create_doris_table_like_hive(
                    args.hive_db, args.hive_table, 
                    args.doris_db, args.doris_table,
                    args.replication_num
                )
                if not success:
                    print_error(f"建表失败: {msg}")
                    sys.exit(1)
            
            success, result = sync_tool.sync_table_data(
                args.hive_db, args.hive_table,
                args.doris_db, args.doris_table
            )
            
            if success and args.verify:
                sync_tool.verify_data(
                    args.hive_db, args.hive_table,
                    args.doris_db, args.doris_table
                )
                
        elif args.action == 'batch-sync':
            if kerberos_config:
                if not sync_tool.init_kerberos():
                    sys.exit(1)
            
            table_list = parse_table_file(args.table_file)
            if not table_list:
                print_error(f"表列表文件为空或格式错误: {args.table_file}")
                sys.exit(1)
            
            results = sync_tool.batch_sync_tables(
                table_list,
                parallel=args.parallel,
                create_table=args.create_table,
                verify=args.verify,
                replication_num=args.replication_num
            )
            
            output_file = args.output
            if not output_file:
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                output_file = f"hive_to_doris_sync_result_{timestamp}.txt"
            
            sync_tool.export_sync_result(results, output_file)
            
    finally:
        sync_tool.close()


if __name__ == '__main__':
    main()
