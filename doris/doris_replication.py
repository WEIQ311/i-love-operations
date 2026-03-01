#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Doris表副本数检测和修改工具
支持检测副本数为1的表，以及修改表的副本数
"""

import sys
import argparse
import re
from datetime import datetime
from typing import List, Tuple, Optional

try:
    import pymysql
except ImportError:
    print("错误: 需要安装 pymysql 库")
    print("请运行: pip install pymysql")
    sys.exit(1)


def connect_doris(host: str, port: int, user: str, password: str) -> pymysql.Connection:
    """连接Doris数据库"""
    try:
        conn = pymysql.connect(
            host=host,
            port=port,
            user=user,
            password=password,
            charset='utf8mb4',
            connect_timeout=10
        )
        return conn
    except Exception as e:
        print(f"连接Doris数据库失败: {e}")
        sys.exit(1)


def get_all_databases(conn: pymysql.Connection) -> List[str]:
    """获取所有数据库列表"""
    try:
        with conn.cursor() as cursor:
            cursor.execute("SHOW DATABASES")
            databases = [row[0] for row in cursor.fetchall()]
            exclude_dbs = ['information_schema', 'sys', '__internal_schema']
            databases = [db for db in databases if db not in exclude_dbs]
            return databases
    except Exception as e:
        print(f"获取数据库列表失败: {e}")
        return []


def get_tables_with_replication_one(conn: pymysql.Connection, database: str) -> List[Tuple[str, str]]:
    """获取指定数据库中副本数为1的表"""
    tables_with_repl_one = []
    try:
        conn.select_db(database)
        with conn.cursor() as cursor:
            cursor.execute("SHOW TABLES")
            tables = [row[0] for row in cursor.fetchall()]
            
            for table in tables:
                try:
                    cursor.execute(f"SHOW CREATE TABLE `{table}`")
                    result = cursor.fetchone()
                    if result:
                        create_sql = result[1]
                        if '"replication_num" = "1"' in create_sql or "'replication_num' = '1'" in create_sql:
                            tables_with_repl_one.append((database, table))
                        elif '"replication_num" = 1' in create_sql or "'replication_num' = 1" in create_sql:
                            tables_with_repl_one.append((database, table))
                except Exception as e:
                    continue
    except Exception as e:
        pass
    return tables_with_repl_one


def parse_table_file(file_path: str) -> List[Tuple[str, str]]:
    """从文件中解析表列表"""
    tables = []
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#') or line.startswith('库名') or line.startswith('-'):
                    continue
                parts = re.split(r'\s+', line)
                if len(parts) >= 2:
                    tables.append((parts[0], parts[1]))
    except FileNotFoundError:
        print(f"错误: 文件 '{file_path}' 不存在")
        sys.exit(1)
    except Exception as e:
        print(f"读取文件失败: {e}")
        sys.exit(1)
    return tables


def alter_table_replication(conn: pymysql.Connection, db_name: str, table_name: str, replication_num: int) -> Tuple[bool, str]:
    """修改表的副本数"""
    try:
        conn.select_db(db_name)
        with conn.cursor() as cursor:
            sql = f"ALTER TABLE `{table_name}` SET (\"replication_num\" = \"{replication_num}\")"
            cursor.execute(sql)
            conn.commit()
            return True, "成功"
    except Exception as e:
        try:
            conn.rollback()
        except:
            pass
        return False, str(e)


def main():
    parser = argparse.ArgumentParser(
        description='Doris表副本数检测和修改工具',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  # 检测副本数为1的表
  python doris_replication.py check -H 192.168.1.181 -P 9030 -u root -p root
  
  # 检测并直接修改为3
  python doris_replication.py check -H 192.168.1.181 -P 9030 -u root -p root --alter 3
  
  # 从文件读取表列表并修改副本数为3
  python doris_replication.py alter -H 192.168.1.181 -P 9030 -u root -p root -f tables.txt -n 3
  
  # 修改单个表
  python doris_replication.py alter -H 192.168.1.181 -P 9030 -u root -p root -d test_db -t table1 -n 3
        """
    )
    
    subparsers = parser.add_subparsers(dest='action', help='操作类型')
    
    # 检测命令
    check_parser = subparsers.add_parser('check', help='检测副本数为1的表')
    check_parser.add_argument('-H', '--host', default='localhost', help='Doris FE节点地址')
    check_parser.add_argument('-P', '--port', type=int, default=9030, help='Doris FE查询端口')
    check_parser.add_argument('-u', '--user', default='root', help='用户名')
    check_parser.add_argument('-p', '--password', default='', help='密码')
    check_parser.add_argument('-o', '--output', default='', help='输出文件名')
    check_parser.add_argument('--alter', type=int, metavar='NUM', help='检测后直接修改为指定副本数')
    
    # 修改命令
    alter_parser = subparsers.add_parser('alter', help='修改表的副本数')
    alter_parser.add_argument('-H', '--host', default='localhost', help='Doris FE节点地址')
    alter_parser.add_argument('-P', '--port', type=int, default=9030, help='Doris FE查询端口')
    alter_parser.add_argument('-u', '--user', default='root', help='用户名')
    alter_parser.add_argument('-p', '--password', default='', help='密码')
    alter_parser.add_argument('-n', '--replication-num', type=int, required=True, help='目标副本数')
    alter_parser.add_argument('-f', '--file', help='包含表列表的文件路径')
    alter_parser.add_argument('-d', '--database', help='数据库名')
    alter_parser.add_argument('-t', '--table', help='表名')
    alter_parser.add_argument('--all-tables', action='store_true', help='修改指定数据库下所有表')
    alter_parser.add_argument('-o', '--output', default='', help='结果输出文件')
    alter_parser.add_argument('--dry-run', action='store_true', help='仅显示SQL，不实际执行')
    
    args = parser.parse_args()
    
    if not args.action:
        parser.print_help()
        sys.exit(1)
    
    # 执行检测操作
    if args.action == 'check':
        print(f"正在连接Doris数据库 {args.host}:{args.port}...")
        conn = connect_doris(args.host, args.port, args.user, args.password)
        print("连接成功!")
        
        print("\n正在获取数据库列表...")
        databases = get_all_databases(conn)
        print(f"找到 {len(databases)} 个数据库")
        
        print("\n正在检测所有表的副本数...")
        all_tables_with_repl_one = []
        for db in databases:
            print(f"  检查数据库: {db}")
            tables = get_tables_with_replication_one(conn, db)
            if tables:
                print(f"    找到 {len(tables)} 个副本数为1的表")
                all_tables_with_repl_one.extend(tables)
        
        # 生成输出文件名
        if not args.output:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_file = f"doris_replication_one_tables_{timestamp}.txt"
        else:
            output_file = args.output
        
        # 写入检测结果
        print(f"\n正在写入结果到文件: {output_file}")
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(f"# Doris数据库副本数为1的表检测结果\n")
            f.write(f"# 检测时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"# 数据库地址: {args.host}:{args.port}\n")
            f.write(f"# 共找到 {len(all_tables_with_repl_one)} 个副本数为1的表\n")
            f.write(f"# {'='*60}\n\n")
            if all_tables_with_repl_one:
                f.write("库名\t表名\n")
                f.write("-" * 60 + "\n")
                for db_name, table_name in sorted(all_tables_with_repl_one):
                    f.write(f"{db_name}\t{table_name}\n")
            else:
                f.write("未找到副本数为1的表\n")
        
        print(f"\n检测完成! 共找到 {len(all_tables_with_repl_one)} 个副本数为1的表")
        print(f"结果已保存到: {output_file}")
        
        # 如果指定了--alter，直接修改
        if args.alter and all_tables_with_repl_one:
            print(f"\n开始修改表的副本数为 {args.alter}...")
            success_count = 0
            fail_count = 0
            
            for i, (db_name, table_name) in enumerate(all_tables_with_repl_one, 1):
                print(f"[{i}/{len(all_tables_with_repl_one)}] 处理 {db_name}.{table_name}...", end=' ')
                success, message = alter_table_replication(conn, db_name, table_name, args.alter)
                if success:
                    print("✓ 成功")
                    success_count += 1
                else:
                    print(f"✗ 失败: {message}")
                    fail_count += 1
            
            print(f"\n修改完成! 成功: {success_count}, 失败: {fail_count}")
        
        conn.close()
    
    # 执行修改操作
    elif args.action == 'alter':
        # 准备表列表
        if args.file:
            tables = parse_table_file(args.file)
            print(f"从文件 '{args.file}' 读取到 {len(tables)} 个表")
        elif args.database and args.table:
            tables = [(args.database, args.table)]
        elif args.database and args.all_tables:
            conn = connect_doris(args.host, args.port, args.user, args.password)
            try:
                conn.select_db(args.database)
                with conn.cursor() as cursor:
                    cursor.execute("SHOW TABLES")
                    tables = [(args.database, row[0]) for row in cursor.fetchall()]
                print(f"找到 {len(tables)} 个表")
            except Exception as e:
                print(f"获取表列表失败: {e}")
                conn.close()
                sys.exit(1)
            conn.close()
        else:
            print("错误: 必须指定 -f/--file, -d/-t, 或 -d/--all-tables")
            sys.exit(1)
        
        if not args.output:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_file = f"alter_replication_result_{timestamp}.txt"
        else:
            output_file = args.output
        
        print(f"\n正在连接Doris数据库 {args.host}:{args.port}...")
        conn = connect_doris(args.host, args.port, args.user, args.password)
        print("连接成功!")
        
        print(f"\n开始修改表的副本数为 {args.replication_num}...")
        print(f"共需要处理 {len(tables)} 个表\n")
        
        success_count = 0
        fail_count = 0
        results = []
        
        for i, (db_name, table_name) in enumerate(tables, 1):
            print(f"[{i}/{len(tables)}] 处理 {db_name}.{table_name}...", end=' ')
            
            if args.dry_run:
                sql = f"ALTER TABLE `{table_name}` SET (\"replication_num\" = \"{args.replication_num}\")"
                print(f"\n  SQL: {sql}")
                results.append((db_name, table_name, True, "DRY-RUN", sql))
                success_count += 1
            else:
                success, message = alter_table_replication(conn, db_name, table_name, args.replication_num)
                if success:
                    print("✓ 成功")
                    success_count += 1
                    results.append((db_name, table_name, True, "成功", ""))
                else:
                    print(f"✗ 失败: {message}")
                    fail_count += 1
                    results.append((db_name, table_name, False, "失败", message))
        
        conn.close()
        
        # 写入结果文件
        print(f"\n正在写入结果到文件: {output_file}")
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(f"# Doris表副本数修改结果\n")
            f.write(f"# 修改时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"# 数据库地址: {args.host}:{args.port}\n")
            f.write(f"# 目标副本数: {args.replication_num}\n")
            f.write(f"# 共处理: {len(tables)} 个表\n")
            f.write(f"# 成功: {success_count} 个\n")
            f.write(f"# 失败: {fail_count} 个\n")
            f.write(f"# {'='*60}\n\n")
            
            if args.dry_run:
                f.write("库名\t表名\t状态\tSQL语句\n")
                f.write("-" * 80 + "\n")
                for db_name, table_name, success, status, sql in results:
                    f.write(f"{db_name}\t{table_name}\t{status}\t{sql}\n")
            else:
                f.write("库名\t表名\t状态\t错误信息\n")
                f.write("-" * 80 + "\n")
                for db_name, table_name, success, status, message in results:
                    error_info = message if message else "-"
                    f.write(f"{db_name}\t{table_name}\t{status}\t{error_info}\n")
        
        print(f"\n修改完成! 成功: {success_count}, 失败: {fail_count}")
        if args.dry_run:
            print("注意: 这是DRY-RUN模式，未实际执行修改")
        print(f"结果已保存到: {output_file}")


if __name__ == '__main__':
    main()
