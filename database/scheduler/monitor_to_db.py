#!/usr/bin/env python3
import os
import json
import time
import logging
import argparse
import re
import concurrent.futures
from datetime import datetime, timedelta
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
                        id INT AUTO_INCREMENT PRIMARY KEY COMMENT '主键ID',
                        instance_name VARCHAR(255) NOT NULL COMMENT '实例名称',
                        timestamp DATETIME NOT NULL COMMENT '监控时间戳',
                        monitor_time DOUBLE NOT NULL COMMENT '监控时间戳（Unix时间）',
                        connection_status BOOLEAN COMMENT '连接状态',
                        connection_count INT COMMENT '当前连接数',
                        connection_percent DOUBLE COMMENT '连接使用率',
                        threads_running INT COMMENT '运行中的线程数',
                        threads_connected INT COMMENT '已连接的线程数',
                        threads_created INT COMMENT '已创建的线程数',
                        threads_cached INT COMMENT '缓存的线程数',
                        qps DOUBLE COMMENT '每秒查询数',
                        total_queries BIGINT COMMENT '总查询数',
                        uptime INT COMMENT '数据库运行时间（秒）',
                        slow_queries INT COMMENT '慢查询数',
                        long_query_time DOUBLE COMMENT '慢查询阈值（秒）',
                        slow_query_log VARCHAR(50) COMMENT '慢查询日志状态',
                        innodb_cache_hit_rate DOUBLE COMMENT 'InnoDB缓存命中率',
                        query_cache_hit_rate DOUBLE COMMENT '查询缓存命中率',
                        tablespace_usage DOUBLE COMMENT '表空间使用率',
                        replication_status TEXT COMMENT '复制状态',
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '记录创建时间'
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
                        threads_running INTEGER,
                        threads_connected INTEGER,
                        threads_created INTEGER,
                        threads_cached INTEGER,
                        qps DOUBLE PRECISION,
                        total_queries BIGINT,
                        uptime INTEGER,
                        slow_queries INTEGER,
                        long_query_time DOUBLE PRECISION,
                        slow_query_log VARCHAR(50),
                        innodb_cache_hit_rate DOUBLE PRECISION,
                        query_cache_hit_rate DOUBLE PRECISION,
                        tablespace_usage DOUBLE PRECISION,
                        replication_status TEXT,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                ''')
                # 添加字段注释
                self.cursor.execute("COMMENT ON COLUMN monitor_main.id IS '主键ID'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.instance_name IS '实例名称'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.timestamp IS '监控时间戳'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.monitor_time IS '监控时间戳（Unix时间）'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.connection_status IS '连接状态'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.connection_count IS '当前连接数'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.connection_percent IS '连接使用率'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.threads_running IS '运行中的线程数'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.threads_connected IS '已连接的线程数'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.threads_created IS '已创建的线程数'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.threads_cached IS '缓存的线程数'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.qps IS '每秒查询数'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.total_queries IS '总查询数'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.uptime IS '数据库运行时间（秒）'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.slow_queries IS '慢查询数'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.long_query_time IS '慢查询阈值（秒）'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.slow_query_log IS '慢查询日志状态'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.innodb_cache_hit_rate IS 'InnoDB缓存命中率'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.query_cache_hit_rate IS '查询缓存命中率'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.tablespace_usage IS '表空间使用率'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.replication_status IS '复制状态'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.created_at IS '记录创建时间'")
            
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
                        threads_running NUMBER,
                        threads_connected NUMBER,
                        threads_created NUMBER,
                        threads_cached NUMBER,
                        qps NUMBER(15,2),
                        total_queries NUMBER,
                        uptime NUMBER,
                        slow_queries NUMBER,
                        long_query_time NUMBER(10,2),
                        slow_query_log VARCHAR2(50),
                        innodb_cache_hit_rate NUMBER(10,2),
                        query_cache_hit_rate NUMBER(10,2),
                        tablespace_usage NUMBER(10,2),
                        replication_status CLOB,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                ''')
                # 添加字段注释
                self.cursor.execute("COMMENT ON COLUMN monitor_main.id IS '主键ID'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.instance_name IS '实例名称'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.timestamp IS '监控时间戳'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.monitor_time IS '监控时间戳（Unix时间）'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.connection_status IS '连接状态'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.connection_count IS '当前连接数'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.connection_percent IS '连接使用率'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.threads_running IS '运行中的线程数'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.threads_connected IS '已连接的线程数'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.threads_created IS '已创建的线程数'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.threads_cached IS '缓存的线程数'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.qps IS '每秒查询数'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.total_queries IS '总查询数'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.uptime IS '数据库运行时间（秒）'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.slow_queries IS '慢查询数'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.long_query_time IS '慢查询阈值（秒）'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.slow_query_log IS '慢查询日志状态'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.innodb_cache_hit_rate IS 'InnoDB缓存命中率'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.query_cache_hit_rate IS '查询缓存命中率'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.tablespace_usage IS '表空间使用率'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.replication_status IS '复制状态'")
                self.cursor.execute("COMMENT ON COLUMN monitor_main.created_at IS '记录创建时间'")
            
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
                        threads_running INT,
                        threads_connected INT,
                        threads_created INT,
                        threads_cached INT,
                        qps FLOAT,
                        total_queries BIGINT,
                        uptime INT,
                        slow_queries INT,
                        long_query_time FLOAT,
                        slow_query_log VARCHAR(50),
                        innodb_cache_hit_rate FLOAT,
                        query_cache_hit_rate FLOAT,
                        tablespace_usage FLOAT,
                        replication_status TEXT,
                        created_at DATETIME DEFAULT GETDATE()
                    )
                ''')
                # 添加字段注释，使用条件执行避免重复添加
                # 检查并添加id字段注释
                self.cursor.execute("IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE name='MS_Description' AND major_id=OBJECT_ID('monitor_main') AND minor_id=COLUMNPROPERTY(OBJECT_ID('monitor_main'), 'id', 'ColumnId')) EXEC sp_addextendedproperty @name=N'MS_Description', @value=N'主键ID', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'monitor_main', @level2type=N'COLUMN',@level2name=N'id'")
                # 检查并添加instance_name字段注释
                self.cursor.execute("IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE name='MS_Description' AND major_id=OBJECT_ID('monitor_main') AND minor_id=COLUMNPROPERTY(OBJECT_ID('monitor_main'), 'instance_name', 'ColumnId')) EXEC sp_addextendedproperty @name=N'MS_Description', @value=N'实例名称', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'monitor_main', @level2type=N'COLUMN',@level2name=N'instance_name'")
                # 检查并添加timestamp字段注释
                self.cursor.execute("IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE name='MS_Description' AND major_id=OBJECT_ID('monitor_main') AND minor_id=COLUMNPROPERTY(OBJECT_ID('monitor_main'), 'timestamp', 'ColumnId')) EXEC sp_addextendedproperty @name=N'MS_Description', @value=N'监控时间戳', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'monitor_main', @level2type=N'COLUMN',@level2name=N'timestamp'")
                # 检查并添加monitor_time字段注释
                self.cursor.execute("IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE name='MS_Description' AND major_id=OBJECT_ID('monitor_main') AND minor_id=COLUMNPROPERTY(OBJECT_ID('monitor_main'), 'monitor_time', 'ColumnId')) EXEC sp_addextendedproperty @name=N'MS_Description', @value=N'监控时间戳（Unix时间）', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'monitor_main', @level2type=N'COLUMN',@level2name=N'monitor_time'")
                # 检查并添加connection_status字段注释
                self.cursor.execute("IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE name='MS_Description' AND major_id=OBJECT_ID('monitor_main') AND minor_id=COLUMNPROPERTY(OBJECT_ID('monitor_main'), 'connection_status', 'ColumnId')) EXEC sp_addextendedproperty @name=N'MS_Description', @value=N'连接状态', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'monitor_main', @level2type=N'COLUMN',@level2name=N'connection_status'")
                # 检查并添加connection_count字段注释
                self.cursor.execute("IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE name='MS_Description' AND major_id=OBJECT_ID('monitor_main') AND minor_id=COLUMNPROPERTY(OBJECT_ID('monitor_main'), 'connection_count', 'ColumnId')) EXEC sp_addextendedproperty @name=N'MS_Description', @value=N'当前连接数', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'monitor_main', @level2type=N'COLUMN',@level2name=N'connection_count'")
                # 检查并添加connection_percent字段注释
                self.cursor.execute("IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE name='MS_Description' AND major_id=OBJECT_ID('monitor_main') AND minor_id=COLUMNPROPERTY(OBJECT_ID('monitor_main'), 'connection_percent', 'ColumnId')) EXEC sp_addextendedproperty @name=N'MS_Description', @value=N'连接使用率', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'monitor_main', @level2type=N'COLUMN',@level2name=N'connection_percent'")
                # 检查并添加threads_running字段注释
                self.cursor.execute("IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE name='MS_Description' AND major_id=OBJECT_ID('monitor_main') AND minor_id=COLUMNPROPERTY(OBJECT_ID('monitor_main'), 'threads_running', 'ColumnId')) EXEC sp_addextendedproperty @name=N'MS_Description', @value=N'运行中的线程数', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'monitor_main', @level2type=N'COLUMN',@level2name=N'threads_running'")
                # 检查并添加threads_connected字段注释
                self.cursor.execute("IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE name='MS_Description' AND major_id=OBJECT_ID('monitor_main') AND minor_id=COLUMNPROPERTY(OBJECT_ID('monitor_main'), 'threads_connected', 'ColumnId')) EXEC sp_addextendedproperty @name=N'MS_Description', @value=N'已连接的线程数', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'monitor_main', @level2type=N'COLUMN',@level2name=N'threads_connected'")
                # 检查并添加threads_created字段注释
                self.cursor.execute("IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE name='MS_Description' AND major_id=OBJECT_ID('monitor_main') AND minor_id=COLUMNPROPERTY(OBJECT_ID('monitor_main'), 'threads_created', 'ColumnId')) EXEC sp_addextendedproperty @name=N'MS_Description', @value=N'已创建的线程数', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'monitor_main', @level2type=N'COLUMN',@level2name=N'threads_created'")
                # 检查并添加threads_cached字段注释
                self.cursor.execute("IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE name='MS_Description' AND major_id=OBJECT_ID('monitor_main') AND minor_id=COLUMNPROPERTY(OBJECT_ID('monitor_main'), 'threads_cached', 'ColumnId')) EXEC sp_addextendedproperty @name=N'MS_Description', @value=N'缓存的线程数', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'monitor_main', @level2type=N'COLUMN',@level2name=N'threads_cached'")
                # 检查并添加qps字段注释
                self.cursor.execute("IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE name='MS_Description' AND major_id=OBJECT_ID('monitor_main') AND minor_id=COLUMNPROPERTY(OBJECT_ID('monitor_main'), 'qps', 'ColumnId')) EXEC sp_addextendedproperty @name=N'MS_Description', @value=N'每秒查询数', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'monitor_main', @level2type=N'COLUMN',@level2name=N'qps'")
                # 检查并添加total_queries字段注释
                self.cursor.execute("IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE name='MS_Description' AND major_id=OBJECT_ID('monitor_main') AND minor_id=COLUMNPROPERTY(OBJECT_ID('monitor_main'), 'total_queries', 'ColumnId')) EXEC sp_addextendedproperty @name=N'MS_Description', @value=N'总查询数', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'monitor_main', @level2type=N'COLUMN',@level2name=N'total_queries'")
                # 检查并添加uptime字段注释
                self.cursor.execute("IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE name='MS_Description' AND major_id=OBJECT_ID('monitor_main') AND minor_id=COLUMNPROPERTY(OBJECT_ID('monitor_main'), 'uptime', 'ColumnId')) EXEC sp_addextendedproperty @name=N'MS_Description', @value=N'数据库运行时间（秒）', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'monitor_main', @level2type=N'COLUMN',@level2name=N'uptime'")
                # 检查并添加slow_queries字段注释
                self.cursor.execute("IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE name='MS_Description' AND major_id=OBJECT_ID('monitor_main') AND minor_id=COLUMNPROPERTY(OBJECT_ID('monitor_main'), 'slow_queries', 'ColumnId')) EXEC sp_addextendedproperty @name=N'MS_Description', @value=N'慢查询数', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'monitor_main', @level2type=N'COLUMN',@level2name=N'slow_queries'")
                # 检查并添加long_query_time字段注释
                self.cursor.execute("IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE name='MS_Description' AND major_id=OBJECT_ID('monitor_main') AND minor_id=COLUMNPROPERTY(OBJECT_ID('monitor_main'), 'long_query_time', 'ColumnId')) EXEC sp_addextendedproperty @name=N'MS_Description', @value=N'慢查询阈值（秒）', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'monitor_main', @level2type=N'COLUMN',@level2name=N'long_query_time'")
                # 检查并添加slow_query_log字段注释
                self.cursor.execute("IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE name='MS_Description' AND major_id=OBJECT_ID('monitor_main') AND minor_id=COLUMNPROPERTY(OBJECT_ID('monitor_main'), 'slow_query_log', 'ColumnId')) EXEC sp_addextendedproperty @name=N'MS_Description', @value=N'慢查询日志状态', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'monitor_main', @level2type=N'COLUMN',@level2name=N'slow_query_log'")
                # 检查并添加innodb_cache_hit_rate字段注释
                self.cursor.execute("IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE name='MS_Description' AND major_id=OBJECT_ID('monitor_main') AND minor_id=COLUMNPROPERTY(OBJECT_ID('monitor_main'), 'innodb_cache_hit_rate', 'ColumnId')) EXEC sp_addextendedproperty @name=N'MS_Description', @value=N'InnoDB缓存命中率', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'monitor_main', @level2type=N'COLUMN',@level2name=N'innodb_cache_hit_rate'")
                # 检查并添加query_cache_hit_rate字段注释
                self.cursor.execute("IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE name='MS_Description' AND major_id=OBJECT_ID('monitor_main') AND minor_id=COLUMNPROPERTY(OBJECT_ID('monitor_main'), 'query_cache_hit_rate', 'ColumnId')) EXEC sp_addextendedproperty @name=N'MS_Description', @value=N'查询缓存命中率', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'monitor_main', @level2type=N'COLUMN',@level2name=N'query_cache_hit_rate'")
                # 检查并添加tablespace_usage字段注释
                self.cursor.execute("IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE name='MS_Description' AND major_id=OBJECT_ID('monitor_main') AND minor_id=COLUMNPROPERTY(OBJECT_ID('monitor_main'), 'tablespace_usage', 'ColumnId')) EXEC sp_addextendedproperty @name=N'MS_Description', @value=N'表空间使用率', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'monitor_main', @level2type=N'COLUMN',@level2name=N'tablespace_usage'")
                # 检查并添加replication_status字段注释
                self.cursor.execute("IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE name='MS_Description' AND major_id=OBJECT_ID('monitor_main') AND minor_id=COLUMNPROPERTY(OBJECT_ID('monitor_main'), 'replication_status', 'ColumnId')) EXEC sp_addextendedproperty @name=N'MS_Description', @value=N'复制状态', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'monitor_main', @level2type=N'COLUMN',@level2name=N'replication_status'")
                # 检查并添加created_at字段注释
                self.cursor.execute("IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE name='MS_Description' AND major_id=OBJECT_ID('monitor_main') AND minor_id=COLUMNPROPERTY(OBJECT_ID('monitor_main'), 'created_at', 'ColumnId')) EXEC sp_addextendedproperty @name=N'MS_Description', @value=N'记录创建时间', @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'monitor_main', @level2type=N'COLUMN',@level2name=N'created_at'")
            
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
                        value VARCHAR(255),
                        threshold VARCHAR(255),
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
                        value VARCHAR(255),
                        threshold VARCHAR(255),
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
                        value VARCHAR2(255),
                        threshold VARCHAR2(255),
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
                        value VARCHAR(255),
                        threshold VARCHAR(255),
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
            threads_running = None
            threads_connected = None
            threads_created = None
            threads_cached = None
            if stats.get('connection_stats'):
                connection_count = stats['connection_stats'].get('current_connections')
                connection_percent = stats['connection_stats'].get('connection_percent')
                threads_running = stats['connection_stats'].get('threads_running')
                threads_connected = stats['connection_stats'].get('threads_connected')
                threads_created = stats['connection_stats'].get('threads_created')
                threads_cached = stats['connection_stats'].get('threads_cached')
            
            qps = None
            total_queries = None
            uptime = None
            if stats.get('qps'):
                qps = stats['qps'].get('qps')
                total_queries = stats['qps'].get('total_queries')
                uptime = stats['qps'].get('uptime')
            
            slow_queries = None
            long_query_time = None
            slow_query_log = None
            if stats.get('slow_queries'):
                slow_queries = stats['slow_queries'].get('slow_queries')
                long_query_time = stats['slow_queries'].get('long_query_time')
                slow_query_log = stats['slow_queries'].get('slow_query_log')
            
            innodb_cache_hit_rate = None
            query_cache_hit_rate = None
            if stats.get('cache_hit_rate'):
                innodb_cache_hit_rate = stats['cache_hit_rate'].get('innodb_cache_hit_rate')
                query_cache_hit_rate = stats['cache_hit_rate'].get('query_cache_hit_rate')
            
            tablespace_usage = None
            if stats.get('tablespace_usage'):
                if isinstance(stats['tablespace_usage'], list) and len(stats['tablespace_usage']) > 0:
                    # 取第一个表空间的使用率作为代表
                    tablespace_usage = stats['tablespace_usage'][0].get('usage_percent')
                elif isinstance(stats['tablespace_usage'], dict):
                    # MongoDB的存储空间使用情况
                    tablespace_usage = stats['tablespace_usage'].get('usage_percent')
            
            # 提取复制状态
            replication_status = None
            if stats.get('replication_status'):
                replication_status = str(stats['replication_status'])
            
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
                    'threads_running': threads_running,
                    'threads_connected': threads_connected,
                    'threads_created': threads_created,
                    'threads_cached': threads_cached,
                    'qps': qps,
                    'total_queries': total_queries,
                    'uptime': uptime,
                    'slow_queries': slow_queries,
                    'long_query_time': long_query_time,
                    'slow_query_log': slow_query_log,
                    'innodb_cache_hit_rate': innodb_cache_hit_rate,
                    'query_cache_hit_rate': query_cache_hit_rate,
                    'tablespace_usage': tablespace_usage,
                    'replication_status': replication_status,
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
                            connection_count, connection_percent, threads_running, threads_connected, 
                            threads_created, threads_cached, qps, total_queries, uptime, 
                            slow_queries, long_query_time, slow_query_log, innodb_cache_hit_rate, 
                            query_cache_hit_rate, tablespace_usage, replication_status
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    ''', (
                        instance_name, timestamp, monitor_time, connection_status,
                        connection_count, connection_percent, threads_running, threads_connected,
                        threads_created, threads_cached, qps, total_queries, uptime,
                        slow_queries, long_query_time, slow_query_log, innodb_cache_hit_rate,
                        query_cache_hit_rate, tablespace_usage, replication_status
                    ))
                
                elif self.db_type == 'postgresql':
                    self.cursor.execute('''
                        INSERT INTO monitor_main (
                            instance_name, timestamp, monitor_time, connection_status, 
                            connection_count, connection_percent, threads_running, threads_connected, 
                            threads_created, threads_cached, qps, total_queries, uptime, 
                            slow_queries, long_query_time, slow_query_log, innodb_cache_hit_rate, 
                            query_cache_hit_rate, tablespace_usage, replication_status
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    ''', (
                        instance_name, timestamp, monitor_time, connection_status,
                        connection_count, connection_percent, threads_running, threads_connected,
                        threads_created, threads_cached, qps, total_queries, uptime,
                        slow_queries, long_query_time, slow_query_log, innodb_cache_hit_rate,
                        query_cache_hit_rate, tablespace_usage, replication_status
                    ))
                
                elif self.db_type == 'oracle':
                    self.cursor.execute('''
                        INSERT INTO monitor_main (
                            instance_name, timestamp, monitor_time, connection_status, 
                            connection_count, connection_percent, threads_running, threads_connected, 
                            threads_created, threads_cached, qps, total_queries, uptime, 
                            slow_queries, long_query_time, slow_query_log, innodb_cache_hit_rate, 
                            query_cache_hit_rate, tablespace_usage, replication_status
                        ) VALUES (:1, :2, :3, :4, :5, :6, :7, :8, :9, :10, :11, :12, :13, :14, :15, :16, :17, :18, :19, :20)
                    ''', (
                        instance_name, timestamp, monitor_time, 1 if connection_status else 0,
                        connection_count, connection_percent, threads_running, threads_connected,
                        threads_created, threads_cached, qps, total_queries, uptime,
                        slow_queries, long_query_time, slow_query_log, innodb_cache_hit_rate,
                        query_cache_hit_rate, tablespace_usage, replication_status
                    ))
                
                elif self.db_type == 'mssql':
                    self.cursor.execute('''
                        INSERT INTO monitor_main (
                            instance_name, timestamp, monitor_time, connection_status, 
                            connection_count, connection_percent, threads_running, threads_connected, 
                            threads_created, threads_cached, qps, total_queries, uptime, 
                            slow_queries, long_query_time, slow_query_log, innodb_cache_hit_rate, 
                            query_cache_hit_rate, tablespace_usage, replication_status
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ''', (
                        instance_name, timestamp, monitor_time, connection_status,
                        connection_count, connection_percent, threads_running, threads_connected,
                        threads_created, threads_cached, qps, total_queries, uptime,
                        slow_queries, long_query_time, slow_query_log, innodb_cache_hit_rate,
                        query_cache_hit_rate, tablespace_usage, replication_status
                    ))
                
                elif self.db_type in ['dm', 'kb']:
                    self.cursor.execute('''
                        INSERT INTO monitor_main (
                            instance_name, timestamp, monitor_time, connection_status, 
                            connection_count, connection_percent, threads_running, threads_connected, 
                            threads_created, threads_cached, qps, total_queries, uptime, 
                            slow_queries, long_query_time, slow_query_log, innodb_cache_hit_rate, 
                            query_cache_hit_rate, tablespace_usage, replication_status
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    ''', (
                        instance_name, timestamp, monitor_time, connection_status,
                        connection_count, connection_percent, threads_running, threads_connected,
                        threads_created, threads_cached, qps, total_queries, uptime,
                        slow_queries, long_query_time, slow_query_log, innodb_cache_hit_rate,
                        query_cache_hit_rate, tablespace_usage, replication_status
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
                        # 将 value 和 threshold 转换为字符串，避免数据截断错误
                        alert_value = str(alert.get('value')) if alert.get('value') is not None else None
                        alert_threshold = str(alert.get('threshold')) if alert.get('threshold') is not None else None
                        
                        self.cursor.execute('''
                            INSERT INTO monitor_alerts (
                                instance_name, timestamp, level, message, 
                                metric, value, threshold
                            ) VALUES (:1, :2, :3, :4, :5, :6, :7)
                        ''', (
                            instance_name, timestamp, alert.get('level', ''),
                            alert.get('message', ''), alert.get('metric', ''),
                            alert_value, alert_threshold
                        ))
                    else:
                        # 将 value 和 threshold 转换为字符串，避免数据截断错误
                        alert_value = str(alert.get('value')) if alert.get('value') is not None else None
                        alert_threshold = str(alert.get('threshold')) if alert.get('threshold') is not None else None
                        
                        self.cursor.execute('''
                            INSERT INTO monitor_alerts (
                                instance_name, timestamp, level, message, 
                                metric, value, threshold
                            ) VALUES (%s, %s, %s, %s, %s, %s, %s)
                        ''', (
                            instance_name, timestamp, alert.get('level', ''),
                            alert.get('message', ''), alert.get('metric', ''),
                            alert_value, alert_threshold
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

def read_json_files(monitor_dir, processed_files=None):
    """读取监控目录下的JSON文件，只处理新文件"""
    json_files = []
    processed_files_set = set(processed_files) if processed_files else set()
    
    try:
        # 获取监控目录下的所有日期目录
        if os.path.exists(monitor_dir):
            # 只处理最近的日期目录，提高效率
            date_dirs = []
            for item in os.listdir(monitor_dir):
                item_path = os.path.join(monitor_dir, item)
                if os.path.isdir(item_path) and re.match(r'\d{4}-\d{2}-\d{2}', item):
                    date_dirs.append((item, item_path))
            
            # 按日期倒序排序，优先处理最近的目录
            date_dirs.sort(key=lambda x: x[0], reverse=True)
            
            # 遍历日期目录
            for date_str, date_path in date_dirs:
                # 遍历目录中的文件
                for file in os.listdir(date_path):
                    if file.endswith('.json'):
                        file_path = os.path.join(date_path, file)
                        
                        # 检查文件是否已处理
                        if file_path in processed_files_set:
                            continue
                        
                        try:
                            with open(file_path, 'r', encoding='utf-8') as f:
                                data = json.load(f)
                                json_files.append((file_path, data))
                        except Exception as e:
                            logger.error(f"读取JSON文件失败: {file_path} - {e}")
        
        logger.info(f"成功读取 {len(json_files)} 个新的JSON文件")
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

def get_processed_files_dir(monitor_dir):
    """获取已处理文件记录的目录"""
    return os.path.join(monitor_dir, 'processed')

def get_processed_files_file(monitor_dir, date=None):
    """获取指定日期的已处理文件记录文件路径"""
    processed_dir = get_processed_files_dir(monitor_dir)
    if not date:
        date = datetime.now().strftime('%Y-%m-%d')
    return os.path.join(processed_dir, f'processed_files_{date}.json')

def load_processed_files(monitor_dir, days=7):
    """加载已处理的文件记录，默认加载最近7天的"""
    processed_files = set()
    processed_dir = get_processed_files_dir(monitor_dir)
    
    if os.path.exists(processed_dir):
        # 获取最近days天的日期
        for i in range(days):
            date = (datetime.now() - timedelta(days=i)).strftime('%Y-%m-%d')
            file_path = get_processed_files_file(monitor_dir, date)
            
            if os.path.exists(file_path):
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        day_files = json.load(f)
                        processed_files.update(day_files)
                except Exception as e:
                    logger.error(f"加载已处理文件记录失败: {file_path} - {e}")
    
    logger.debug(f"加载了 {len(processed_files)} 个已处理文件记录")
    return processed_files

def save_processed_files(processed_files, monitor_dir):
    """保存已处理的文件记录，按日期分文件存储"""
    try:
        # 按日期分组文件路径
        files_by_date = {}
        for file_path in processed_files:
            # 从文件路径中提取日期（假设文件路径格式为 monitor\2026-02-05\xxx.json）
            parts = file_path.split(os.sep)
            if len(parts) >= 2:
                date_part = parts[-2]
                if re.match(r'\d{4}-\d{2}-\d{2}', date_part):
                    if date_part not in files_by_date:
                        files_by_date[date_part] = []
                    files_by_date[date_part].append(file_path)
        
        # 确保processed目录存在
        processed_dir = get_processed_files_dir(monitor_dir)
        if not os.path.exists(processed_dir):
            os.makedirs(processed_dir)
        
        # 保存每个日期的文件记录
        for date, files in files_by_date.items():
            file_path = get_processed_files_file(monitor_dir, date)
            # 只保存当天和昨天的记录，更早的记录不需要频繁更新
            date_obj = datetime.strptime(date, '%Y-%m-%d')
            days_diff = (datetime.now() - date_obj).days
            if days_diff <= 1:
                with open(file_path, 'w', encoding='utf-8') as f:
                    json.dump(files, f, ensure_ascii=False, separators=(',', ':'))  # 紧凑格式，减少文件大小
        
        # 清理过期记录（保留最近7天）
        cleanup_expired_records(monitor_dir, days=7)
        
        logger.debug(f"保存了 {len(processed_files)} 个已处理文件记录")
        return True
    except Exception as e:
        logger.error(f"保存已处理文件记录失败: {e}")
        return False

def cleanup_expired_records(monitor_dir, days=7):
    """清理过期的已处理文件记录"""
    try:
        processed_dir = get_processed_files_dir(monitor_dir)
        if not os.path.exists(processed_dir):
            return
        
        # 计算过期日期
        cutoff_date = datetime.now() - timedelta(days=days)
        
        # 遍历processed目录中的所有文件
        for file_name in os.listdir(processed_dir):
            if file_name.startswith('processed_files_') and file_name.endswith('.json'):
                # 提取文件中的日期
                date_str = file_name.replace('processed_files_', '').replace('.json', '')
                try:
                    file_date = datetime.strptime(date_str, '%Y-%m-%d')
                    if file_date < cutoff_date:
                        # 删除过期文件
                        file_path = os.path.join(processed_dir, file_name)
                        os.remove(file_path)
                        logger.debug(f"清理过期的已处理文件记录: {file_path}")
                except ValueError:
                    # 日期格式不正确，跳过
                    pass
    except Exception as e:
        logger.error(f"清理过期记录失败: {e}")

def process_file(file_info):
    """处理单个监控文件，返回处理后的数据"""
    file_path, data = file_info
    try:
        # 解析时间戳
        timestamp_str = data.get('timestamp', '')
        try:
            timestamp = datetime.strptime(timestamp_str, '%Y-%m-%d %H:%M:%S')
        except:
            timestamp = datetime.now()
        
        # 提取关键指标
        instance_name = data.get('instance_name', '')
        monitor_time = data.get('monitor_time', 0)
        stats = data.get('stats', {})
        alerts = data.get('alerts', [])
        
        # 提取连接状态和连接统计
        connection_status = stats.get('connection_status', False)
        connection_count = None
        connection_percent = None
        threads_running = None
        threads_connected = None
        threads_created = None
        threads_cached = None
        if stats.get('connection_stats'):
            connection_count = stats['connection_stats'].get('current_connections')
            connection_percent = stats['connection_stats'].get('connection_percent')
            threads_running = stats['connection_stats'].get('threads_running')
            threads_connected = stats['connection_stats'].get('threads_connected')
            threads_created = stats['connection_stats'].get('threads_created')
            threads_cached = stats['connection_stats'].get('threads_cached')
        
        # 提取QPS和查询统计
        qps = None
        total_queries = None
        uptime = None
        if stats.get('qps'):
            qps = stats['qps'].get('qps')
            total_queries = stats['qps'].get('total_queries')
            uptime = stats['qps'].get('uptime')
        
        # 提取慢查询信息
        slow_queries = None
        long_query_time = None
        slow_query_log = None
        if stats.get('slow_queries'):
            slow_queries = stats['slow_queries'].get('slow_queries')
            long_query_time = stats['slow_queries'].get('long_query_time')
            slow_query_log = stats['slow_queries'].get('slow_query_log')
        
        # 提取缓存命中率
        innodb_cache_hit_rate = None
        query_cache_hit_rate = None
        if stats.get('cache_hit_rate'):
            innodb_cache_hit_rate = stats['cache_hit_rate'].get('innodb_cache_hit_rate')
            query_cache_hit_rate = stats['cache_hit_rate'].get('query_cache_hit_rate')
        
        # 提取表空间使用率
        tablespace_usage = None
        if stats.get('tablespace_usage'):
            if isinstance(stats['tablespace_usage'], list) and len(stats['tablespace_usage']) > 0:
                # 取第一个表空间的使用率作为代表
                tablespace_usage = stats['tablespace_usage'][0].get('usage_percent')
            elif isinstance(stats['tablespace_usage'], dict):
                # MongoDB的存储空间使用情况
                tablespace_usage = stats['tablespace_usage'].get('usage_percent')
        
        # 提取复制状态
        replication_status = None
        if stats.get('replication_status'):
            replication_status = str(stats['replication_status'])
        
        # 处理告警数据
        processed_alerts = []
        for alert in alerts:
            alert_value = str(alert.get('value')) if alert.get('value') is not None else None
            alert_threshold = str(alert.get('threshold')) if alert.get('threshold') is not None else None
            processed_alerts.append((
                instance_name, timestamp, alert.get('level', ''),
                alert.get('message', ''), alert.get('metric', ''),
                alert_value, alert_threshold
            ))
        
        # 返回处理后的数据
        return {
            'file_path': file_path,
            'main_data': (
                instance_name, timestamp, monitor_time, connection_status,
                connection_count, connection_percent, threads_running, threads_connected,
                threads_created, threads_cached, qps, total_queries, uptime,
                slow_queries, long_query_time, slow_query_log, innodb_cache_hit_rate,
                query_cache_hit_rate, tablespace_usage, replication_status
            ),
            'alerts': processed_alerts,
            'success': True
        }
    except Exception as e:
        logger.error(f"处理文件失败: {file_path} - {e}")
        return {
            'file_path': file_path,
            'success': False
        }

def batch_write_to_db(processed_data_list, db_type, db_config):
    """批量写入数据到数据库"""
    if not processed_data_list:
        return 0, 0
    
    success_count = 0
    failed_count = 0
    
    try:
        # 创建数据库写入器
        writer = DatabaseWriter(db_type, db_config)
        
        # 连接数据库
        if not writer.connect():
            logger.error("无法连接到数据库，批量写入失败")
            return 0, len(processed_data_list)
        
        # 开始事务
        if db_type != 'mongodb':
            writer.conn.autocommit = False
        
        # 处理主数据和告警数据
        for data in processed_data_list:
            if not data['success']:
                failed_count += 1
                continue
            
            try:
                # 写入主表
                if db_type == 'mongodb':
                    # MongoDB写入方式
                    main_data = {
                        'instance_name': data['main_data'][0],
                        'timestamp': data['main_data'][1],
                        'monitor_time': data['main_data'][2],
                        'connection_status': data['main_data'][3],
                        'connection_count': data['main_data'][4],
                        'connection_percent': data['main_data'][5],
                        'threads_running': data['main_data'][6],
                        'threads_connected': data['main_data'][7],
                        'threads_created': data['main_data'][8],
                        'threads_cached': data['main_data'][9],
                        'qps': data['main_data'][10],
                        'total_queries': data['main_data'][11],
                        'uptime': data['main_data'][12],
                        'slow_queries': data['main_data'][13],
                        'long_query_time': data['main_data'][14],
                        'slow_query_log': data['main_data'][15],
                        'innodb_cache_hit_rate': data['main_data'][16],
                        'query_cache_hit_rate': data['main_data'][17],
                        'tablespace_usage': data['main_data'][18],
                        'replication_status': data['main_data'][19],
                        'created_at': datetime.now()
                    }
                    writer.db.monitor_main.insert_one(main_data)
                else:
                    # 关系型数据库写入方式
                    if db_type == 'mysql':
                        writer.cursor.execute('''
                            INSERT INTO monitor_main (
                                instance_name, timestamp, monitor_time, connection_status, 
                                connection_count, connection_percent, threads_running, threads_connected, 
                                threads_created, threads_cached, qps, total_queries, uptime, 
                                slow_queries, long_query_time, slow_query_log, innodb_cache_hit_rate, 
                                query_cache_hit_rate, tablespace_usage, replication_status
                            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                        ''', data['main_data'])
                    elif db_type == 'postgresql':
                        writer.cursor.execute('''
                            INSERT INTO monitor_main (
                                instance_name, timestamp, monitor_time, connection_status, 
                                connection_count, connection_percent, threads_running, threads_connected, 
                                threads_created, threads_cached, qps, total_queries, uptime, 
                                slow_queries, long_query_time, slow_query_log, innodb_cache_hit_rate, 
                                query_cache_hit_rate, tablespace_usage, replication_status
                            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                        ''', data['main_data'])
                    elif db_type == 'oracle':
                        # Oracle需要特殊处理布尔值
                        oracle_data = list(data['main_data'])
                        oracle_data[3] = 1 if oracle_data[3] else 0
                        writer.cursor.execute('''
                            INSERT INTO monitor_main (
                                instance_name, timestamp, monitor_time, connection_status, 
                                connection_count, connection_percent, threads_running, threads_connected, 
                                threads_created, threads_cached, qps, total_queries, uptime, 
                                slow_queries, long_query_time, slow_query_log, innodb_cache_hit_rate, 
                                query_cache_hit_rate, tablespace_usage, replication_status
                            ) VALUES (:1, :2, :3, :4, :5, :6, :7, :8, :9, :10, :11, :12, :13, :14, :15, :16, :17, :18, :19, :20)
                        ''', oracle_data)
                    elif db_type == 'mssql':
                        writer.cursor.execute('''
                            INSERT INTO monitor_main (
                                instance_name, timestamp, monitor_time, connection_status, 
                                connection_count, connection_percent, threads_running, threads_connected, 
                                threads_created, threads_cached, qps, total_queries, uptime, 
                                slow_queries, long_query_time, slow_query_log, innodb_cache_hit_rate, 
                                query_cache_hit_rate, tablespace_usage, replication_status
                            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        ''', data['main_data'])
                    elif db_type in ['dm', 'kb']:
                        writer.cursor.execute('''
                            INSERT INTO monitor_main (
                                instance_name, timestamp, monitor_time, connection_status, 
                                connection_count, connection_percent, threads_running, threads_connected, 
                                threads_created, threads_cached, qps, total_queries, uptime, 
                                slow_queries, long_query_time, slow_query_log, innodb_cache_hit_rate, 
                                query_cache_hit_rate, tablespace_usage, replication_status
                            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                        ''', data['main_data'])
                
                # 写入告警数据
                for alert in data['alerts']:
                    if db_type == 'mongodb':
                        alert_data = {
                            'instance_name': alert[0],
                            'timestamp': alert[1],
                            'level': alert[2],
                            'message': alert[3],
                            'metric': alert[4],
                            'value': alert[5],
                            'threshold': alert[6],
                            'created_at': datetime.now()
                        }
                        writer.db.monitor_alerts.insert_one(alert_data)
                    else:
                        if db_type == 'oracle':
                            writer.cursor.execute('''
                                INSERT INTO monitor_alerts (
                                    instance_name, timestamp, level, message, 
                                    metric, value, threshold
                                ) VALUES (:1, :2, :3, :4, :5, :6, :7)
                            ''', alert)
                        else:
                            writer.cursor.execute('''
                                INSERT INTO monitor_alerts (
                                    instance_name, timestamp, level, message, 
                                    metric, value, threshold
                                ) VALUES (%s, %s, %s, %s, %s, %s, %s)
                            ''', alert)
                
                success_count += 1
            except Exception as e:
                logger.error(f"写入数据失败: {data['file_path']} - {e}")
                failed_count += 1
        
        # 提交事务
        if db_type != 'mongodb':
            writer.conn.commit()
        
        # 断开连接
        writer.disconnect()
        
    except Exception as e:
        logger.error(f"批量写入过程中发生错误: {e}")
        # 回滚事务
        if 'writer' in locals() and writer.conn and db_type != 'mongodb':
            try:
                writer.conn.rollback()
            except:
                pass
        # 断开连接
        if 'writer' in locals():
            try:
                writer.disconnect()
            except:
                pass
        failed_count = len(processed_data_list)
    
    return success_count, failed_count

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
    parser.add_argument('--max-workers', type=int, default=10, 
                        help='最大并行处理线程数')
    
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
    logger.info(f"最大并行线程数: {args.max_workers}")
    
    # 测试数据库连接并创建表结构
    test_writer = DatabaseWriter(db_type, db_config)
    if not test_writer.connect():
        logger.error("无法连接到数据库，退出脚本")
        return
    
    if not test_writer.create_tables():
        logger.error("无法创建表结构，退出脚本")
        test_writer.disconnect()
        return
    
    test_writer.disconnect()
    
    if args.continuous:
        logger.info(f"启动持续监控模式，监控目录: {args.monitor_dir}，间隔: {args.interval}秒")
        
        # 记录已处理的文件
        processed_files = set()
        
        try:
            while True:
                # 读取JSON文件，只处理新文件
                json_files = read_json_files(args.monitor_dir, processed_files)
                
                # 直接使用返回的新文件
                new_files = json_files
                
                if new_files:
                    logger.info(f"发现 {len(new_files)} 个新的监控文件")
                    
                    # 写入数据
                    success_count = 0
                    failed_count = 0
                    processed_data_list = []
                    
                    # 使用线程池并行处理文件
                    with concurrent.futures.ThreadPoolExecutor(max_workers=args.max_workers) as executor:
                        # 提交任务
                        futures = {
                            executor.submit(process_file, (file_path, data)): file_path
                            for file_path, data in new_files
                        }
                        
                        # 收集处理结果
                        for future in concurrent.futures.as_completed(futures):
                            file_path = futures[future]
                            try:
                                result = future.result()
                                processed_data_list.append(result)
                            except Exception as e:
                                logger.error(f"处理文件时发生异常: {file_path} - {e}")
                                processed_data_list.append({
                                    'file_path': file_path,
                                    'success': False
                                })
                    
                    # 批量写入数据库
                    batch_success, batch_failed = batch_write_to_db(processed_data_list, db_type, db_config)
                    success_count = batch_success
                    failed_count = batch_failed
                    
                    # 更新已处理文件集合
                    for data in processed_data_list:
                        if data['success']:
                            processed_files.add(data['file_path'])
                    
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
        # 加载已处理的文件记录
        processed_files = load_processed_files(args.monitor_dir)
        
        # 读取JSON文件，只处理新文件
        json_files = read_json_files(args.monitor_dir, processed_files)
        
        if not json_files:
            logger.warning("没有找到监控JSON文件，退出脚本")
            return
        
        # 直接使用返回的新文件
        new_files = json_files
        
        if not new_files:
            logger.info("没有发现新的监控文件，退出脚本")
            return
        
        logger.info(f"发现 {len(new_files)} 个新的监控文件")
        
        # 写入数据
        success_count = 0
        failed_count = 0
        processed_files_set = set(processed_files)
        processed_data_list = []
        
        # 使用线程池并行处理文件
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.max_workers) as executor:
            # 提交任务
            futures = {
                executor.submit(process_file, (file_path, data)): file_path
                for file_path, data in new_files
            }
            
            # 收集处理结果
            for future in concurrent.futures.as_completed(futures):
                file_path = futures[future]
                try:
                    result = future.result()
                    processed_data_list.append(result)
                except Exception as e:
                    logger.error(f"处理文件时发生异常: {file_path} - {e}")
                    processed_data_list.append({
                        'file_path': file_path,
                        'success': False
                    })
        
        # 批量写入数据库
        batch_success, batch_failed = batch_write_to_db(processed_data_list, db_type, db_config)
        success_count = batch_success
        failed_count = batch_failed
        
        # 更新已处理文件集合
        for data in processed_data_list:
            if data['success']:
                processed_files_set.add(data['file_path'])
        
        # 保存已处理的文件记录
        if processed_files_set:
            save_processed_files(list(processed_files_set), args.monitor_dir)
        
        # 输出结果
        logger.info(f"监控数据入库完成")
        logger.info(f"总文件数: {len(new_files)}")
        logger.info(f"成功入库: {success_count}")
        logger.info(f"失败数量: {failed_count}")

if __name__ == "__main__":
    main()