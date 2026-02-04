#!/usr/bin/env python3
import os
import time
import json
from pymongo import MongoClient
from dotenv import load_dotenv

# 加载配置文件
load_dotenv()

# 数据库配置
MONGO_HOST = os.getenv('MONGO_HOST', 'localhost')
MONGO_PORT = int(os.getenv('MONGO_PORT', 27017))
MONGO_USER = os.getenv('MONGO_USER', '')
MONGO_PASSWORD = os.getenv('MONGO_PASSWORD', '')
MONGO_DATABASE = os.getenv('MONGO_DATABASE', 'admin')

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

class MongoDBMonitor:
    def __init__(self, config=None):
        self.client = None
        self.db = None
        # 使用传入的配置或环境变量
        self.config = config or {}
        self.host = self.config.get('host', MONGO_HOST)
        self.port = self.config.get('port', MONGO_PORT)
        self.user = self.config.get('user', MONGO_USER)
        self.password = self.config.get('password', MONGO_PASSWORD)
        self.database = self.config.get('database', MONGO_DATABASE)
    
    def connect(self):
        """连接到MongoDB数据库"""
        try:
            if self.user and self.password:
                # 带认证的连接
                mongo_uri = f"mongodb://{self.user}:{self.password}@{self.host}:{self.port}/{self.database}?authSource=admin"
            else:
                # 无认证的连接
                mongo_uri = f"mongodb://{self.host}:{self.port}/{self.database}"
            
            self.client = pymongo.MongoClient(mongo_uri)
            self.db = self.client[self.database]
            
            # 测试连接
            self.client.admin.command('ping')
            print(f"[INFO] 成功连接到MongoDB数据库: {self.host}:{self.port}")
            return True
        except Exception as e:
            print(f"[ERROR] 连接MongoDB数据库失败: {e}")
            return False
    
    def disconnect(self):
        """断开数据库连接"""
        if self.client:
            self.client.close()
        print("[INFO] 数据库连接已断开")
    
    def get_connection_status(self):
        """获取连接状态"""
        try:
            self.db.command('ping')
            return True
        except Exception as e:
            print(f"[ERROR] 检查连接状态失败: {e}")
            return False
    
    def get_connection_stats(self):
        """获取连接统计信息"""
        try:
            # 获取连接统计信息
            server_status = self.db.command('serverStatus')
            
            # 获取当前连接数
            current_connections = server_status.get('connections', {}).get('current', 0)
            available_connections = server_status.get('connections', {}).get('available', 0)
            total_connections = current_connections + available_connections
            
            connection_percent = (current_connections / total_connections) * 100 if total_connections > 0 else 0
            
            return {
                'max_connections': total_connections,
                'current_connections': current_connections,
                'connection_percent': connection_percent,
                'available_connections': available_connections
            }
        except Exception as e:
            print(f"[ERROR] 获取连接统计信息失败: {e}")
            return None
    
    def get_qps(self):
        """获取QPS(每秒查询数)"""
        try:
            # 获取操作统计信息
            server_status = self.db.command('serverStatus')
            
            # 获取操作计数器
            opcounters = server_status.get('opcounters', {})
            total_ops = sum(opcounters.values())
            
            # 获取服务器运行时间
            uptime = server_status.get('uptime', 0)
            
            qps = total_ops / uptime if uptime > 0 else 0
            
            return {
                'total_operations': total_ops,
                'uptime': uptime,
                'qps': qps,
                'opcounters': opcounters
            }
        except Exception as e:
            print(f"[ERROR] 获取QPS失败: {e}")
            return None
    
    def get_slow_queries(self):
        """获取慢查询信息"""
        try:
            # 检查慢查询日志是否启用
            get_param_result = self.db.command('getParameter', 1, slowms=1)
            slowms = get_param_result.get('slowms', 100)
            
            # 获取慢查询数（需要启用慢查询日志）
            # 这里简化处理，实际生产环境中需要查询system.profile集合
            slow_query_count = 0
            
            return {
                'slow_queries': slow_query_count,
                'slow_query_threshold': slowms / 1000  # 转换为秒
            }
        except Exception as e:
            print(f"[ERROR] 获取慢查询信息失败: {e}")
            return None
    
    def get_cache_hit_rate(self):
        """获取缓存命中率"""
        try:
            # 获取内存使用情况
            server_status = self.db.command('serverStatus')
            
            # 获取缓存命中信息
            wiredtiger = server_status.get('wiredTiger', {})
            cache = wiredtiger.get('cache', {})
            
            if cache:
                hits = cache.get('hits', 0)
                misses = cache.get('misses', 0)
                total = hits + misses
                
                cache_hit_rate = (hits / total) * 100 if total > 0 else 0
                
                return {
                    'cache_hit_rate': cache_hit_rate,
                    'hits': hits,
                    'misses': misses
                }
            return None
        except Exception as e:
            print(f"[ERROR] 获取缓存命中率失败: {e}")
            return None
    
    def get_tablespace_usage(self):
        """获取存储空间使用情况"""
        try:
            # 获取数据库大小信息
            db_stats = self.db.command('dbStats')
            
            total_size_mb = db_stats.get('dataSize', 0) / (1024 * 1024)
            storage_size_mb = db_stats.get('storageSize', 0) / (1024 * 1024)
            index_size_mb = db_stats.get('indexSize', 0) / (1024 * 1024)
            
            # 获取所有集合的大小
            collections = []
            for coll_name in self.db.list_collection_names():
                coll_stats = self.db.command('collStats', coll_name)
                collections.append({
                    'collection': coll_name,
                    'size_mb': coll_stats.get('size', 0) / (1024 * 1024),
                    'storage_size_mb': coll_stats.get('storageSize', 0) / (1024 * 1024),
                    'index_size_mb': coll_stats.get('totalIndexSize', 0) / (1024 * 1024)
                })
            
            return {
                'database': MONGO_DATABASE,
                'total_size_mb': total_size_mb,
                'storage_size_mb': storage_size_mb,
                'index_size_mb': index_size_mb,
                'collections': collections
            }
        except Exception as e:
            print(f"[ERROR] 获取存储空间使用情况失败: {e}")
            return None
    
    def get_process_list(self):
        """获取数据库进程列表"""
        try:
            # 获取当前操作
            current_ops = self.db.command('currentOp', { 'active': True })
            
            operations = []
            for op in current_ops.get('inprog', []):
                operations.append({
                    'opid': op.get('opid'),
                    'op': op.get('op'),
                    'ns': op.get('ns'),
                    'query': op.get('query'),
                    'client': op.get('client'),
                    'connectionId': op.get('connectionId'),
                    'active': op.get('active'),
                    'secs_running': op.get('secs_running')
                })
            
            return operations
        except Exception as e:
            print(f"[ERROR] 获取进程列表失败: {e}")
            return None
    
    def get_replication_status(self):
        """获取复制状态"""
        try:
            # 检查复制状态
            repl_status = self.db.command('replSetGetStatus', check=False)
            
            if repl_status.get('ok') == 1:
                # 复制集状态
                members = repl_status.get('members', [])
                primary = None
                secondaries = []
                
                for member in members:
                    if member.get('stateStr') == 'PRIMARY':
                        primary = member
                    elif member.get('stateStr') == 'SECONDARY':
                        secondaries.append(member)
                
                return {
                    'status': 'Running',
                    'replSetName': repl_status.get('set'),
                    'primary': primary.get('name') if primary else None,
                    'secondaries': [s.get('name') for s in secondaries],
                    'memberCount': len(members)
                }
            else:
                # 不是复制集
                return {'status': 'Not a replica set'}
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
            file_name = f"mongodb_monitor_{time.strftime('%Y%m%d_%H%M%S')}.json"
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
                print(f"可用连接数: {conn_stats['available_connections']}")
            
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
            
            # 存储空间使用情况
            if stats['tablespace_usage']:
                ts_usage = stats['tablespace_usage']
                print("\n存储空间使用情况:")
                print(f"  数据库: {ts_usage['database']}")
                print(f"  数据大小: {ts_usage['total_size_mb']:.2f}MB")
                print(f"  存储大小: {ts_usage['storage_size_mb']:.2f}MB")
                print(f"  索引大小: {ts_usage['index_size_mb']:.2f}MB")
            
            # 复制状态
            if stats['replication_status']:
                print(f"\n复制状态: {stats['replication_status']['status']}")
                if 'primary' in stats['replication_status']:
                    print(f"  主节点: {stats['replication_status']['primary']}")
                if 'secondaries' in stats['replication_status']:
                    print(f"  从节点数: {len(stats['replication_status']['secondaries'])}")
        
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
    monitor = MongoDBMonitor()
    try:
        monitor.run_monitor()
    except KeyboardInterrupt:
        print("\n[INFO] 监控已手动停止")
    finally:
        # 连接已经在run_monitor方法中关闭，不需要重复关闭
        pass
