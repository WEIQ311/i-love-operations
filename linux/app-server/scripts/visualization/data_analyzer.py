#!/usr/bin/env python3
import json
import os
import pandas as pd
import matplotlib.pyplot as plt
from datetime import datetime
import re

class DataAnalyzer:
    def __init__(self):
        self.data_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'data')
        self.output_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'data', 'visualization')
        
        # 创建输出目录
        os.makedirs(self.output_dir, exist_ok=True)
    
    def load_data(self, data_type):
        """加载指定类型的监控数据"""
        data_path = os.path.join(self.data_dir, data_type)
        data = []
        
        if os.path.exists(data_path):
            for file_name in os.listdir(data_path):
                if file_name.endswith('.json'):
                    file_path = os.path.join(data_path, file_name)
                    try:
                        with open(file_path, 'r', encoding='utf-8') as f:
                            file_data = json.load(f)
                            data.extend(file_data)
                    except Exception as e:
                        print(f"加载文件失败: {file_path} - {e}")
        
        return data
    
    def analyze_system_data(self):
        """分析系统资源数据"""
        data = self.load_data('system')
        if not data:
            print("没有系统资源监控数据")
            return
        
        # 转换为DataFrame
        df = pd.DataFrame(data)
        df['timestamp'] = pd.to_datetime(df['timestamp'])
        df.set_index('timestamp', inplace=True)
        
        # 提取CPU使用率
        cpu_data = []
        for idx, row in df.iterrows():
            cpu_data.append({
                'timestamp': idx,
                'cpu_total': row['cpu']['total']
            })
        cpu_df = pd.DataFrame(cpu_data)
        cpu_df.set_index('timestamp', inplace=True)
        
        # 提取内存使用率
        memory_data = []
        for idx, row in df.iterrows():
            memory_data.append({
                'timestamp': idx,
                'memory_percent': row['memory']['percent']
            })
        memory_df = pd.DataFrame(memory_data)
        memory_df.set_index('timestamp', inplace=True)
        
        # 绘图
        plt.figure(figsize=(12, 8))
        
        # CPU使用率图
        plt.subplot(2, 1, 1)
        plt.plot(cpu_df.index, cpu_df['cpu_total'], label='CPU使用率')
        plt.title('CPU使用率趋势')
        plt.ylabel('使用率 (%)')
        plt.grid(True)
        plt.legend()
        
        # 内存使用率图
        plt.subplot(2, 1, 2)
        plt.plot(memory_df.index, memory_df['memory_percent'], label='内存使用率')
        plt.title('内存使用率趋势')
        plt.ylabel('使用率 (%)')
        plt.grid(True)
        plt.legend()
        
        plt.tight_layout()
        plt.savefig(os.path.join(self.output_dir, 'system_resources.png'))
        plt.close()
        
        print("系统资源分析完成，图表已保存到 system_resources.png")
    
    def analyze_nginx_data(self):
        """分析Nginx性能数据"""
        data = self.load_data('nginx')
        if not data:
            print("没有Nginx性能监控数据")
            return
        
        # 转换为DataFrame
        df = pd.DataFrame(data)
        df['timestamp'] = pd.to_datetime(df['timestamp'])
        df.set_index('timestamp', inplace=True)
        
        # 提取连接数和请求数
        nginx_data = []
        for idx, row in df.iterrows():
            stub_status = row.get('stub_status', {})
            access_log = row.get('access_log_stats', {})
            nginx_data.append({
                'timestamp': idx,
                'active_connections': stub_status.get('active_connections', 0),
                'total_requests': stub_status.get('total_requests', 0),
                'error_rate': access_log.get('error_rate', 0),
                'avg_request_time': access_log.get('avg_request_time', 0)
            })
        nginx_df = pd.DataFrame(nginx_data)
        nginx_df.set_index('timestamp', inplace=True)
        
        # 绘图
        plt.figure(figsize=(12, 10))
        
        # 连接数图
        plt.subplot(2, 2, 1)
        plt.plot(nginx_df.index, nginx_df['active_connections'], label='活跃连接数')
        plt.title('Nginx活跃连接数趋势')
        plt.ylabel('连接数')
        plt.grid(True)
        plt.legend()
        
        # 请求数图
        plt.subplot(2, 2, 2)
        plt.plot(nginx_df.index, nginx_df['total_requests'], label='总请求数')
        plt.title('Nginx总请求数趋势')
        plt.ylabel('请求数')
        plt.grid(True)
        plt.legend()
        
        # 错误率图
        plt.subplot(2, 2, 3)
        plt.plot(nginx_df.index, nginx_df['error_rate'], label='错误率')
        plt.title('Nginx错误率趋势')
        plt.ylabel('错误率 (%)')
        plt.grid(True)
        plt.legend()
        
        # 请求时间图
        plt.subplot(2, 2, 4)
        plt.plot(nginx_df.index, nginx_df['avg_request_time'], label='平均请求时间')
        plt.title('Nginx平均请求时间趋势')
        plt.ylabel('时间 (ms)')
        plt.grid(True)
        plt.legend()
        
        plt.tight_layout()
        plt.savefig(os.path.join(self.output_dir, 'nginx_performance.png'))
        plt.close()
        
        print("Nginx性能分析完成，图表已保存到 nginx_performance.png")
    
    def analyze_network_data(self):
        """分析网络性能数据"""
        data = self.load_data('network')
        if not data:
            print("没有网络性能监控数据")
            return
        
        # 转换为DataFrame
        df = pd.DataFrame(data)
        df['timestamp'] = pd.to_datetime(df['timestamp'])
        df.set_index('timestamp', inplace=True)
        
        # 提取网络I/O和延迟
        network_data = []
        for idx, row in df.iterrows():
            # 获取主要网络接口的流量
            network_io = row.get('network_io', {})
            # 假设eth0是主要网络接口，可根据实际情况修改
            eth0_io = network_io.get('eth0', {})
            
            # 获取网络延迟
            ping_google = row.get('ping_google', {})
            ping_baidu = row.get('ping_baidu', {})
            
            network_data.append({
                'timestamp': idx,
                'bytes_sent_per_sec': eth0_io.get('bytes_sent_per_sec', 0),
                'bytes_recv_per_sec': eth0_io.get('bytes_recv_per_sec', 0),
                'ping_google_delay': ping_google.get('avg_delay', 0),
                'ping_baidu_delay': ping_baidu.get('avg_delay', 0)
            })
        network_df = pd.DataFrame(network_data)
        network_df.set_index('timestamp', inplace=True)
        
        # 绘图
        plt.figure(figsize=(12, 10))
        
        # 网络发送流量图
        plt.subplot(2, 2, 1)
        plt.plot(network_df.index, network_df['bytes_sent_per_sec'], label='发送流量')
        plt.title('网络发送流量趋势')
        plt.ylabel('字节/秒')
        plt.grid(True)
        plt.legend()
        
        # 网络接收流量图
        plt.subplot(2, 2, 2)
        plt.plot(network_df.index, network_df['bytes_recv_per_sec'], label='接收流量')
        plt.title('网络接收流量趋势')
        plt.ylabel('字节/秒')
        plt.grid(True)
        plt.legend()
        
        # Google延迟图
        plt.subplot(2, 2, 3)
        plt.plot(network_df.index, network_df['ping_google_delay'], label='Google延迟')
        plt.title('Google网络延迟趋势')
        plt.ylabel('延迟 (ms)')
        plt.grid(True)
        plt.legend()
        
        # 百度延迟图
        plt.subplot(2, 2, 4)
        plt.plot(network_df.index, network_df['ping_baidu_delay'], label='百度延迟')
        plt.title('百度网络延迟趋势')
        plt.ylabel('延迟 (ms)')
        plt.grid(True)
        plt.legend()
        
        plt.tight_layout()
        plt.savefig(os.path.join(self.output_dir, 'network_performance.png'))
        plt.close()
        
        print("网络性能分析完成，图表已保存到 network_performance.png")
    
    def analyze_backend_data(self):
        """分析后端应用性能数据"""
        data = self.load_data('backend')
        if not data:
            print("没有后端应用性能监控数据")
            return
        
        # 转换为DataFrame
        df = pd.DataFrame(data)
        df['timestamp'] = pd.to_datetime(df['timestamp'])
        df.set_index('timestamp', inplace=True)
        
        # 提取后端应用响应时间和错误率
        backend_data = []
        for idx, row in df.iterrows():
            summary = row.get('endpoint_tests', {}).get('summary', {})
            backend_data.append({
                'timestamp': idx,
                'avg_response_time': summary.get('avg_response_time', 0),
                'error_rate': summary.get('error_rate', 0),
                'total_requests': summary.get('total_requests', 0)
            })
        backend_df = pd.DataFrame(backend_data)
        backend_df.set_index('timestamp', inplace=True)
        
        # 绘图
        plt.figure(figsize=(12, 8))
        
        # 响应时间图
        plt.subplot(2, 1, 1)
        plt.plot(backend_df.index, backend_df['avg_response_time'], label='平均响应时间')
        plt.title('后端应用平均响应时间趋势')
        plt.ylabel('时间 (ms)')
        plt.grid(True)
        plt.legend()
        
        # 错误率图
        plt.subplot(2, 1, 2)
        plt.plot(backend_df.index, backend_df['error_rate'], label='错误率')
        plt.title('后端应用错误率趋势')
        plt.ylabel('错误率 (%)')
        plt.grid(True)
        plt.legend()
        
        plt.tight_layout()
        plt.savefig(os.path.join(self.output_dir, 'backend_performance.png'))
        plt.close()
        
        print("后端应用性能分析完成，图表已保存到 backend_performance.png")
    
    def generate_summary_report(self):
        """生成监控数据汇总报告"""
        report_path = os.path.join(self.output_dir, 'monitoring_summary.md')
        
        with open(report_path, 'w', encoding='utf-8') as f:
            f.write('# Nginx服务器监控数据汇总报告\n\n')
            f.write(f'生成时间: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}\n\n')
            
            # 系统资源分析
            f.write('## 系统资源分析\n')
            system_data = self.load_data('system')
            if system_data:
                # 计算平均值
                cpu_total = []
                memory_percent = []
                for data in system_data:
                    cpu_total.append(data['cpu']['total'])
                    memory_percent.append(data['memory']['percent'])
                
                avg_cpu = sum(cpu_total) / len(cpu_total)
                avg_memory = sum(memory_percent) / len(memory_percent)
                
                f.write(f'- 平均CPU使用率: {avg_cpu:.2f}%\n')
                f.write(f'- 平均内存使用率: {avg_memory:.2f}%\n')
                
                # 检查是否有异常
                if avg_cpu > 80:
                    f.write('- **警告**: CPU使用率过高，可能是性能瓶颈\n')
                if avg_memory > 80:
                    f.write('- **警告**: 内存使用率过高，可能是性能瓶颈\n')
            else:
                f.write('- 没有系统资源监控数据\n')
            
            f.write('\n')
            
            # Nginx性能分析
            f.write('## Nginx性能分析\n')
            nginx_data = self.load_data('nginx')
            if nginx_data:
                # 计算平均值
                active_connections = []
                error_rates = []
                avg_request_times = []
                for data in nginx_data:
                    active_connections.append(data.get('stub_status', {}).get('active_connections', 0))
                    error_rates.append(data.get('access_log_stats', {}).get('error_rate', 0))
                    avg_request_times.append(data.get('access_log_stats', {}).get('avg_request_time', 0))
                
                avg_active_connections = sum(active_connections) / len(active_connections)
                avg_error_rate = sum(error_rates) / len(error_rates)
                avg_req_time = sum(avg_request_times) / len(avg_request_times)
                
                f.write(f'- 平均活跃连接数: {avg_active_connections:.2f}\n')
                f.write(f'- 平均错误率: {avg_error_rate:.2f}%\n')
                f.write(f'- 平均请求时间: {avg_req_time:.2f}ms\n')
                
                # 检查是否有异常
                if avg_error_rate > 0.05:
                    f.write('- **警告**: Nginx错误率过高，可能存在问题\n')
                if avg_req_time > 1000:
                    f.write('- **警告**: Nginx请求时间过长，可能是性能瓶颈\n')
            else:
                f.write('- 没有Nginx性能监控数据\n')
            
            f.write('\n')
            
            # 网络性能分析
            f.write('## 网络性能分析\n')
            network_data = self.load_data('network')
            if network_data:
                # 计算平均值
                ping_delays = []
                for data in network_data:
                    ping_google = data.get('ping_google', {})
                    if ping_google.get('success', False):
                        ping_delays.append(ping_google.get('avg_delay', 0))
                
                if ping_delays:
                    avg_ping_delay = sum(ping_delays) / len(ping_delays)
                    f.write(f'- 平均网络延迟: {avg_ping_delay:.2f}ms\n')
                    
                    # 检查是否有异常
                    if avg_ping_delay > 100:
                        f.write('- **警告**: 网络延迟过高，可能是性能瓶颈\n')
                else:
                    f.write('- 没有有效的网络延迟数据\n')
            else:
                f.write('- 没有网络性能监控数据\n')
            
            f.write('\n')
            
            # 后端应用分析
            f.write('## 后端应用分析\n')
            backend_data = self.load_data('backend')
            if backend_data:
                # 计算平均值
                backend_response_times = []
                backend_error_rates = []
                for data in backend_data:
                    summary = data.get('endpoint_tests', {}).get('summary', {})
                    backend_response_times.append(summary.get('avg_response_time', 0))
                    backend_error_rates.append(summary.get('error_rate', 0))
                
                avg_backend_response = sum(backend_response_times) / len(backend_response_times)
                avg_backend_error = sum(backend_error_rates) / len(backend_error_rates)
                
                f.write(f'- 平均响应时间: {avg_backend_response:.2f}ms\n')
                f.write(f'- 平均错误率: {avg_backend_error:.2f}%\n')
                
                # 检查是否有异常
                if avg_backend_response > 1000:
                    f.write('- **警告**: 后端应用响应时间过长，可能是性能瓶颈\n')
                if avg_backend_error > 0.05:
                    f.write('- **警告**: 后端应用错误率过高，可能存在问题\n')
            else:
                f.write('- 没有后端应用性能监控数据\n')
            
            f.write('\n')
            
            # 问题定位建议
            f.write('## 问题定位建议\n')
            f.write('根据监控数据，可能的性能瓶颈如下:\n')
            
            # 系统资源瓶颈
            if system_data:
                max_cpu = max([d['cpu']['total'] for d in system_data])
                max_memory = max([d['memory']['percent'] for d in system_data])
                if max_cpu > 90:
                    f.write('- **系统资源**: CPU使用率过高，建议检查是否有进程占用过多CPU\n')
                if max_memory > 90:
                    f.write('- **系统资源**: 内存使用率过高，建议检查是否有内存泄漏\n')
            
            # Nginx瓶颈
            if nginx_data:
                max_connections = max([d.get('stub_status', {}).get('active_connections', 0) for d in nginx_data])
                if max_connections > 1000:
                    f.write('- **Nginx**: 活跃连接数过高，建议调整Nginx配置，增加worker_processes和worker_connections\n')
            
            # 网络瓶颈
            if network_data:
                max_delay = max([d.get('ping_google', {}).get('avg_delay', 0) for d in network_data])
                if max_delay > 200:
                    f.write('- **网络**: 网络延迟过高，建议检查网络连接和带宽\n')
            
            # 后端应用瓶颈
            if backend_data:
                max_backend_response = max([d.get('endpoint_tests', {}).get('summary', {}).get('avg_response_time', 0) for d in backend_data])
                if max_backend_response > 2000:
                    f.write('- **后端应用**: 响应时间过长，建议检查后端应用代码和数据库查询\n')
    
    def run_analysis(self):
        """运行所有分析"""
        print("开始分析监控数据...")
        self.analyze_system_data()
        self.analyze_nginx_data()
        self.analyze_network_data()
        self.analyze_backend_data()
        self.generate_summary_report()
        print("监控数据分析完成")

if __name__ == "__main__":
    analyzer = DataAnalyzer()
    analyzer.run_analysis()
