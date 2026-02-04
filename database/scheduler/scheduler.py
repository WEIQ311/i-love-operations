#!/usr/bin/env python3
import os
import time
import json
import logging
import importlib
import threading
import concurrent.futures
from datetime import datetime
from dotenv import load_dotenv

# 加载配置文件
load_dotenv()

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('scheduler.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# 数据库类型映射
DB_TYPE_MAPPING = {
    'mysql': {
        'module': 'mysql.mysql_monitor',
        'class': 'MySQLMonitor',
        'config_prefix': 'MYSQL'
    },
    'postgresql': {
        'module': 'pg.postgresql_monitor',
        'class': 'PostgreSQLMonitor',
        'config_prefix': 'POSTGRES'
    },
    'dm': {
        'module': 'dm.dm_monitor',
        'class': 'DMMonitor',
        'config_prefix': 'DM'
    },
    'kb': {
        'module': 'kb.kb_monitor',
        'class': 'KingbaseMonitor',
        'config_prefix': 'KB'
    },
    'oracle': {
        'module': 'oracle.oracle_monitor',
        'class': 'OracleMonitor',
        'config_prefix': 'ORACLE'
    },
    'mssql': {
        'module': 'mssql.mssql_monitor',
        'class': 'MSSQLMonitor',
        'config_prefix': 'MSSQL'
    },
    'mongodb': {
        'module': 'mongodb.mongodb_monitor',
        'class': 'MongoDBMonitor',
        'config_prefix': 'MONGO'
    }
}

class DatabaseScheduler:
    def __init__(self, config_file='config.json'):
        self.config_file = config_file
        self.config = self.load_config()
        self.db_instances = self.config.get('database_instances', [])
        self.concurrent_execution = self.config.get('concurrent_execution', True)
    
    def load_config(self):
        """加载配置文件"""
        try:
            if os.path.exists(self.config_file):
                with open(self.config_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
            else:
                # 返回默认配置
                return {
                    'concurrent_execution': True,
                    'database_instances': []
                }
        except Exception as e:
            logger.error(f"加载配置文件失败: {e}")
            return {
                'concurrent_execution': True,
                'database_instances': []
            }
    
    def save_config(self):
        """保存配置文件"""
        try:
            with open(self.config_file, 'w', encoding='utf-8') as f:
                json.dump(self.config, f, ensure_ascii=False, indent=2)
            logger.info(f"配置文件已保存到 {self.config_file}")
        except Exception as e:
            logger.error(f"保存配置文件失败: {e}")
    
    def add_db_instance(self, db_type, name, config):
        """添加数据库实例"""
        if db_type not in DB_TYPE_MAPPING:
            logger.error(f"不支持的数据库类型: {db_type}")
            return False
        
        instance = {
            'type': db_type,
            'name': name,
            'config': config,
            'enabled': True
        }
        
        self.db_instances.append(instance)
        self.config['database_instances'] = self.db_instances
        self.save_config()
        logger.info(f"添加数据库实例成功: {name} ({db_type})")
        return True
    
    def run_monitor(self, db_instance):
        """运行单个数据库监控"""
        db_type = db_instance['type']
        db_name = db_instance['name']
        db_config = db_instance['config']
        
        logger.info(f"开始监控数据库实例: {db_name} ({db_type})")
        
        try:
            # 动态导入监控模块
            module_info = DB_TYPE_MAPPING[db_type]
            module_path = module_info['module']
            class_name = module_info['class']
            
            # 添加数据库目录到Python路径
            import sys
            sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
            
            # 导入模块
            module = importlib.import_module(module_path)
            monitor_class = getattr(module, class_name)
            
            # 创建监控实例并传递配置和实例名称
            monitor = monitor_class(config=db_config, instance_name=db_name)
            
            # 确保统一监控目录存在，并按日期分目录
            import datetime
            current_date = datetime.datetime.now().strftime('%Y-%m-%d')
            monitor_root_dir = os.path.join(os.path.dirname(__file__), 'monitor')
            monitor_date_dir = os.path.join(monitor_root_dir, current_date)
            if not os.path.exists(monitor_date_dir):
                os.makedirs(monitor_date_dir)
                logger.info(f"创建监控目录: {monitor_date_dir}")
            
            # 运行监控，传递统一的存储目录
            monitor.run_monitor(monitor_dir=monitor_date_dir)
            
            logger.info(f"监控数据库实例完成: {db_name} ({db_type})")
            return True
        except Exception as e:
            logger.error(f"监控数据库实例失败: {db_name} ({db_type}) - {e}")
            return False
    
    def run_all_monitors(self):
        """运行所有数据库监控"""
        logger.info(f"开始执行所有数据库监控 (共 {len(self.db_instances)} 个实例)")
        
        enabled_instances = [instance for instance in self.db_instances if instance.get('enabled', True)]
        logger.info(f"启用的实例数: {len(enabled_instances)}")
        
        if self.concurrent_execution:
            # 并发执行
            with concurrent.futures.ThreadPoolExecutor(max_workers=min(10, len(enabled_instances))) as executor:
                futures = {executor.submit(self.run_monitor, instance): instance for instance in enabled_instances}
                
                for future in concurrent.futures.as_completed(futures):
                    instance = futures[future]
                    try:
                        future.result()
                    except Exception as e:
                        logger.error(f"执行监控失败: {instance['name']} ({instance['type']}) - {e}")
        else:
            # 顺序执行
            for instance in enabled_instances:
                self.run_monitor(instance)
        
        logger.info("所有数据库监控执行完成")
    
    def run_scheduler(self):
        """运行调度器"""
        logger.info("启动数据库监控调度器")
        
        try:
            start_time = datetime.now()
            
            # 运行所有监控
            self.run_all_monitors()
            
            # 计算执行时间
            execution_time = (datetime.now() - start_time).total_seconds()
            logger.info(f"监控执行完成，总耗时: {execution_time:.2f}秒")
        except KeyboardInterrupt:
            logger.info("调度器已手动停止")
        except Exception as e:
            logger.error(f"调度器运行失败: {e}")
    
    def test_connection(self, db_instance):
        """测试数据库连接"""
        db_type = db_instance['type']
        db_name = db_instance['name']
        
        logger.info(f"测试数据库连接: {db_name} ({db_type})")
        
        try:
            # 动态导入监控模块
            module_info = DB_TYPE_MAPPING[db_type]
            module_path = module_info['module']
            class_name = module_info['class']
            
            # 添加数据库目录到Python路径
            import sys
            sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
            
            # 导入模块
            module = importlib.import_module(module_path)
            monitor_class = getattr(module, class_name)
            
            # 创建监控实例并传递配置
            monitor = monitor_class(config=db_instance['config'])
            
            # 测试连接
            if monitor.connect():
                logger.info(f"数据库连接测试成功: {db_name} ({db_type})")
                monitor.disconnect()
                return True
            else:
                logger.error(f"数据库连接测试失败: {db_name} ({db_type})")
                return False
        except Exception as e:
            logger.error(f"测试数据库连接失败: {db_name} ({db_type}) - {e}")
            return False

def main():
    """主函数"""
    scheduler = DatabaseScheduler()
    
    # 检查是否有数据库实例配置
    if not scheduler.db_instances:
        logger.warning("未配置数据库实例，请在 config.json 中添加数据库实例")
        logger.info("示例配置:")
        example_config = {
            "database_instances": [
                {
                    "type": "mysql",
                    "name": "mysql_prod",
                    "enabled": true,
                    "config": {
                        "host": "localhost",
                        "port": 3306,
                        "user": "root",
                        "password": "password",
                        "database": "information_schema"
                    }
                }
            ]
        }
        logger.info(json.dumps(example_config, ensure_ascii=False, indent=2))
    
    # 运行调度器
    scheduler.run_scheduler()

if __name__ == "__main__":
    main()
