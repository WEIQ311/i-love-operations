#!/usr/bin/env python3
import requests
import re
import time
import json
import os
from datetime import datetime
import subprocess

class NginxMonitor:
    def __init__(self, stub_status_url='http://localhost/nginx_status', access_log_path='/var/log/nginx/access.log'):
        self.stub_status_url = stub_status_url
        self.access_log_path = access_log_path
        self.data_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'data', 'nginx')
        self.log_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'logs')
        
        # 创建数据目录
        os.makedirs(self.data_dir, exist_ok=True)
        os.makedirs(self.log_dir, exist_ok=True)
    
    def get_stub_status(self):
        """从Nginx stub_status模块获取状态信息"""
        try:
            response = requests.get(self.stub_status_url, timeout=5)
            if response.status_code == 200:
                status_text = response.text
                # 解析stub_status返回的文本
                active_connections = int(re.search(r'Active connections:\s+(\d+)', status_text).group(1))
                accepted, handled, requests = map(int, re.search(r'\s+(\d+)\s+(\d+)\s+(\d+)', status_text).groups())
                reading, writing, waiting = map(int, re.search(r'Reading:\s+(\d+)\s+Writing:\s+(\d+)\s+Waiting:\s+(\d+)', status_text).groups())
                
                return {
                    'active_connections': active_connections,
                    'accepted_connections': accepted,
                    'handled_connections': handled,
                    'total_requests': requests,
                    'reading_connections': reading,
                    'writing_connections': writing,
                    'waiting_connections': waiting
                }
        except Exception as e:
            print(f"获取Nginx stub_status失败: {e}")
        return {}
    
    def parse_access_log(self, lines=1000):
        """解析Nginx访问日志"""
        try:
            # 使用tail命令获取最新的日志行
            result = subprocess.run(['tail', '-n', str(lines), self.access_log_path], 
                                   capture_output=True, text=True)
            log_lines = result.stdout.strip().split('\n')
            
            # 解析日志
            status_codes = {}
            request_times = []
            total_requests = 0
            error_requests = 0
            
            for line in log_lines:
                if line:
                    total_requests += 1
                    # 解析状态码和请求时间（假设日志格式包含这两个字段）
                    # 示例日志格式: 127.0.0.1 - - [05/Feb/2026:12:44:32 +0800] "GET / HTTP/1.1" 200 612 "-" "Mozilla/5.0"
                    match = re.search(r'"\s+(\d+)\s+', line)
                    if match:
                        status_code = match.group(1)
                        status_codes[status_code] = status_codes.get(status_code, 0) + 1
                        if int(status_code) >= 400:
                            error_requests += 1
                    
                    # 解析请求时间（如果日志格式包含）
                    match_time = re.search(r'\s+(\d+\.\d+)\s+', line)
                    if match_time:
                        try:
                            request_time = float(match_time.group(1))
                            request_times.append(request_time)
                        except Exception:
                            pass
            
            # 计算请求时间统计
            if request_times:
                avg_request_time = sum(request_times) / len(request_times)
                max_request_time = max(request_times)
                min_request_time = min(request_times)
            else:
                avg_request_time = 0
                max_request_time = 0
                min_request_time = 0
            
            return {
                'total_requests': total_requests,
                'error_requests': error_requests,
                'error_rate': error_requests / total_requests if total_requests > 0 else 0,
                'status_codes': status_codes,
                'avg_request_time': avg_request_time,
                'max_request_time': max_request_time,
                'min_request_time': min_request_time
            }
        except Exception as e:
            print(f"解析Nginx访问日志失败: {e}")
        return {}
    
    def get_nginx_process_info(self):
        """获取Nginx进程信息"""
        try:
            # 使用ps命令获取Nginx进程信息
            result = subprocess.run(['ps', '-ef', '|', 'grep', 'nginx'], 
                                   shell=True, capture_output=True, text=True)
            processes = []
            for line in result.stdout.strip().split('\n'):
                if 'nginx' in line and not 'grep' in line:
                    processes.append(line.strip())
            
            # 获取Nginx版本
            version_result = subprocess.run(['nginx', '-v'], 
                                         capture_output=True, text=True, stderr=subprocess.STDOUT)
            version = version_result.stdout.strip()
            
            return {
                'processes': processes,
                'version': version
            }
        except Exception as e:
            print(f"获取Nginx进程信息失败: {e}")
        return {}
    
    def collect_metrics(self):
        """收集所有Nginx指标"""
        metrics = {
            'timestamp': datetime.now().isoformat(),
            'stub_status': self.get_stub_status(),
            'access_log_stats': self.parse_access_log(),
            'process_info': self.get_nginx_process_info()
        }
        return metrics
    
    def save_metrics(self, metrics):
        """保存指标到文件"""
        date_str = datetime.now().strftime('%Y-%m-%d')
        file_path = os.path.join(self.data_dir, f'nginx_metrics_{date_str}.json')
        
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
        print(f"启动Nginx性能监控，间隔{interval}秒")
        try:
            while True:
                metrics = self.collect_metrics()
                self.save_metrics(metrics)
                print(f"[{datetime.now()}] Nginx性能监控数据已收集")
                time.sleep(interval)
        except KeyboardInterrupt:
            print("Nginx性能监控已停止")

if __name__ == "__main__":
    # 默认配置，可根据实际情况修改
    monitor = NginxMonitor(
        stub_status_url='http://localhost/nginx_status',
        access_log_path='/var/log/nginx/access.log'
    )
    monitor.run()
