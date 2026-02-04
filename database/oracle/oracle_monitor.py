#!/usr/bin/env python3
import os
import time
import json
import cx_Oracle
from dotenv import load_dotenv

# 加载配置文件
load_dotenv()

# 数据库配置
ORACLE_HOST = os.getenv('ORACLE_HOST', 'localhost')
ORACLE_PORT = int(os.getenv('ORACLE_PORT', 1521))
ORACLE_USER = os.getenv('ORACLE_USER', 'system')
ORACLE_PASSWORD = os.getenv('ORACLE_PASSWORD', 'oracle')
ORACLE_SID = os.getenv('ORACLE_SID', 'ORCL')

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

class OracleMonitor:
    def __init__(self):
        self.conn = None
        self.cursor = None
    
    def connect(self):
        """连接到Oracle数据库"""
        try:
            dsn = cx_Oracle.makedsn(ORACLE_HOST, ORACLE_PORT, sid=ORACLE_SID)
            self.conn = cx_Oracle.connect(
                user=ORACLE_USER,
                password=ORACLE_PASSWORD,
                dsn=dsn
            )
            self.cursor = self.conn.cursor()
            print(f"[INFO] 成功连接到Oracle数据库: {ORACLE_HOST}:{ORACLE_PORT}/{ORACLE_SID}")
            return True
        except Exception as e:
            print(f"[ERROR] 连接Oracle数据库失败: {e}")
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
            self.cursor.execute("SELECT 1 FROM DUAL")
            result = self.cursor.fetchone()
            return result is not None
        except Exception as e:
            print(f"[ERROR] 检查连接状态失败: {e}")
            return False
    
    def get_connection_stats(self):
        """获取连接统计信息"""
        try:
            # 获取最大连接数
            self.cursor.execute("SELECT value FROM v$parameter WHERE name = 'processes'")
            max_processes = int(self.cursor.fetchone()[0])
            
            # 获取当前连接数
            self.cursor.execute("SELECT COUNT(*) FROM v$session")
            current_connections = int(self.cursor.fetchone()[0])
            
            connection_percent = (current_connections / max_processes) * 100
            
            # 获取运行中查询数
            self.cursor.execute("SELECT COUNT(*) FROM v$session WHERE status = 'ACTIVE'")
            active_connections = int(self.cursor.fetchone()[0])
            
            return {
                'max_connections': max_processes,
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
                    SUM(value) as total_executions,
                    (SYSDATE - startup_time) * 86400 as uptime_seconds
                FROM v$sysstat, v$instance
                WHERE name = 'execute count'
            """)
            
            result = self.cursor.fetchone()
            if result:
                total_executions = result[0] or 0
                uptime_seconds = result[1] or 0
                
                qps = total_executions / uptime_seconds if uptime_seconds > 0 else 0
                
                return {
                    'total_executions': total_executions,
                    'uptime_seconds': uptime_seconds,
                    'qps': qps
                }
            return None
        except Exception as e:
            print(f"[ERROR] 获取QPS失败: {e}")
            return None
    
    def get_slow_queries(self):
        """获取慢查询信息"""
        try:
            # 获取慢查询数（执行时间超过1秒的SQL）
            self.cursor.execute("""
                SELECT COUNT(*) 
                FROM v$sql
                WHERE elapsed_time > 1000000
            """)
            slow_query_count = int(self.cursor.fetchone()[0])
            
            return {
                'slow_queries': slow_query_count,
                'slow_query_threshold': SLOW_QUERY_THRESHOLD
            }
        except Exception as e:
            print(f"[ERROR] 获取慢查询信息失败: {e}")
            return None
    
    def get_cache_hit_rate(self):
        """获取缓存命中率"""
        try:
            # 获取缓冲区命中率
            self.cursor.execute("""
                SELECT 
                    (1 - (phy_reads / (consistent_gets + db_block_gets + phy_reads + 1))) * 100 as cache_hit_rate,
                    consistent_gets + db_block_gets as logical_reads,
                    phy_reads as physical_reads
                FROM v$sysstat
                WHERE name = 'physical reads'
            """)
            
            result = self.cursor.fetchone()
            if result:
                cache_hit_rate = result[0] or 0
                logical_reads = result[1] or 0
                physical_reads = result[2] or 0
                
                return {
                    'cache_hit_rate': cache_hit_rate,
                    'logical_reads': logical_reads,
                    'physical_reads': physical_reads
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
                    tablespace_name,
                    round(sum(bytes) / 1024 / 1024, 2) as total_mb,
                    round(sum(bytes - free_bytes) / 1024 / 1024, 2) as used_mb,
                    round(sum(free_bytes) / 1024 / 1024, 2) as free_mb,
                    round((sum(bytes - free_bytes) / sum(bytes)) * 100, 2) as usage_percent
                FROM (
                    SELECT 
                        tablespace_name,
                        bytes,
                        CASE 
                            WHEN autoextensible = 'YES' THEN maxbytes
                            ELSE bytes
                        END as max_bytes,
                        CASE 
                            WHEN autoextensible = 'YES' THEN maxbytes - bytes
                            ELSE 0
                        END as free_bytes
                    FROM dba_data_files
                )
                GROUP BY tablespace_name
                ORDER BY usage_percent DESC
            """)
            
            tablespaces = []
            for row in self.cursor.fetchall():
                tablespaces.append({
                    'tablespace': row[0],
                    'total_mb': row[1],
                    'used_mb': row[2],
                    'free_mb': row[3],
                    'usage_percent': row[4]
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
                    sid,
                    serial#,
                    username,
                    machine,
                    status,
                    sql_text,
                    logon_time
                FROM v$session s
                LEFT JOIN v$sql q ON s.sql_id = q.sql_id
                WHERE username IS NOT NULL
                ORDER BY status DESC
            """)
            
            processes = []
            for row in self.cursor.fetchall():
                processes.append({
                    'sid': row[0],
                    'serial#': row[1],
                    'username': row[2],
                    'machine': row[3],
                    'status': row[4],
                    'sql_text': row[5],
                    'logon_time': str(row[6]) if row[6] else None
                })
            
            return processes
        except Exception as e:
            print(f"[ERROR] 获取进程列表失败: {e}")
            return None
    
    def get_replication_status(self):
        """获取复制状态"""
        try:
            # 检查是否为主库或备库
            self.cursor.execute("SELECT database_role FROM v$database")
            role = self.cursor.fetchone()[0]
            
            if role == 'PRIMARY':
                # 检查备库状态
                self.cursor.execute("SELECT COUNT(*) FROM v$archive_dest WHERE status = 'VALID' AND target != 'LOCAL'")
                standby_count = int(self.cursor.fetchone()[0])
                
                if standby_count > 0:
                    return {
                        'status': 'Running',
                        'role': role,
                        'standby_count': standby_count
                    }
                else:
                    return {'status': 'No standbys', 'role': role}
            elif role in ('PHYSICAL STANDBY', 'LOGICAL STANDBY'):
                # 检查主库连接状态
                self.cursor.execute("SELECT recovery_mode FROM v$archive_dest_status WHERE dest_id = 1")
                recovery_mode = self.cursor.fetchone()[0]
                
                return {
                    'status': 'Running' if recovery_mode == 'MANAGED' else 'Error',
                    'role': role,
                    'recovery_mode': recovery_mode
                }
            else:
                return {'status': 'Single instance', 'role': role}
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
            cache_rate = stats['cache_hit_rate']['cache_hit_rate']
            if cache_rate < CACHE_HIT_RATE_THRESHOLD:
                alerts.append({
                    'level': 'WARNING',
                    'message': f'缓存命中率过低: {cache_rate:.2f}% (阈值: {CACHE_HIT_RATE_THRESHOLD}%)',
                    'metric': 'cache_hit_rate',
                    'value': cache_rate,
                    'threshold': CACHE_HIT_RATE_THRESHOLD
                })
        
        # 检查表空间使用情况
        if stats.get('tablespace_usage'):
            for tablespace in stats['tablespace_usage']:
                if tablespace['usage_percent'] > TABLESPACE_USAGE_THRESHOLD:
                    alerts.append({
                        'level': 'WARNING',
                        'message': f'表空间 {tablespace["tablespace"]} 使用率过高: {tablespace["usage_percent"]:.2f}% (阈值: {TABLESPACE_USAGE_THRESHOLD}%)',
                        'metric': 'tablespace_usage',
                        'value': tablespace['usage_percent'],
                        'threshold': TABLESPACE_USAGE_THRESHOLD,
                        'tablespace': tablespace['tablespace']
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
            file_name = f"oracle_monitor_{time.strftime('%Y%m%d_%H%M%S')}.json"
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
                print(f"活跃连接数: {conn_stats['active_connections']}")
            
            # QPS
            if stats['qps']:
                print(f"QPS: {stats['qps']['qps']:.2f}")
            
            # 慢查询
            if stats['slow_queries']:
                print(f"慢查询数: {stats['slow_queries']['slow_queries']}")
                print(f"慢查询阈值: {stats['slow_queries']['slow_query_threshold']}秒")
            
            # 缓存命中率
            if stats['cache_hit_rate']:
                print(f"缓存命中率: {stats['cache_hit_rate']['cache_hit_rate']:.2f}%")
            
            # 表空间使用情况
            if stats['tablespace_usage']:
                print("\n表空间使用情况:")
                for ts in stats['tablespace_usage']:
                    print(f"  {ts['tablespace']}: {ts['used_mb']:.2f}MB/{ts['total_mb']:.2f}MB ({ts['usage_percent']:.2f}%)")
            
            # 复制状态
            if stats['replication_status']:
                print(f"\n复制状态: {stats['replication_status']['status']}")
                if 'role' in stats['replication_status']:
                    print(f"  角色: {stats['replication_status']['role']}")
        
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
    monitor = OracleMonitor()
    try:
        monitor.run_monitor()
    except KeyboardInterrupt:
        print("\n[INFO] 监控已手动停止")
    finally:
        # 连接已经在run_monitor方法中关闭，不需要重复关闭
        pass
