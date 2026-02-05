#!/usr/bin/env python3
import psutil
import time
import json
import os
from datetime import datetime

class SystemMonitor:
    def __init__(self):
        self.data_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'data', 'system')
        self.log_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'logs')
        
        # 创建数据目录
        os.makedirs(self.data_dir, exist_ok=True)
        os.makedirs(self.log_dir, exist_ok=True)
    
    def get_cpu_usage(self):
        """获取CPU使用率"""
        return {
            'total': psutil.cpu_percent(interval=1, percpu=False),
            'per_core': psutil.cpu_percent(interval=1, percpu=True)
        }
    
    def get_memory_usage(self):
        """获取内存使用情况"""
        memory = psutil.virtual_memory()
        return {
            'total': memory.total,
            'available': memory.available,
            'used': memory.used,
            'percent': memory.percent
        }
    
    def get_disk_usage(self):
        """获取磁盘使用情况"""
        disk_info = []
        for partition in psutil.disk_partitions():
            if partition.fstype:
                try:
                    usage = psutil.disk_usage(partition.mountpoint)
                    disk_info.append({
                        'device': partition.device,
                        'mountpoint': partition.mountpoint,
                        'fstype': partition.fstype,
                        'total': usage.total,
                        'used': usage.used,
                        'free': usage.free,
                        'percent': usage.percent
                    })
                except Exception as e:
                    pass
        return disk_info
    
    def get_disk_io(self):
        """获取磁盘I/O情况"""
        disk_io = psutil.disk_io_counters(perdisk=True)
        result = {}
        for disk, io in disk_io.items():
            result[disk] = {
                'read_count': io.read_count,
                'write_count': io.write_count,
                'read_bytes': io.read_bytes,
                'write_bytes': io.write_bytes,
                'read_time': io.read_time,
                'write_time': io.write_time
            }
        return result
    
    def get_system_load(self):
        """获取系统负载"""
        if hasattr(psutil, 'getloadavg'):
            load_avg = psutil.getloadavg()
            return {
                '1min': load_avg[0],
                '5min': load_avg[1],
                '15min': load_avg[2]
            }
        else:
            # Windows系统不支持getloadavg
            return {}
    
    def get_process_count(self):
        """获取进程数量"""
        return len(psutil.pids())
    
    def collect_metrics(self):
        """收集所有系统指标"""
        metrics = {
            'timestamp': datetime.now().isoformat(),
            'cpu': self.get_cpu_usage(),
            'memory': self.get_memory_usage(),
            'disk_usage': self.get_disk_usage(),
            'disk_io': self.get_disk_io(),
            'system_load': self.get_system_load(),
            'process_count': self.get_process_count()
        }
        return metrics
    
    def save_metrics(self, metrics):
        """保存指标到文件"""
        date_str = datetime.now().strftime('%Y-%m-%d')
        file_path = os.path.join(self.data_dir, f'system_metrics_{date_str}.json')
        
        # 读取现有数据
        existing_data = []
        if os.path.exists(file_path):
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    existing_data = json.load(f)
            except Exception as e:
                pass
        
        # 添加新数据
        existing_data.append(metrics)
        
        # 保存数据
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(existing_data, f, ensure_ascii=False, indent=2)
    
    def run(self, interval=60):
        """运行监控"""
        print(f"启动系统资源监控，间隔{interval}秒")
        try:
            while True:
                metrics = self.collect_metrics()
                self.save_metrics(metrics)
                print(f"[{datetime.now()}] 系统资源监控数据已收集")
                time.sleep(interval)
        except KeyboardInterrupt:
            print("系统资源监控已停止")

if __name__ == "__main__":
    monitor = SystemMonitor()
    monitor.run()
