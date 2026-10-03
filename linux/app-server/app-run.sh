#!/bin/bash

################################################################################
# Web应用启动脚本（开发环境）
# 说明：此脚本用于开发环境快速启动web服务
################################################################################

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 1. 创建目录
mkdir app-server

# 2. 解压环境到目录中
tar -xzf linux_offline_env.tar.gz -C app-server

# 3. 激活环境 (conda-pack 的神奇之处)
source app-server/bin/activate

# 3.5. 修复 GLIBC 兼容性问题（如果存在）
if [ -f "fix_glibc_compatibility.sh" ]; then
    echo "🔧 检查并修复 GLIBC 兼容性问题..."
    bash fix_glibc_compatibility.sh
fi

# 4. 验证 Python 版本
python3 --version
# 此时应该显示 Python 3.12.x，且 pip list 包含你的依赖

# 检查Python
if ! command -v python3 &> /dev/null; then
    echo "错误: 未找到 python3 命令"
    echo "请先安装 Python 3.6 或更高版本"
    exit 1
fi

echo "======================================================"
echo "应用服务器监控工具"
echo "用法:"
echo "  python monitor.py start [monitor_type]    启动监控脚本"
echo "  python monitor.py stop [monitor_type]     停止监控脚本"
echo "  python monitor.py status                  查看监控脚本状态"
echo "  python monitor.py analyze                 运行监控数据分析"
echo "  python monitor.py help                    显示帮助信息"
echo "======================================================"
echo "监控类型:"
echo "  system        系统资源监控"
echo "  nginx         Nginx性能监控"
echo "  network       网络性能监控"
echo "  backend       后端应用性能监控"
echo "======================================================"
echo "示例:"
echo "  python monitor.py start                  启动所有监控脚本"
echo "  python monitor.py start nginx            只启动Nginx监控脚本"
echo "  python monitor.py stop                   停止所有监控脚本"
echo "  python monitor.py status                 查看所有监控脚本状态"
echo "  python monitor.py analyze                运行监控数据分析"
echo "======================================================"