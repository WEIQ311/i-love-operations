#!/usr/bin/env python3
import os
import sys
import time
import subprocess
import json
from datetime import datetime

class MonitorManager:
    def __init__(self):
        self.scripts_dir = os.path.join(os.path.dirname(__file__), 'scripts')
        self.logs_dir = os.path.join(os.path.dirname(__file__), 'logs')
        self.data_dir = os.path.join(os.path.dirname(__file__), 'data')
        
        # 创建必要的目录
        os.makedirs(self.logs_dir, exist_ok=True)
        os.makedirs(self.data_dir, exist_ok=True)
        
        # 监控脚本配置
        self.monitor_scripts = {
            'system': os.path.join(self.scripts_dir, 'system', 'system_monitor.py'),
            'nginx': os.path.join(self.scripts_dir, 'nginx', 'nginx_monitor.py'),
            'network': os.path.join(self.scripts_dir, 'network', 'network_monitor.py'),
            'backend': os.path.join(self.scripts_dir, 'backend', 'backend_monitor.py')
        }
        
        # 进程ID存储
        self.pids_file = os.path.join(self.logs_dir, 'monitor_pids.json')
        self.pids = {}
    
    def start_monitor(self, monitor_type):
        """启动指定类型的监控脚本"""
        if monitor_type not in self.monitor_scripts:
            print(f"错误: 未知的监控类型 '{monitor_type}'")
            return False
        
        script_path = self.monitor_scripts[monitor_type]
        if not os.path.exists(script_path):
            print(f"错误: 监控脚本不存在: {script_path}")
            return False
        
        # 检查脚本是否已经在运行
        if monitor_type in self.pids and self.is_process_running(self.pids[monitor_type]):
            print(f"监控 '{monitor_type}' 已经在运行")
            return False
        
        # 启动脚本
        print(f"启动监控: {monitor_type}")
        log_file = os.path.join(self.logs_dir, f'{monitor_type}_monitor.log')
        
        # 使用subprocess启动脚本，并将输出重定向到日志文件
        process = subprocess.Popen(
            [sys.executable, script_path],
            stdout=open(log_file, 'a'),
            stderr=open(log_file, 'a'),
            cwd=os.path.dirname(script_path)
        )
        
        # 存储进程ID
        self.pids[monitor_type] = process.pid
        self.save_pids()
        print(f"监控 '{monitor_type}' 已启动，进程ID: {process.pid}")
        return True
    
    def stop_monitor(self, monitor_type):
        """停止指定类型的监控脚本"""
        if monitor_type not in self.pids:
            print(f"监控 '{monitor_type}' 未运行")
            return False
        
        pid = self.pids[monitor_type]
        if not self.is_process_running(pid):
            print(f"监控 '{monitor_type}' 进程不存在或已停止")
            del self.pids[monitor_type]
            self.save_pids()
            return False
        
        # 停止进程
        print(f"停止监控: {monitor_type}, 进程ID: {pid}")
        try:
            os.kill(pid, 2)  # 发送SIGINT信号
            # 等待进程终止
            time.sleep(2)
            if self.is_process_running(pid):
                os.kill(pid, 9)  # 强制终止
        except Exception as e:
            print(f"停止监控时发生错误: {e}")
            return False
        
        # 从存储中删除进程ID
        del self.pids[monitor_type]
        self.save_pids()
        print(f"监控 '{monitor_type}' 已停止")
        return True
    
    def start_all(self):
        """启动所有监控脚本"""
        print("启动所有监控脚本...")
        for monitor_type in self.monitor_scripts:
            self.start_monitor(monitor_type)
        print("所有监控脚本启动完成")
    
    def stop_all(self):
        """停止所有监控脚本"""
        print("停止所有监控脚本...")
        for monitor_type in list(self.pids.keys()):
            self.stop_monitor(monitor_type)
        print("所有监控脚本停止完成")
    
    def status(self):
        """查看监控脚本状态"""
        print("监控脚本状态:")
        print("-" * 50)
        
        # 加载最新的进程ID
        self.load_pids()
        
        for monitor_type in self.monitor_scripts:
            if monitor_type in self.pids and self.is_process_running(self.pids[monitor_type]):
                print(f"{monitor_type}: 运行中 (PID: {self.pids[monitor_type]})")
            else:
                print(f"{monitor_type}: 未运行")
        print("-" * 50)
    
    def run_analysis(self):
        """运行监控数据分析"""
        analysis_script = os.path.join(self.scripts_dir, 'visualization', 'data_analyzer.py')
        if not os.path.exists(analysis_script):
            print(f"错误: 分析脚本不存在: {analysis_script}")
            return False
        
        print("运行监控数据分析...")
        try:
            result = subprocess.run(
                [sys.executable, analysis_script],
                capture_output=True,
                text=True,
                cwd=os.path.dirname(analysis_script)
            )
            print(result.stdout)
            if result.stderr:
                print(f"错误输出: {result.stderr}")
            print("监控数据分析完成")
            return True
        except Exception as e:
            print(f"运行分析时发生错误: {e}")
            return False
    
    def is_process_running(self, pid):
        """检查进程是否正在运行"""
        try:
            os.kill(pid, 0)  # 发送0信号，不做任何操作，只检查进程是否存在
            return True
        except OSError:
            return False
    
    def save_pids(self):
        """保存进程ID到文件"""
        try:
            with open(self.pids_file, 'w', encoding='utf-8') as f:
                json.dump(self.pids, f, ensure_ascii=False, indent=2)
        except Exception as e:
            print(f"保存进程ID失败: {e}")
    
    def load_pids(self):
        """从文件加载进程ID"""
        try:
            if os.path.exists(self.pids_file):
                with open(self.pids_file, 'r', encoding='utf-8') as f:
                    self.pids = json.load(f)
                
                # 清理已停止的进程
                for monitor_type, pid in list(self.pids.items()):
                    if not self.is_process_running(pid):
                        del self.pids[monitor_type]
                
                # 保存清理后的进程ID
                self.save_pids()
        except Exception as e:
            print(f"加载进程ID失败: {e}")
            self.pids = {}
    
    def main(self):
        """主函数"""
        # 加载进程ID
        self.load_pids()
        
        # 解析命令行参数
        if len(sys.argv) < 2:
            self.show_help()
            return
        
        command = sys.argv[1].lower()
        
        if command == 'start':
            if len(sys.argv) == 2:
                # 启动所有监控
                self.start_all()
            else:
                # 启动指定监控
                monitor_type = sys.argv[2].lower()
                self.start_monitor(monitor_type)
        
        elif command == 'stop':
            if len(sys.argv) == 2:
                # 停止所有监控
                self.stop_all()
            else:
                # 停止指定监控
                monitor_type = sys.argv[2].lower()
                self.stop_monitor(monitor_type)
        
        elif command == 'status':
            # 查看状态
            self.status()
        
        elif command == 'analyze':
            # 运行分析
            self.run_analysis()
        
        elif command == 'help':
            # 显示帮助
            self.show_help()
        
        else:
            print(f"错误: 未知命令 '{command}'")
            self.show_help()
    
    def show_help(self):
        """显示帮助信息"""
        print("Nginx服务器监控工具")
        print("用法:")
        print("  python monitor.py start [monitor_type]    启动监控脚本")
        print("  python monitor.py stop [monitor_type]     停止监控脚本")
        print("  python monitor.py status                  查看监控脚本状态")
        print("  python monitor.py analyze                 运行监控数据分析")
        print("  python monitor.py help                    显示帮助信息")
        print("\n监控类型:")
        print("  system        系统资源监控")
        print("  nginx         Nginx性能监控")
        print("  network       网络性能监控")
        print("  backend       后端应用性能监控")
        print("\n示例:")
        print("  python monitor.py start                  启动所有监控脚本")
        print("  python monitor.py start nginx            只启动Nginx监控脚本")
        print("  python monitor.py stop                   停止所有监控脚本")
        print("  python monitor.py status                 查看所有监控脚本状态")
        print("  python monitor.py analyze                运行监控数据分析")

if __name__ == "__main__":
    manager = MonitorManager()
    manager.main()
