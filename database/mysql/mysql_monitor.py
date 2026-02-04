#!/usr/bin/env python3
import os
import time
import json
import pymysql
from dotenv import load_dotenv

# 加载配置文件
load_dotenv()

# 数据库配置
MYSQL_HOST = os.getenv('MYSQL_HOST', 'localhost')
MYSQL_PORT = int(os.getenv('MYSQL_PORT', 3306))
MYSQL_USER = os.getenv('MYSQL_USER', 'root')
MYSQL_PASSWORD = os.getenv('MYSQL_PASSWORD', '')
MYSQL_DATABASE = os.getenv('MYSQL_DATABASE', 'information_schema')

# 监控阈值
MAX_CONNECTIONS_THRESHOLD = int(os.getenv('MAX_CONNECTIONS_THRESHOLD', 80))
MAX_QPS_THRESHOLD = int(os.getenv('MAX_QPS_THRESHOLD', 1000))
SLOW_QUERY_THRESHOLD = float(os.getenv('SLOW_QUERY_THRESHOLD', 1))
CACHE_HIT_RATE_THRESHOLD = float(os.getenv('CACHE_HIT_RATE_THRESHOLD', 90))
TABLESPACE_USAGE_THRESHOLD = float(os.getenv('TABLESPACE_USAGE_THRESHOLD', 80))

# 监控间隔
MONITOR_INTERVAL = int(os.getenv('MONITOR_INTERVAL', 60))

# 告警配置
ALERT_ENABLED = os.getenv('ALERT_ENABLED', 'true').lower() == 'true'
ALERT_EMAIL = os.getenv('ALERT_EMAIL', 'admin@example.com')

class MySQLMonitor:
    def __init__(self, config=None):
        self.conn = None
        self.cursor = None
        # 使用传入的配置或环境变量
        self.config = config or {}
        self.host = self.config.get('host', MYSQL_HOST)
        self.port = self.config.get('port', MYSQL_PORT)
        self.user = self.config.get('user', MYSQL_USER)
        self.password = self.config.get('password', MYSQL_PASSWORD)
        self.database = self.config.get('database', MYSQL_DATABASE)
    
    def connect(self):
        """连接到MySQL数据库"""
        try:
            self.conn = pymysql.connect(
                host=self.host,
                port=self.port,
                user=self.user,
                password=self.password,
                database=self.database,
                charset='utf8mb4',
                cursorclass=pymysql.cursors.DictCursor
            )
            self.cursor = self.conn.cursor()
            print(f"[INFO] 成功连接到MySQL数据库: {self.host}:{self.port}")
            return True
        except Exception as e:
            print(f"[ERROR] 连接MySQL数据库失败: {e}")
            return False
    
    def disconnect(self):
        """断开数据库连接"""
        if self.cursor:
            self.cursor.close()
        if self.conn:
            self.conn.close()
        print("[INFO] 数据库连接已断开")
    
    def get_connection_status(self):
        """获取连接状态"""
        try:
            self.cursor.execute("SELECT 1")
            result = self.cursor.fetchone()
            return result is not None
        except Exception as e:
            print(f"[ERROR] 检查连接状态失败: {e}")
            return False
    
    def get_connection_stats(self):
        """获取连接统计信息"""
        try:
            self.cursor.execute("""
                SHOW GLOBAL STATUS LIKE 'Threads%';
            """)
            threads = {}
            for row in self.cursor.fetchall():
                threads[row['Variable_name']] = row['Value']
            
            self.cursor.execute("""
                SHOW GLOBAL VARIABLES LIKE 'max_connections';
            """)
            max_connections = int(self.cursor.fetchone()['Value'])
            
            current_connections = int(threads.get('Threads_connected', 0))
            connection_percent = (current_connections / max_connections) * 100
            
            return {
                'max_connections': max_connections,
                'current_connections': current_connections,
                'connection_percent': connection_percent,
                'threads_running': int(threads.get('Threads_running', 0)),
                'threads_connected': current_connections,
                'threads_created': int(threads.get('Threads_created', 0)),
                'threads_cached': int(threads.get('Threads_cached', 0))
            }
        except Exception as e:
            print(f"[ERROR] 获取连接统计信息失败: {e}")
            return None
    
    def get_qps(self):
        """获取QPS(每秒查询数)"""
        try:
            # 获取Com_select, Com_insert, Com_update, Com_delete等操作的计数
            self.cursor.execute("""
                SHOW GLOBAL STATUS LIKE 'Com_%';
            """)
            commands = {}
            for row in self.cursor.fetchall():
                commands[row['Variable_name']] = int(row['Value'])
            
            # 计算总查询数
            total_queries = sum(commands.values())
            
            # 获取服务器运行时间
            self.cursor.execute("""
                SHOW GLOBAL STATUS LIKE 'Uptime';
            """)
            uptime = int(self.cursor.fetchone()['Value'])
            
            qps = total_queries / uptime if uptime > 0 else 0
            
            return {
                'total_queries': total_queries,
                'uptime': uptime,
                'qps': qps
            }
        except Exception as e:
            print(f"[ERROR] 获取QPS失败: {e}")
            return None
    
    def get_slow_queries(self):
        """获取慢查询信息"""
        try:
            # 获取慢查询数量
            self.cursor.execute("""
                SHOW GLOBAL STATUS LIKE 'Slow_queries';
            """)
            slow_queries = int(self.cursor.fetchone()['Value'])
            
            # 获取慢查询阈值
            self.cursor.execute("""
                SHOW GLOBAL VARIABLES LIKE 'long_query_time';
            """)
            long_query_time = float(self.cursor.fetchone()['Value'])
            
            # 获取慢查询日志状态
            self.cursor.execute("""
                SHOW GLOBAL VARIABLES LIKE 'slow_query_log';
            """)
            slow_query_log = self.cursor.fetchone()['Value']
            
            return {
                'slow_queries': slow_queries,
                'long_query_time': long_query_time,
                'slow_query_log': slow_query_log
            }
        except Exception as e:
            print(f"[ERROR] 获取慢查询信息失败: {e}")
            return None
    
    def get_cache_hit_rate(self):
        """获取缓存命中率"""
        try:
            # 获取InnoDB缓存信息
            self.cursor.execute("""
                SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_read%';
            """)
            innodb_stats = {}
            for row in self.cursor.fetchall():
                innodb_stats[row['Variable_name']] = int(row['Value'])
            
            # 计算InnoDB缓存命中率
            innodb_reads = innodb_stats.get('Innodb_buffer_pool_reads', 0)
            innodb_read_requests = innodb_stats.get('Innodb_buffer_pool_read_requests', 0)
            innodb_cache_hit_rate = ((innodb_read_requests - innodb_reads) / innodb_read_requests * 100) if innodb_read_requests > 0 else 0
            
            # 获取查询缓存信息（如果启用）
            self.cursor.execute("""
                SHOW GLOBAL STATUS LIKE 'Qcache%';
            """)
            qcache_stats = {}
            for row in self.cursor.fetchall():
                qcache_stats[row['Variable_name']] = int(row['Value'])
            
            # 计算查询缓存命中率
            qcache_hits = qcache_stats.get('Qcache_hits', 0)
            qcache_inserts = qcache_stats.get('Qcache_inserts', 0)
            qcache_not_cached = qcache_stats.get('Qcache_not_cached', 0)
            qcache_total = qcache_hits + qcache_inserts + qcache_not_cached
            query_cache_hit_rate = (qcache_hits / qcache_total * 100) if qcache_total > 0 else 0
            
            return {
                'innodb_cache_hit_rate': innodb_cache_hit_rate,
                'query_cache_hit_rate': query_cache_hit_rate
            }
        except Exception as e:
            print(f"[ERROR] 获取缓存命中率失败: {e}")
            return None
    
    def get_tablespace_usage(self):
        """获取表空间使用情况"""
        try:
            self.cursor.execute("""
                SELECT 
                    table_schema,
                    SUM(data_length + index_length) / 1024 / 1024 AS total_mb,
                    SUM(data_free) / 1024 / 1024 AS free_mb
                FROM 
                    information_schema.tables
                GROUP BY 
                    table_schema
                ORDER BY 
                    total_mb DESC;
            """)
            tablespaces = []
            for row in self.cursor.fetchall():
                schema = row['table_schema']
                if schema in ('information_schema', 'performance_schema', 'mysql', 'sys'):
                    continue
                
                total_mb = row['total_mb'] or 0
                free_mb = row['free_mb'] or 0
                used_mb = total_mb - free_mb
                usage_percent = (used_mb / total_mb * 100) if total_mb > 0 else 0
                
                tablespaces.append({
                    'schema': schema,
                    'total_mb': total_mb,
                    'used_mb': used_mb,
                    'free_mb': free_mb,
                    'usage_percent': usage_percent
                })
            
            return tablespaces
        except Exception as e:
            print(f"[ERROR] 获取表空间使用情况失败: {e}")
            return None
    
    def get_process_list(self):
        """获取数据库进程列表"""
        try:
            self.cursor.execute("""
                SHOW PROCESSLIST;
            """)
            processes = []
            for row in self.cursor.fetchall():
                processes.append({
                    'id': row['Id'],
                    'user': row['User'],
                    'host': row['Host'],
                    'db': row['db'],
                    'command': row['Command'],
                    'time': row['Time'],
                    'state': row['State'],
                    'info': row['Info']
                })
            return processes
        except Exception as e:
            print(f"[ERROR] 获取进程列表失败: {e}")
            return None
    
    def get_replication_status(self):
        """获取主从复制状态"""
        try:
            self.cursor.execute("""
                SHOW SLAVE STATUS;
            """)
            slave_status = self.cursor.fetchone()
            
            if not slave_status:
                return {'status': 'Not a slave'}
            
            return {
                'status': 'Running' if slave_status['Slave_IO_Running'] == 'Yes' and slave_status['Slave_SQL_Running'] == 'Yes' else 'Error',
                'master_host': slave_status['Master_Host'],
                'master_port': slave_status['Master_Port'],
                'slave_io_running': slave_status['Slave_IO_Running'],
                'slave_sql_running': slave_status['Slave_SQL_Running'],
                'seconds_behind_master': slave_status['Seconds_Behind_Master']
            }
        except Exception as e:
            print(f"[ERROR] 获取主从复制状态失败: {e}")
            return {'status': 'Error', 'error': str(e)}
    
    def check_thresholds(self, stats):
        """检查阈值并生成告警"""
        alerts = []
        
        # 检查连接数
        if stats.get('connection_stats'):
            conn_percent = stats['connection_stats']['connection_percent']
            if conn_percent > MAX_CONNECTIONS_THRESHOLD:
                alerts.append({
                    'level': 'WARNING',
                    'message': f'连接数使用率过高: {conn_percent:.2f}% (阈值: {MAX_CONNECTIONS_THRESHOLD}%)',
                    'metric': 'connection_percent',
                    'value': conn_percent,
                    'threshold': MAX_CONNECTIONS_THRESHOLD
                })
        
        # 检查QPS
        if stats.get('qps'):
            qps_value = stats['qps']['qps']
            if qps_value > MAX_QPS_THRESHOLD:
                alerts.append({
                    'level': 'WARNING',
                    'message': f'QPS过高: {qps_value:.2f} (阈值: {MAX_QPS_THRESHOLD})',
                    'metric': 'qps',
                    'value': qps_value,
                    'threshold': MAX_QPS_THRESHOLD
                })
        
        # 检查慢查询
        if stats.get('slow_queries'):
            slow_query_count = stats['slow_queries']['slow_queries']
            if slow_query_count > 0:
                alerts.append({
                    'level': 'WARNING',
                    'message': f'存在慢查询: {slow_query_count} 条',
                    'metric': 'slow_queries',
                    'value': slow_query_count,
                    'threshold': 0
                })
        
        # 检查缓存命中率
        if stats.get('cache_hit_rate'):
            innodb_cache_rate = stats['cache_hit_rate']['innodb_cache_hit_rate']
            if innodb_cache_rate < CACHE_HIT_RATE_THRESHOLD:
                alerts.append({
                    'level': 'WARNING',
                    'message': f'InnoDB缓存命中率过低: {innodb_cache_rate:.2f}% (阈值: {CACHE_HIT_RATE_THRESHOLD}%)',
                    'metric': 'innodb_cache_hit_rate',
                    'value': innodb_cache_rate,
                    'threshold': CACHE_HIT_RATE_THRESHOLD
                })
        
        # 检查表空间使用情况
        if stats.get('tablespace_usage'):
            for tablespace in stats['tablespace_usage']:
                if tablespace['usage_percent'] > TABLESPACE_USAGE_THRESHOLD:
                    alerts.append({
                        'level': 'WARNING',
                        'message': f'表空间 {tablespace["schema"]} 使用率过高: {tablespace["usage_percent"]:.2f}% (阈值: {TABLESPACE_USAGE_THRESHOLD}%)',
                        'metric': 'tablespace_usage',
                        'value': tablespace['usage_percent'],
                        'threshold': TABLESPACE_USAGE_THRESHOLD,
                        'schema': tablespace['schema']
                    })
        
        # 检查主从复制状态
        if stats.get('replication_status') and stats['replication_status']['status'] != 'Not a slave':
            if stats['replication_status']['status'] != 'Running':
                alerts.append({
                    'level': 'CRITICAL',
                    'message': f'主从复制异常: {stats["replication_status"].get("error", "未知错误")}',
                    'metric': 'replication_status',
                    'value': stats['replication_status']['status'],
                    'threshold': 'Running'
                })
            elif stats['replication_status'].get('seconds_behind_master') and stats['replication_status']['seconds_behind_master'] > 30:
                alerts.append({
                    'level': 'WARNING',
                    'message': f'主从复制延迟过大: {stats["replication_status"]["seconds_behind_master"]} 秒',
                    'metric': 'seconds_behind_master',
                    'value': stats['replication_status']['seconds_behind_master'],
                    'threshold': 30
                })
        
        return alerts
    
    def send_alert(self, alert):
        """发送告警"""
        if ALERT_ENABLED:
            print(f"[ALERT] [{alert['level']}] {alert['message']}")
            # 这里可以添加邮件发送逻辑
            # import smtplib
            # from email.mime.text import MIMEText
            # ...
    
    def _convert_decimal_to_float(self, data):
        """将数据中的Decimal类型转换为float类型"""
        if isinstance(data, dict):
            return {k: self._convert_decimal_to_float(v) for k, v in data.items()}
        elif isinstance(data, list):
            return [self._convert_decimal_to_float(item) for item in data]
        elif isinstance(data, (int, float, str, bool, type(None))):
            return data
        else:
            try:
                return float(data)
            except:
                return str(data)
    
    def save_stats_to_json(self, stats, alerts):
        """保存监控结果为JSON文件"""
        try:
            # 构建完整的监控数据
            monitor_data = {
                'timestamp': time.strftime('%Y-%m-%d %H:%M:%S'),
                'monitor_time': time.time(),
                'stats': self._convert_decimal_to_float(stats),
                'alerts': self._convert_decimal_to_float(alerts),
                'thresholds': {
                    'max_connections_threshold': MAX_CONNECTIONS_THRESHOLD,
                    'max_qps_threshold': MAX_QPS_THRESHOLD,
                    'slow_query_threshold': SLOW_QUERY_THRESHOLD,
                    'cache_hit_rate_threshold': CACHE_HIT_RATE_THRESHOLD,
                    'tablespace_usage_threshold': TABLESPACE_USAGE_THRESHOLD
                }
            }
            
            # 生成文件名，包含时间戳
            file_name = f"mysql_monitor_{time.strftime('%Y%m%d_%H%M%S')}.json"
            file_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'monitor', file_name)
            
            # 写入JSON文件
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(monitor_data, f, ensure_ascii=False, indent=2)
            
            print(f"[INFO] 监控结果已保存到: {file_path}")
        except Exception as e:
            print(f"[ERROR] 保存监控结果到JSON文件失败: {e}")
    
    def run_monitor(self):
        """运行监控"""
        print(f"\n[INFO] 开始监控 - {time.strftime('%Y-%m-%d %H:%M:%S')}")
        
        # 初始化监控数据
        stats = {
            'connection_status': False,
            'connection_stats': None,
            'qps': None,
            'slow_queries': None,
            'cache_hit_rate': None,
            'tablespace_usage': None,
            'process_list': None,
            'replication_status': None,
            'connection_error': None
        }
        
        # 连接数据库
        if not self.connect():
            error_msg = "无法连接数据库"
            print(f"[ERROR] {error_msg}")
            stats['connection_error'] = error_msg
        else:
            # 收集监控数据
            stats['connection_status'] = self.get_connection_status()
            stats['connection_stats'] = self.get_connection_stats()
            stats['qps'] = self.get_qps()
            stats['slow_queries'] = self.get_slow_queries()
            stats['cache_hit_rate'] = self.get_cache_hit_rate()
            stats['tablespace_usage'] = self.get_tablespace_usage()
            stats['process_list'] = self.get_process_list()
            stats['replication_status'] = self.get_replication_status()
            
            # 输出监控结果
            print("\n=== 监控结果 ===")
            
            # 连接状态
            print(f"连接状态: {'正常' if stats['connection_status'] else '异常'}")
            
            # 连接统计
            if stats['connection_stats']:
                conn_stats = stats['connection_stats']
                print(f"连接数: {conn_stats['current_connections']}/{conn_stats['max_connections']} ({conn_stats['connection_percent']:.2f}%)")
                print(f"运行中线程: {conn_stats['threads_running']}")
            
            # QPS
            if stats['qps']:
                print(f"QPS: {stats['qps']['qps']:.2f}")
            
            # 慢查询
            if stats['slow_queries']:
                print(f"慢查询数: {stats['slow_queries']['slow_queries']}")
                print(f"慢查询阈值: {stats['slow_queries']['long_query_time']}秒")
                print(f"慢查询日志: {stats['slow_queries']['slow_query_log']}")
            
            # 缓存命中率
            if stats['cache_hit_rate']:
                print(f"InnoDB缓存命中率: {stats['cache_hit_rate']['innodb_cache_hit_rate']:.2f}%")
                print(f"查询缓存命中率: {stats['cache_hit_rate']['query_cache_hit_rate']:.2f}%")
            
            # 表空间使用情况
            if stats['tablespace_usage']:
                print("\n表空间使用情况:")
                for ts in stats['tablespace_usage']:
                    print(f"  {ts['schema']}: {ts['used_mb']:.2f}MB/{ts['total_mb']:.2f}MB ({ts['usage_percent']:.2f}%)")
            
            # 主从复制状态
            if stats['replication_status']:
                print(f"\n主从复制状态: {stats['replication_status']['status']}")
                if stats['replication_status']['status'] != 'Not a slave':
                    print(f"  主库: {stats['replication_status'].get('master_host')}:{stats['replication_status'].get('master_port')}")
                    if 'seconds_behind_master' in stats['replication_status']:
                        print(f"  延迟: {stats['replication_status']['seconds_behind_master']}秒")
        
        # 检查阈值并生成告警
        alerts = self.check_thresholds(stats)
        if alerts:
            print("\n=== 告警信息 ===")
            for alert in alerts:
                self.send_alert(alert)
        else:
            print("\n=== 告警信息 ===")
            print("无告警")
        
        # 保存监控结果为JSON文件
        self.save_stats_to_json(stats, alerts)
        
        # 断开连接
        self.disconnect()
        
        print(f"\n[INFO] 监控完成 - {time.strftime('%Y-%m-%d %H:%M:%S')}")

if __name__ == "__main__":
    monitor = MySQLMonitor()
    try:
        monitor.run_monitor()
    except KeyboardInterrupt:
        print("\n[INFO] 监控已手动停止")
    finally:
        # 连接已经在run_monitor方法中关闭，不需要重复关闭
        pass
