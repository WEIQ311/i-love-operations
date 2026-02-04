#!/usr/bin/env python3
import os
import json
import time
import logging
import argparse
from datetime import datetime
from dotenv import load_dotenv

# 加载配置文件
load_dotenv()

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('monitor_to_db.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class DatabaseWriter:
    def __init__(self, db_type, db_config):
        self.db_type = db_type
        self.db_config = db_config
        self.conn = None
        self.cursor = None
    
    def connect(self):
        """连接到数据库"""
        try:
            if self.db_type == 'mysql':
                import pymysql
                self.conn = pymysql.connect(
                    host=self.db_config.get('host', 'localhost'),
                    port=self.db_config.get('port', 3306),
                    user=self.db_config.get('user', 'root'),
                    password=self.db_config.get('password', ''),
                    database=self.db_config.get('database', 'monitor'),
                    charset='utf8mb4',
                    cursorclass=pymysql.cursors.DictCursor
                )
                self.cursor = self.conn.cursor()
                # 测试连接
                self.cursor.execute("SELECT 1")
            
            elif self.db_type == 'postgresql':
                import psycopg2
                self.conn = psycopg2.connect(
                    host=self.db_config.get('host', 'localhost'),
                    port=self.db_config.get('port', 5432),
                    user=self.db_config.get('user', 'postgres'),
                    password=self.db_config.get('password', ''),
                    database=self.db_config.get('database', 'monitor')
                )
                self.cursor = self.conn.cursor()
                # 测试连接
                self.cursor.execute("SELECT 1")
            
            elif self.db_type == 'oracle':
                import oracledb
                dsn = oracledb.makedsn(
                    self.db_config.get('host', 'localhost'),
                    self.db_config.get('port', 1521),
                    sid=self.db_config.get('sid', 'ORCL')
                )
                self.conn = oracledb.connect(
                    user=self.db_config.get('user', 'system'),
                    password=self.db_config.get('password', 'oracle'),
                    dsn=dsn
                )
                self.cursor = self.conn.cursor()
                # 测试连接
                self.cursor.execute("SELECT 1 FROM DUAL")
            
            elif self.db_type == 'mssql':
                import pyodbc
                conn_str = f"DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={self.db_config.get('host', 'localhost')},{self.db_config.get('port', 1433)};DATABASE={self.db_config.get('database', 'monitor')};UID={self.db_config.get('user', 'sa')};PWD={self.db_config.get('password', '')}"
                self.conn = pyodbc.connect(conn_str)
                self.cursor = self.conn.cursor()
                # 测试连接
                self.cursor.execute("SELECT 1")
            
            elif self.db_type == 'mongodb':
                import pymongo
                mongo_uri = f"mongodb://{self.db_config.get('user', '')}:{self.db_config.get('password', '')}@{self.db_config.get('host', 'localhost')}:{self.db_config.get('port', 27017)}/{self.db_config.get('database', 'monitor')}"
                self.conn = pymongo.MongoClient(mongo_uri, serverSelectionTimeoutMS=5000)
                # 测试连接
                self.conn.admin.command('ping')
                self.db = self.conn[self.db_config.get('database', 'monitor')]
            
            elif self.db_type == 'dm':
                import dmPython
                self.conn = dmPython.connect(
                    user=self.db_config.get('user', 'SYSDBA'),
                    password=self.db_config.get('password', 'SYSDBA'),
                    server=self.db_config.get('host', 'localhost'),
                    port=self.db_config.get('port', 5236)
                )
                self.cursor = self.conn.cursor()
                # 测试连接
                self.cursor.execute("SELECT 1")
            
            elif self.db_type == 'kb':
                import psycopg2
                self.conn = psycopg2.connect(
                    host=self.db_config.get('host', 'localhost'),
                    port=self.db_config.get('port', 54321),
                    user=self.db_config.get('user', 'system'),
                    password=self.db_config.get('password', 'manager'),
                    database=self.db_config.get('database', 'monitor')
                )
                self.cursor = self.conn.cursor()
                # 测试连接
                self.cursor.execute("SELECT 1")
            
            logger.info(f"成功连接到{self.db_type}数据库")
            return True
        except Exception as e:
            logger.error(f"连接{self.db_type}数据库失败: {e}")
            # 确保连接被关闭
            self.disconnect()
            return False
    
    def disconnect(self):
        """断开数据库连接"""
        try:
            if self.cursor:
                self.cursor.close()
            if self.conn:
                self.conn.close()
            logger.info(f"已断开{self.db_type}数据库连接")
        except Exception as e:
            logger.error(f"断开数据库连接失败: {e}")
    
    def create_tables(self):
        """创建数据库表结构"""
        try:
            if self.db_type == 'mongodb':
                # MongoDB不需要创建表结构
                return True
            
            # 创建主表
            if self.db_type in ['mysql', 'dm', 'kb']:
                self.cursor.execute('''
                    CREATE TABLE IF NOT EXISTS monitor_main (
                        id INT AUTO_INCREMENT PRIMARY KEY,
                        instance_name VARCHAR(255) NOT NULL,
                        timestamp DATETIME NOT NULL,
                        monitor_time DOUBLE NOT NULL,
                        connection_status BOOLEAN,
                        connection_count INT,
                        connection_percent DOUBLE,
                        qps DOUBLE,
                        slow_queries INT,
                        cache_hit_rate DOUBLE,
                        tablespace_usage DOUBLE,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
                ''')
            
            elif self.db_type == 'postgresql':
                self.cursor.execute('''
                    CREATE TABLE IF NOT EXISTS monitor_main (
                        id SERIAL PRIMARY KEY,
                        instance_name VARCHAR(255) NOT NULL,
                        timestamp TIMESTAMP NOT NULL,
                        monitor_time DOUBLE PRECISION NOT NULL,
                        connection_status BOOLEAN,
                        connection_count INTEGER,
                        connection_percent DOUBLE PRECISION,
                        qps DOUBLE PRECISION,
                        slow_queries INTEGER,
                        cache_hit_rate DOUBLE PRECISION,
                        tablespace_usage DOUBLE PRECISION,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                ''')
            
            elif self.db_type == 'oracle':
                self.cursor.execute('''
                    CREATE TABLE IF NOT EXISTS monitor_main (
                        id NUMBER GENERATED BY DEFAULT ON NULL AS IDENTITY PRIMARY KEY,
                        instance_name VARCHAR2(255) NOT NULL,
                        timestamp TIMESTAMP NOT NULL,
                        monitor_time NUMBER(15,2) NOT NULL,
                        connection_status NUMBER(1),
                        connection_count NUMBER,
                        connection_percent NUMBER(10,2),
                        qps NUMBER(15,2),
                        slow_queries NUMBER,
                        cache_hit_rate NUMBER(10,2),
                        tablespace_usage NUMBER(10,2),
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                ''')
            
            elif self.db_type == 'mssql':
                self.cursor.execute('''
                    IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='monitor_main' AND xtype='U')
                    CREATE TABLE monitor_main (
                        id INT IDENTITY(1,1) PRIMARY KEY,
                        instance_name VARCHAR(255) NOT NULL,
                        timestamp DATETIME NOT NULL,
                        monitor_time FLOAT NOT NULL,
                        connection_status BIT,
                        connection_count INT,
                        connection_percent FLOAT,
                        qps FLOAT,
                        slow_queries INT,
                        cache_hit_rate FLOAT,
                        tablespace_usage FLOAT,
                        created_at DATETIME DEFAULT GETDATE()
                    )
                ''')
            
            # 创建告警表
            if self.db_type in ['mysql', 'dm', 'kb']:
                self.cursor.execute('''
                    CREATE TABLE IF NOT EXISTS monitor_alerts (
                        id INT AUTO_INCREMENT PRIMARY KEY,
                        instance_name VARCHAR(255) NOT NULL,
                        timestamp DATETIME NOT NULL,
                        level VARCHAR(50) NOT NULL,
                        message TEXT NOT NULL,
                        metric VARCHAR(100) NOT NULL,
                        value DOUBLE,
                        threshold DOUBLE,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
                ''')
            
            elif self.db_type == 'postgresql':
                self.cursor.execute('''
                    CREATE TABLE IF NOT EXISTS monitor_alerts (
                        id SERIAL PRIMARY KEY,
                        instance_name VARCHAR(255) NOT NULL,
                        timestamp TIMESTAMP NOT NULL,
                        level VARCHAR(50) NOT NULL,
                        message TEXT NOT NULL,
                        metric VARCHAR(100) NOT NULL,
                        value DOUBLE PRECISION,
                        threshold DOUBLE PRECISION,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                ''')
            
            elif self.db_type == 'oracle':
                self.cursor.execute('''
                    CREATE TABLE IF NOT EXISTS monitor_alerts (
                        id NUMBER GENERATED BY DEFAULT ON NULL AS IDENTITY PRIMARY KEY,
                        instance_name VARCHAR2(255) NOT NULL,
                        timestamp TIMESTAMP NOT NULL,
                        level VARCHAR2(50) NOT NULL,
                        message CLOB NOT NULL,
                        metric VARCHAR2(100) NOT NULL,
                        value NUMBER(15,2),
                        threshold NUMBER(15,2),
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                ''')
            
            elif self.db_type == 'mssql':
                self.cursor.execute('''
                    IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='monitor_alerts' AND xtype='U')
                    CREATE TABLE monitor_alerts (
                        id INT IDENTITY(1,1) PRIMARY KEY,
                        instance_name VARCHAR(255) NOT NULL,
                        timestamp DATETIME NOT NULL,
                        level VARCHAR(50) NOT NULL,
                        message TEXT NOT NULL,
                        metric VARCHAR(100) NOT NULL,
                        value FLOAT,
                        threshold FLOAT,
                        created_at DATETIME DEFAULT GETDATE()
                    )
                ''')
            
            # 提交事务
            if self.db_type != 'mongodb':
                self.conn.commit()
            
            logger.info("成功创建数据库表结构")
            return True
        except Exception as e:
            logger.error(f"创建数据库表结构失败: {e}")
            if self.conn and self.db_type != 'mongodb':
                self.conn.rollback()
            return False
    
    def write_monitor_data(self, monitor_data):
        """写入监控数据到数据库"""
        try:
            instance_name = monitor_data.get('instance_name', '')
            timestamp_str = monitor_data.get('timestamp', '')
            monitor_time = monitor_data.get('monitor_time', 0)
            stats = monitor_data.get('stats', {})
            alerts = monitor_data.get('alerts', [])
            
            # 解析时间戳
            try:
                timestamp = datetime.strptime(timestamp_str, '%Y-%m-%d %H:%M:%S')
            except:
                timestamp = datetime.now()
            
            # 提取关键指标
            connection_status = stats.get('connection_status', False)
            connection_count = None
            connection_percent = None
            if stats.get('connection_stats'):
                connection_count = stats['connection_stats'].get('current_connections')
                connection_percent = stats['connection_stats'].get('connection_percent')
            
            qps = None
            if stats.get('qps'):
                qps = stats['qps'].get('qps')
            
            slow_queries = None
            if stats.get('slow_queries'):
                slow_queries = stats['slow_queries'].get('slow_queries')
            
            cache_hit_rate = None
            if stats.get('cache_hit_rate'):
                cache_hit_rate = stats['cache_hit_rate'].get('cache_hit_rate')
            
            tablespace_usage = None
            if stats.get('tablespace_usage'):
                if isinstance(stats['tablespace_usage'], list) and len(stats['tablespace_usage']) > 0:
                    # 取第一个表空间的使用率作为代表
                    tablespace_usage = stats['tablespace_usage'][0].get('usage_percent')
                elif isinstance(stats['tablespace_usage'], dict):
                    # MongoDB的存储空间使用情况
                    tablespace_usage = stats['tablespace_usage'].get('usage_percent')
            
            # 写入主表
            if self.db_type == 'mongodb':
                # MongoDB写入方式
                main_data = {
                    'instance_name': instance_name,
                    'timestamp': timestamp,
                    'monitor_time': monitor_time,
                    'connection_status': connection_status,
                    'connection_count': connection_count,
                    'connection_percent': connection_percent,
                    'qps': qps,
                    'slow_queries': slow_queries,
                    'cache_hit_rate': cache_hit_rate,
                    'tablespace_usage': tablespace_usage,
                    'stats': stats,
                    'created_at': datetime.now()
                }
                self.db.monitor_main.insert_one(main_data)
            
            else:
                # 关系型数据库写入方式
                if self.db_type == 'mysql':
                    self.cursor.execute('''
                        INSERT INTO monitor_main (
                            instance_name, timestamp, monitor_time, connection_status, 
                            connection_count, connection_percent, qps, slow_queries, 
                            cache_hit_rate, tablespace_usage
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    ''', (
                        instance_name, timestamp, monitor_time, connection_status,
                        connection_count, connection_percent, qps, slow_queries,
                        cache_hit_rate, tablespace_usage
                    ))
                
                elif self.db_type == 'postgresql':
                    self.cursor.execute('''
                        INSERT INTO monitor_main (
                            instance_name, timestamp, monitor_time, connection_status, 
                            connection_count, connection_percent, qps, slow_queries, 
                            cache_hit_rate, tablespace_usage
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    ''', (
                        instance_name, timestamp, monitor_time, connection_status,
                        connection_count, connection_percent, qps, slow_queries,
                        cache_hit_rate, tablespace_usage
                    ))
                
                elif self.db_type == 'oracle':
                    self.cursor.execute('''
                        INSERT INTO monitor_main (
                            instance_name, timestamp, monitor_time, connection_status, 
                            connection_count, connection_percent, qps, slow_queries, 
                            cache_hit_rate, tablespace_usage
                        ) VALUES (:1, :2, :3, :4, :5, :6, :7, :8, :9, :10)
                    ''', (
                        instance_name, timestamp, monitor_time, 1 if connection_status else 0,
                        connection_count, connection_percent, qps, slow_queries,
                        cache_hit_rate, tablespace_usage
                    ))
                
                elif self.db_type == 'mssql':
                    self.cursor.execute('''
                        INSERT INTO monitor_main (
                            instance_name, timestamp, monitor_time, connection_status, 
                            connection_count, connection_percent, qps, slow_queries, 
                            cache_hit_rate, tablespace_usage
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ''', (
                        instance_name, timestamp, monitor_time, connection_status,
                        connection_count, connection_percent, qps, slow_queries,
                        cache_hit_rate, tablespace_usage
                    ))
                
                elif self.db_type in ['dm', 'kb']:
                    self.cursor.execute('''
                        INSERT INTO monitor_main (
                            instance_name, timestamp, monitor_time, connection_status, 
                            connection_count, connection_percent, qps, slow_queries, 
                            cache_hit_rate, tablespace_usage
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    ''', (
                        instance_name, timestamp, monitor_time, connection_status,
                        connection_count, connection_percent, qps, slow_queries,
                        cache_hit_rate, tablespace_usage
                    ))
            
            # 写入告警数据
            for alert in alerts:
                if self.db_type == 'mongodb':
                    alert_data = {
                        'instance_name': instance_name,
                        'timestamp': timestamp,
                        'level': alert.get('level', ''),
                        'message': alert.get('message', ''),
                        'metric': alert.get('metric', ''),
                        'value': alert.get('value'),
                        'threshold': alert.get('threshold'),
                        'created_at': datetime.now()
                    }
                    self.db.monitor_alerts.insert_one(alert_data)
                else:
                    if self.db_type == 'oracle':
                        self.cursor.execute('''
                            INSERT INTO monitor_alerts (
                                instance_name, timestamp, level, message, 
                                metric, value, threshold
                            ) VALUES (:1, :2, :3, :4, :5, :6, :7)
                        ''', (
                            instance_name, timestamp, alert.get('level', ''),
                            alert.get('message', ''), alert.get('metric', ''),
                            alert.get('value'), alert.get('threshold')
                        ))
                    else:
                        self.cursor.execute('''
                            INSERT INTO monitor_alerts (
                                instance_name, timestamp, level, message, 
                                metric, value, threshold
                            ) VALUES (%s, %s, %s, %s, %s, %s, %s)
                        ''', (
                            instance_name, timestamp, alert.get('level', ''),
                            alert.get('message', ''), alert.get('metric', ''),
                            alert.get('value'), alert.get('threshold')
                        ))
            
            # 提交事务
            if self.db_type != 'mongodb':
                self.conn.commit()
            
            logger.info(f"成功写入监控数据: {instance_name} - {timestamp_str}")
            return True
        except Exception as e:
            logger.error(f"写入监控数据失败: {e}")
            if self.conn and self.db_type != 'mongodb':
                self.conn.rollback()
            return False

def read_json_files(monitor_dir):
    """读取监控目录下的JSON文件"""
    json_files = []
    
    try:
        # 遍历监控目录
        for root, dirs, files in os.walk(monitor_dir):
            for file in files:
                if file.endswith('.json'):
                    file_path = os.path.join(root, file)
                    try:
                        with open(file_path, 'r', encoding='utf-8') as f:
                            data = json.load(f)
                            json_files.append((file_path, data))
                    except Exception as e:
                        logger.error(f"读取JSON文件失败: {file_path} - {e}")
        
        logger.info(f"成功读取 {len(json_files)} 个JSON文件")
        return json_files
    except Exception as e:
        logger.error(f"扫描监控目录失败: {e}")
        return []

def load_config_from_file(config_file):
    """从配置文件加载配置"""
    try:
        if os.path.exists(config_file):
            with open(config_file, 'r', encoding='utf-8') as f:
                config = json.load(f)
            logger.info(f"成功从配置文件加载配置: {config_file}")
            return config
        else:
            logger.warning(f"配置文件不存在: {config_file}")
            return {}
    except Exception as e:
        logger.error(f"加载配置文件失败: {e}")
        return {}

def main():
    """主函数"""
    # 先加载配置文件以获取默认数据库类型
    default_config_file = os.path.join(os.path.dirname(__file__), 'monitor_to_db_config.json')
    default_config = load_config_from_file(default_config_file)
    
    # 解析命令行参数
    parser = argparse.ArgumentParser(description='监控数据入库脚本')
    parser.add_argument('--monitor-dir', type=str, 
                        default=os.path.join(os.path.dirname(__file__), 'monitor'),
                        help='监控结果目录')
    parser.add_argument('--batch-size', type=int, default=100, help='批量处理大小')
    parser.add_argument('--config-file', type=str, 
                        default=default_config_file,
                        help='配置文件路径')
    parser.add_argument('--log-level', type=str, default='INFO', 
                        choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'],
                        help='日志级别')
    parser.add_argument('--continuous', action='store_true', 
                        help='是否持续监控目录')
    parser.add_argument('--interval', type=int, default=60, 
                        help='持续监控的时间间隔（秒）')
    
    args = parser.parse_args()
    
    # 从配置文件中获取数据库类型
    db_type = default_config.get('db_type', 'mysql')
    if db_type not in ['mysql', 'postgresql', 'oracle', 'mssql', 'mongodb', 'dm', 'kb']:
        logger.error(f"不支持的数据库类型: {db_type}")
        return
    
    # 设置日志级别
    numeric_level = getattr(logging, args.log_level.upper(), None)
    if isinstance(numeric_level, int):
        logging.getLogger().setLevel(numeric_level)
    
    # 加载配置文件
    config = load_config_from_file(args.config_file)
    
    # 构建数据库配置
    db_config = {
        'host': os.getenv(f'{db_type.upper()}_HOST') or config.get('host') or 'localhost',
        'port': (os.getenv(f'{db_type.upper()}_PORT') and int(os.getenv(f'{db_type.upper()}_PORT'))) or config.get('port'),
        'user': os.getenv(f'{db_type.upper()}_USER') or config.get('user'),
        'password': os.getenv(f'{db_type.upper()}_PASSWORD') or config.get('password'),
        'database': os.getenv(f'{db_type.upper()}_DATABASE') or config.get('database') or 'monitor',
        'sid': os.getenv(f'{db_type.upper()}_SID') or config.get('sid') or 'ORCL'
    }
    
    # 过滤掉None值
    db_config = {k: v for k, v in db_config.items() if v is not None}
    
    # 打印配置信息（隐藏密码）
    config_info = db_config.copy()
    if 'password' in config_info:
        config_info['password'] = '******'
    logger.info(f"数据库类型: {db_type}")
    logger.info(f"数据库配置: {json.dumps(config_info, ensure_ascii=False)}")
    
    # 创建数据库写入器
    writer = DatabaseWriter(db_type, db_config)
    
    # 连接数据库
    if not writer.connect():
        logger.error("无法连接到数据库，退出脚本")
        return
    
    # 创建表结构
    if not writer.create_tables():
        logger.error("无法创建表结构，退出脚本")
        writer.disconnect()
        return
    
    if args.continuous:
        logger.info(f"启动持续监控模式，监控目录: {args.monitor_dir}，间隔: {args.interval}秒")
        
        # 记录已处理的文件
        processed_files = set()
        
        try:
            while True:
                # 读取JSON文件
                json_files = read_json_files(args.monitor_dir)
                
                # 过滤出未处理的文件
                new_files = [(file_path, data) for file_path, data in json_files if file_path not in processed_files]
                
                if new_files:
                    logger.info(f"发现 {len(new_files)} 个新的监控文件")
                    
                    # 写入数据
                    success_count = 0
                    failed_count = 0
                    
                    for file_path, data in new_files:
                        if writer.write_monitor_data(data):
                            success_count += 1
                            processed_files.add(file_path)
                        else:
                            failed_count += 1
                        
                        # 每处理10个文件提交一次
                        if (success_count + failed_count) % 10 == 0:
                            logger.info(f"已处理 {success_count + failed_count}/{len(new_files)} 个文件，成功: {success_count}, 失败: {failed_count}")
                    
                    # 输出结果
                    logger.info(f"批次处理完成")
                    logger.info(f"总文件数: {len(new_files)}")
                    logger.info(f"成功入库: {success_count}")
                    logger.info(f"失败数量: {failed_count}")
                else:
                    logger.debug("没有发现新的监控文件")
                
                # 等待指定的时间间隔
                logger.debug(f"等待 {args.interval} 秒后再次检查")
                time.sleep(args.interval)
                
        except KeyboardInterrupt:
            logger.info("持续监控已手动停止")
        except Exception as e:
            logger.error(f"持续监控过程中发生错误: {e}")
    else:
        # 一次性运行模式
        # 读取JSON文件
        json_files = read_json_files(args.monitor_dir)
        
        if not json_files:
            logger.warning("没有找到监控JSON文件，退出脚本")
            writer.disconnect()
            return
        
        # 写入数据
        success_count = 0
        failed_count = 0
        
        for file_path, data in json_files:
            if writer.write_monitor_data(data):
                success_count += 1
            else:
                failed_count += 1
            
            # 每处理10个文件提交一次
            if (success_count + failed_count) % 10 == 0:
                logger.info(f"已处理 {success_count + failed_count}/{len(json_files)} 个文件，成功: {success_count}, 失败: {failed_count}")
        
        # 输出结果
        logger.info(f"监控数据入库完成")
        logger.info(f"总文件数: {len(json_files)}")
        logger.info(f"成功入库: {success_count}")
        logger.info(f"失败数量: {failed_count}")
    
    # 断开连接
    writer.disconnect()

if __name__ == "__main__":
    main()