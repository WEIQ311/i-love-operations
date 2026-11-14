#!/usr/bin/env python3
import psutil
import time
import json
import os
import socket
import requests
import re
from datetime import datetime

class NetworkMonitor:
    def __init__(self):
        self.data_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'monitor', 'data', 'network')
        self.log_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'monitor', 'logs')
        
        # 创建数据目录
        os.makedirs(self.data_dir, exist_ok=True)
        os.makedirs(self.log_dir, exist_ok=True)
        
        # 存储上一次的网络I/O计数器
        self.previous_io_counters = psutil.net_io_counters(pernic=True)
        self.previous_time = time.time()
    
    def get_network_io(self):
        """获取网络I/O情况"""
        current_io_counters = psutil.net_io_counters(pernic=True)
        current_time = time.time()
        time_diff = current_time - self.previous_time
        
        if time_diff == 0:
            time_diff = 1
        
        network_io = {}
        for interface, counters in current_io_counters.items():
            if interface in self.previous_io_counters:
                prev_counters = self.previous_io_counters[interface]
                network_io[interface] = {
                    'bytes_sent': counters.bytes_sent,
                    'bytes_recv': counters.bytes_recv,
                    'packets_sent': counters.packets_sent,
                    'packets_recv': counters.packets_recv,
                    'errin': counters.errin,
                    'errout': counters.errout,
                    'dropin': counters.dropin,
                    'dropout': counters.dropout,
                    'bytes_sent_per_sec': (counters.bytes_sent - prev_counters.bytes_sent) / time_diff,
                    'bytes_recv_per_sec': (counters.bytes_recv - prev_counters.bytes_recv) / time_diff,
                    'packets_sent_per_sec': (counters.packets_sent - prev_counters.packets_sent) / time_diff,
                    'packets_recv_per_sec': (counters.packets_recv - prev_counters.packets_recv) / time_diff
                }
        
        # 更新上一次的计数器和时间
        self.previous_io_counters = current_io_counters
        self.previous_time = current_time
        
        return network_io
    
    def get_network_connections(self):
        """获取网络连接情况"""
        connections = []
        try:
            for conn in psutil.net_connections(kind='inet'):
                if conn.status == 'ESTABLISHED':
                    connections.append({
                        'local_address': f"{conn.laddr.ip}:{conn.laddr.port}",
                        'remote_address': f"{conn.raddr.ip}:{conn.raddr.port}" if conn.raddr else 'N/A',
                        'status': conn.status,
                        'pid': conn.pid
                    })
        except Exception as e:
            print(f"获取网络连接失败: {e}")
        
        return {
            'total_connections': len(connections),
            'established_connections': len([c for c in connections if c['status'] == 'ESTABLISHED']),
            'connections': connections[:50]  # 只返回前50个连接，避免数据过多
        }
    
    def ping(self, host, count=5):
        """测试网络延迟"""
        try:
            import subprocess
            import platform
            
            # 根据操作系统选择ping命令
            param = '-n' if platform.system() == 'Windows' else '-c'
            result = subprocess.run(['ping', param, str(count), host], 
                                   capture_output=True, text=True)
            
            # 解析ping结果
            if result.returncode == 0:
                output = result.stdout
                # 提取延迟信息
                if platform.system() == 'Windows':
                    # Windows格式: Average = 3ms
                    avg_match = re.search(r'Average = (\d+)ms', output)
                    if avg_match:
                        avg_delay = int(avg_match.group(1))
                    else:
                        avg_delay = 0
                else:
                    # Linux格式: rtt min/avg/max/mdev = 0.056/0.068/0.082/0.010 ms
                    rtt_match = re.search(r'rtt min/avg/max/mdev = ([\d.]+)/([\d.]+)/([\d.]+)/([\d.]+) ms', output)
                    if rtt_match:
                        avg_delay = float(rtt_match.group(2))
                    else:
                        avg_delay = 0
                
                return {
                    'host': host,
                    'success': True,
                    'avg_delay': avg_delay,
                    'output': output
                }
            else:
                return {
                    'host': host,
                    'success': False,
                    'error': result.stderr
                }
        except Exception as e:
            return {
                'host': host,
                'success': False,
                'error': str(e)
            }
    
    def test_website_response(self, url, timeout=5):
        """测试网站响应时间"""
        try:
            start_time = time.time()
            response = requests.get(url, timeout=timeout)
            end_time = time.time()
            response_time = (end_time - start_time) * 1000  # 转换为毫秒
            
            return {
                'url': url,
                'status_code': response.status_code,
                'response_time': response_time,
                'success': True
            }
        except Exception as e:
            return {
                'url': url,
                'success': False,
                'error': str(e)
            }
    
    def collect_metrics(self):
        """收集所有网络指标"""
        metrics = {
            'timestamp': datetime.now().isoformat(),
            'network_io': self.get_network_io(),
            'network_connections': self.get_network_connections(),
            'ping_google': self.ping('www.google.com'),
            'ping_baidu': self.ping('www.baidu.com'),
            'website_response': self.test_website_response('http://localhost')
        }
        return metrics
    
    def save_metrics(self, metrics):
        """保存指标到文件"""
        date_str = datetime.now().strftime('%Y-%m-%d')
        file_path = os.path.join(self.data_dir, f'network_metrics_{date_str}.json')
        
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
        print(f"启动网络性能监控，间隔{interval}秒")
        try:
            while True:
                metrics = self.collect_metrics()
                self.save_metrics(metrics)
                print(f"[{datetime.now()}] 网络性能监控数据已收集")
                time.sleep(interval)
        except KeyboardInterrupt:
            print("网络性能监控已停止")

if __name__ == "__main__":
    monitor = NetworkMonitor()
    monitor.run()
