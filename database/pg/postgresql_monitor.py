#!/usr/bin/env python3
import os
import time
import json
import psycopg2
from dotenv import load_dotenv

# 加载配置文件
load_dotenv()

# 数据库配置
POSTGRES_HOST = os.getenv('POSTGRES_HOST', 'localhost')
POSTGRES_PORT = int(os.getenv('POSTGRES_PORT', 5432))
POSTGRES_USER = os.getenv('POSTGRES_USER', 'postgres')
POSTGRES_PASSWORD = os.getenv('POSTGRES_PASSWORD', '')
POSTGRES_DATABASE = os.getenv('POSTGRES_DATABASE', 'postgres')

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

class PostgreSQLMonitor:
    def __init__(self, config=None, instance_name=None):
        self.conn = None
        self.cursor = None
        # 使用传入的配置或环境变量
        self.config = config or {}
        self.instance_name = instance_name
        self.host = self.config.get('host', POSTGRES_HOST)
        self.port = self.config.get('port', POSTGRES_PORT)
        self.user = self.config.get('user', POSTGRES_USER)
        self.password = self.config.get('password', POSTGRES_PASSWORD)
        self.database = self.config.get('database', POSTGRES_DATABASE)
    
    def connect(self):
        """连接到PostgreSQL数据库"""
        try:
            self.conn = psycopg2.connect(
                host=self.host,
                port=self.port,
                user=self.user,
                password=self.password,
                database=self.database
            )
            self.cursor = self.conn.cursor()
            print(f"[INFO] 成功连接到PostgreSQL数据库: {self.host}:{self.port}")
            return True
        except Exception as e:
            print(f"[ERROR] 连接PostgreSQL数据库失败: {e}")
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
            # 获取最大连接数
            self.cursor.execute("SHOW max_connections")
            max_connections = int(self.cursor.fetchone()[0])
            
            # 获取当前连接数
            self.cursor.execute("SELECT count(*) FROM pg_stat_activity")
            current_connections = int(self.cursor.fetchone()[0])
            
            connection_percent = (current_connections / max_connections) * 100
            
            # 获取运行中查询数
            self.cursor.execute("SELECT count(*) FROM pg_stat_activity WHERE state = 'active'")
            active_connections = int(self.cursor.fetchone()[0])
            
            return {
                'max_connections': max_connections,
                'current_connections': current_connections,
                'connection_percent': connection_percent,
                'active_connections': active_connections
            }
        except Exception as e:
            print(f"[ERROR] 获取连接统计信息失败: {e}")
            return None
    
    def get_qps(self):
        """获取QPS(每秒查询数)"""
        try:
            # 获取查询统计信息
            self.cursor.execute("""
                SELECT 
                    sum(xact_commit + xact_rollback) as total_transactions,
                    extract(epoch from now() - pg_postmaster_start_time()) as uptime
                FROM pg_stat_database
                WHERE datname = %s
            """, (self.database,))
            
            result = self.cursor.fetchone()
            if result:
                total_transactions = result[0] or 0
                uptime = result[1] or 0
                
                qps = total_transactions / uptime if uptime > 0 else 0
                
                return {
                    'total_transactions': total_transactions,
                    'uptime': uptime,
                    'qps': qps
                }
            return None
        except Exception as e:
            print(f"[ERROR] 获取QPS失败: {e}")
            return None
    
    def get_slow_queries(self):
        """获取慢查询信息"""
        try:
            # 获取慢查询设置
            self.cursor.execute("SHOW log_min_duration_statement")
            log_min_duration = self.cursor.fetchone()[0]
            
            # 获取当前正在执行的慢查询（基于设置的慢查询阈值）
            # 尝试将log_min_duration转换为秒
            slow_query_threshold = 1  # 默认1秒
            try:
                if log_min_duration.endswith('ms'):
                    slow_query_threshold = int(log_min_duration[:-2]) / 1000
                elif log_min_duration == '0':
                    slow_query_threshold = 0
                else:
                    slow_query_threshold = int(log_min_duration)
            except:
                pass
            
            # 查询正在执行且超过阈值的查询
            self.cursor.execute("""
                SELECT count(*)
                FROM pg_stat_activity 
                WHERE state = 'active' 
                AND now() - query_start > interval '%s second'
                AND query NOT LIKE '%%pg_stat_activity%%'
            """, (slow_query_threshold,))
            slow_query_count = int(self.cursor.fetchone()[0])
            
            return {
                'slow_queries': slow_query_count,
                'log_min_duration_statement': log_min_duration,
                'slow_query_threshold': slow_query_threshold
            }
        except Exception as e:
            print(f"[ERROR] 获取慢查询信息失败: {e}")
            return None
    
    def get_cache_hit_rate(self):
        """获取缓存命中率"""
        try:
            # 获取共享缓冲区命中率
            self.cursor.execute("""
                SELECT 
                    sum(heap_blks_hit) as heap_blks_hit,
                    sum(heap_blks_read) as heap_blks_read
                FROM pg_statio_user_tables
            """)
            
            result = self.cursor.fetchone()
            if result:
                heap_blks_hit = result[0] or 0
                heap_blks_read = result[1] or 0
                total_reads = heap_blks_hit + heap_blks_read
                
                cache_hit_rate = (heap_blks_hit / total_reads * 100) if total_reads > 0 else 0
                
                return {
                    'cache_hit_rate': cache_hit_rate,
                    'heap_blks_hit': heap_blks_hit,
                    'heap_blks_read': heap_blks_read
                }
            return None
        except Exception as e:
            print(f"[ERROR] 获取缓存命中率失败: {e}")
            return None
    
    def get_tablespace_usage(self):
        """获取表空间使用情况"""
        try:
            self.cursor.execute("""
                SELECT 
                    spcname as tablespace,
                    pg_size_pretty(pg_tablespace_size(spcname)) as size,
                    pg_tablespace_size(spcname) as size_bytes,
                    pg_size_pretty(pg_tablespace_size(spcname) - pg_tablespace_free_size(spcname)) as used_size,
                    pg_tablespace_size(spcname) - pg_tablespace_free_size(spcname) as used_bytes
                FROM pg_tablespace
                WHERE spcname NOT LIKE 'pg_%'
                ORDER BY size_bytes DESC
            """)
            
            tablespaces = []
            for row in self.cursor.fetchall():
                tablespace = row[0]
                size = row[1]
                size_bytes = row[2]
                used_size = row[3]
                used_bytes = row[4]
                
                usage_percent = (used_bytes / size_bytes * 100) if size_bytes > 0 else 0
                
                tablespaces.append({
                    'tablespace': tablespace,
                    'size': size,
                    'size_bytes': size_bytes,
                    'used_size': used_size,
                    'used_bytes': used_bytes,
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
                SELECT 
                    pid,
                    usename,
                    datname,
                    application_name,
                    client_addr,
                    client_port,
                    backend_start,
                    state,
                    query
                FROM pg_stat_activity
                WHERE pid != pg_backend_pid()
            """)
            
            processes = []
            for row in self.cursor.fetchall():
                processes.append({
                    'pid': row[0],
                    'usename': row[1],
                    'datname': row[2],
                    'application_name': row[3],
                    'client_addr': str(row[4]) if row[4] else None,
                    'client_port': row[5],
                    'backend_start': str(row[6]) if row[6] else None,
                    'state': row[7],
                    'query': row[8]
                })
            
            return processes
        except Exception as e:
            print(f"[ERROR] 获取进程列表失败: {e}")
            return None
    
    def get_replication_status(self):
        """获取复制状态"""
        try:
            self.cursor.execute("""
                SELECT 
                    application_name,
                    state,
                    sync_state,
                    pg_wal_lsn_diff(pg_current_wal_lsn(), sent_lsn) as lag_bytes
                FROM pg_stat_replication
            """)
            
            replicas = []
            for row in self.cursor.fetchall():
                replicas.append({
                    'application_name': row[0],
                    'state': row[1],
                    'sync_state': row[2],
                    'lag_bytes': row[3]
                })
            
            if not replicas:
                return {'status': 'No replicas'}
            
            return {
                'status': 'Running' if all(replica['state'] == 'streaming' for replica in replicas) else 'Error',
                'replicas': replicas
            }
        except Exception as e:
            print(f"[ERROR] 获取复制状态失败: {e}")
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
        
        # 检查缓存命中率
        if stats.get('cache_hit_rate'):
            cache_rate = stats['cache_hit_rate']['cache_hit_rate']
            if cache_rate < CACHE_HIT_RATE_THRESHOLD:
                alerts.append({
                    'level': 'WARNING',
                    'message': f'缓存命中率过低: {cache_rate:.2f}% (阈值: {CACHE_HIT_RATE_THRESHOLD}%)',
                    'metric': 'cache_hit_rate',
                    'value': cache_rate,
                    'threshold': CACHE_HIT_RATE_THRESHOLD
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
                'instance_name': self.instance_name,
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
            
            # 生成文件名，包含实例名称和时间戳
            file_name = f"{self.instance_name}_{time.strftime('%Y%m%d_%H%M%S')}.json"
            # 使用传递的监控目录或默认目录
            if self.monitor_dir:
                file_path = os.path.join(self.monitor_dir, file_name)
            else:
                file_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'monitor', file_name)
            
            # 写入JSON文件
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(monitor_data, f, ensure_ascii=False, indent=2)
            
            print(f"[INFO] 监控结果已保存到: {file_path}")
        except Exception as e:
            print(f"[ERROR] 保存监控结果到JSON文件失败: {e}")
    
    def run_monitor(self, monitor_dir=None):
        """运行监控"""
        print(f"\n[INFO] 开始监控 - {time.strftime('%Y-%m-%d %H:%M:%S')}")
        self.monitor_dir = monitor_dir
        
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
                print(f"活跃连接数: {conn_stats['active_connections']}")
            
            # QPS
            if stats['qps']:
                print(f"QPS: {stats['qps']['qps']:.2f}")
            
            # 慢查询
            if stats['slow_queries']:
                print(f"慢查询数: {stats['slow_queries']['slow_queries']}")
                print(f"慢查询阈值: {stats['slow_queries']['log_min_duration_statement']}ms")
            
            # 缓存命中率
            if stats['cache_hit_rate']:
                print(f"缓存命中率: {stats['cache_hit_rate']['cache_hit_rate']:.2f}%")
            
            # 表空间使用情况
            if stats['tablespace_usage']:
                print("\n表空间使用情况:")
                for ts in stats['tablespace_usage']:
                    print(f"  {ts['tablespace']}: {ts['size']}")
            
            # 复制状态
            if stats['replication_status']:
                print(f"\n复制状态: {stats['replication_status']['status']}")
                if 'replicas' in stats['replication_status']:
                    for replica in stats['replication_status']['replicas']:
                        print(f"  副本: {replica['application_name']}, 状态: {replica['state']}, 延迟: {replica['lag_bytes']} bytes")
        
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
    monitor = PostgreSQLMonitor()
    try:
        monitor.run_monitor()
    except KeyboardInterrupt:
        print("\n[INFO] 监控已手动停止")
    finally:
        # 连接已经在run_monitor方法中关闭，不需要重复关闭
        pass
