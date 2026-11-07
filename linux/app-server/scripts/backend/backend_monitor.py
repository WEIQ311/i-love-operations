#!/usr/bin/env python3
import requests
import time
import json
import os
import subprocess
from datetime import datetime
import threading

class BackendMonitor:
    def __init__(self, endpoints=None):
        # 默认监控端点，可根据实际情况修改
        if endpoints is None:
            self.endpoints = [
                {'url': 'http://localhost/api/health', 'method': 'GET', 'name': '健康检查'},
                {'url': 'http://localhost/api/status', 'method': 'GET', 'name': '状态检查'}
            ]
        else:
            self.endpoints = endpoints
        
        # 确保使用正确的路径
        base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
        self.data_dir = os.path.join(base_dir, 'monitor', 'data', 'backend')
        self.log_dir = os.path.join(base_dir, 'monitor', 'logs')
        
        print(f"数据目录: {self.data_dir}")
        print(f"日志目录: {self.log_dir}")
        
        # 创建数据目录
        os.makedirs(self.data_dir, exist_ok=True)
        os.makedirs(self.log_dir, exist_ok=True)
        print(f"目录创建成功: {os.path.exists(self.data_dir)}")
    
    def test_endpoint(self, endpoint):
        """测试单个API端点"""
        url = endpoint['url']
        method = endpoint.get('method', 'GET')
        name = endpoint.get('name', url)
        data = endpoint.get('data', {})
        headers = endpoint.get('headers', {})
        
        try:
            start_time = time.time()
            if method.upper() == 'GET':
                response = requests.get(url, headers=headers, timeout=10)
            elif method.upper() == 'POST':
                response = requests.post(url, json=data, headers=headers, timeout=10)
            elif method.upper() == 'PUT':
                response = requests.put(url, json=data, headers=headers, timeout=10)
            elif method.upper() == 'DELETE':
                response = requests.delete(url, headers=headers, timeout=10)
            else:
                return {
                    'name': name,
                    'url': url,
                    'method': method,
                    'success': False,
                    'error': f'不支持的HTTP方法: {method}'
                }
            
            end_time = time.time()
            response_time = (end_time - start_time) * 1000  # 转换为毫秒
            
            return {
                'name': name,
                'url': url,
                'method': method,
                'status_code': response.status_code,
                'response_time': response_time,
                'success': 200 <= response.status_code < 300,
                'content_length': len(response.content)
            }
        except Exception as e:
            return {
                'name': name,
                'url': url,
                'method': method,
                'success': False,
                'error': str(e)
            }
    
    def test_all_endpoints(self):
        """测试所有API端点"""
        results = []
        threads = []
        thread_results = {}
        
        # 使用线程池并行测试多个端点
        def test_with_thread(endpoint, index):
            thread_results[index] = self.test_endpoint(endpoint)
        
        for i, endpoint in enumerate(self.endpoints):
            thread = threading.Thread(target=test_with_thread, args=(endpoint, i))
            threads.append(thread)
            thread.start()
        
        # 等待所有线程完成
        for thread in threads:
            thread.join()
        
        # 按原始顺序收集结果
        for i in range(len(self.endpoints)):
            if i in thread_results:
                results.append(thread_results[i])
        
        # 计算汇总统计
        total_requests = len(results)
        successful_requests = len([r for r in results if r.get('success', False)])
        error_rate = 1 - (successful_requests / total_requests) if total_requests > 0 else 0
        
        response_times = [r['response_time'] for r in results if 'response_time' in r and r['response_time'] is not None]
        if response_times:
            avg_response_time = sum(response_times) / len(response_times)
            max_response_time = max(response_times)
            min_response_time = min(response_times)
        else:
            avg_response_time = 0
            max_response_time = 0
            min_response_time = 0
        
        return {
            'endpoints': results,
            'summary': {
                'total_requests': total_requests,
                'successful_requests': successful_requests,
                'error_rate': error_rate,
                'avg_response_time': avg_response_time,
                'max_response_time': max_response_time,
                'min_response_time': min_response_time
            }
        }
    
    def get_backend_process_info(self):
        """获取后端应用进程信息"""
        try:
            # 假设后端应用是Python应用，可根据实际情况修改
            result = subprocess.run(['ps', '-ef', '|', 'grep', 'python'], 
                                   shell=True, capture_output=True, text=True)
            processes = []
            for line in result.stdout.strip().split('\n'):
                if 'python' in line and not 'grep' in line:
                    processes.append(line.strip())
            
            return {
                'processes': processes
            }
        except Exception as e:
            print(f"获取后端应用进程信息失败: {e}")
        return {}
    
    def collect_metrics(self):
        """收集所有后端应用指标"""
        metrics = {
            'timestamp': datetime.now().isoformat(),
            'endpoint_tests': self.test_all_endpoints(),
            'process_info': self.get_backend_process_info()
        }
        return metrics
    
    def save_metrics(self, metrics):
        """保存指标到文件"""
        date_str = datetime.now().strftime('%Y-%m-%d')
        file_path = os.path.join(self.data_dir, f'backend_metrics_{date_str}.json')
        
        print(f"保存路径: {file_path}")
        print(f"目录是否存在: {os.path.exists(self.data_dir)}")
        print(f"文件是否存在: {os.path.exists(file_path)}")
        
        try:
            # 确保目录存在
            if not os.path.exists(self.data_dir):
                print(f"创建目录: {self.data_dir}")
                os.makedirs(self.data_dir, exist_ok=True)
                print(f"目录创建结果: {os.path.exists(self.data_dir)}")
            
            # 读取现有数据
            existing_data = []
            if os.path.exists(file_path):
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        existing_data = json.load(f)
                    print(f"读取现有数据成功，共 {len(existing_data)} 条")
                except Exception as e:
                    print(f"读取现有数据失败: {e}")
            
            # 添加新数据
            existing_data.append(metrics)
            print(f"添加新数据后，共 {len(existing_data)} 条")
            
            # 保存数据
            print(f"开始保存数据到: {file_path}")
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(existing_data, f, ensure_ascii=False, indent=2)
            print("保存数据成功")
        except Exception as e:
            print(f"保存数据失败: {e}")
            import traceback
            traceback.print_exc()
    
    def run(self, interval=60):
        """运行监控"""
        print(f"启动后端应用性能监控，间隔{interval}秒")
        try:
            while True:
                metrics = self.collect_metrics()
                self.save_metrics(metrics)
                print(f"[{datetime.now()}] 后端应用性能监控数据已收集")
                time.sleep(interval)
        except KeyboardInterrupt:
            print("后端应用性能监控已停止")

if __name__ == "__main__":
    # 默认配置，可根据实际情况修改
    monitor = BackendMonitor()
    monitor.run()
