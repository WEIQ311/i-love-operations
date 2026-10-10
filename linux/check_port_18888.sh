#!/bin/bash

# 检测端口18888是否启动的脚本

PORT=18888
START_SCRIPT="/opt/soft/xxx-server/start.sh"

# 检查端口是否被占用
check_port() {
    if lsof -i:$PORT > /dev/null 2>&1; then
        return 0  # 端口已启动
    else
        return 1  # 端口未启动
    fi
}

echo "开始检测端口 $PORT..."

if check_port; then
    echo "端口 $PORT 已启动，无需操作"
else
    echo "端口 $PORT 未启动，准备执行启动脚本..."
    
    # 检查启动脚本是否存在
    if [ -f "$START_SCRIPT" ]; then
        echo "执行启动脚本: $START_SCRIPT"
        # 获取脚本所在目录
        SCRIPT_DIR=$(dirname "$START_SCRIPT")
        # 切换到脚本目录
        cd "$SCRIPT_DIR"
        echo "切换到目录: $SCRIPT_DIR"
        # 执行启动脚本
        bash "$(basename "$START_SCRIPT")"
        echo "启动脚本执行完成"
    else
        echo "错误: 启动脚本 $START_SCRIPT 不存在"
        exit 1
    fi
fi

echo "检测完成"
