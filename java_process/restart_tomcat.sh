#!/bin/bash

# 定义公共变量
WEB_INF_PATH="webapps/dms/WEB-INF"
STARTUP_PATTERN='org\.apache\.catalina\.startup\.Catalina\.start.*Server startup in'
LIB_REPLACE_CMD="cd $WEB_INF_PATH && rm -rf lib && cp -r lib_new lib && cd -"
MAX_WAIT=300

# 获取当前时间戳作为标识
CURRENT_TIME=$(date +%s)

# 定义临时日志文件路径
TEMP_LOG="logs/catalina_restart_${CURRENT_TIME}.log"

# 创建临时日志文件（如果不存在）
touch "$TEMP_LOG"

# 记录启动前日志文件的大小
if [ -f "logs/catalina.out" ]; then
    LOG_SIZE=$(stat -c%s "logs/catalina.out")
else
    LOG_SIZE=0
fi

echo "Restarting Tomcat..."
cd $WEB_INF_PATH && rm -rf lib && cp -r libbak0723 lib && cd -
./bin/shutdown.sh
# 根据当前目录查找Tomcat进程的PID并终止它们
ps -ef | grep "$(pwd)" | grep -v grep | awk '{print $2}' | xargs kill -9 2>/dev/null
sleep 5
./bin/startup.sh
# 当监控日志出现org.apache.catalina.startup.Catalina.start Server startup in 时打印启动结束
# 使用awk处理，匹配到启动信息后打印提示并退出
{
    echo "正在监控Tomcat启动状态..."
    echo "记录启动前日志大小: ${LOG_SIZE}字节"
    
    # 首先检查日志文件是否存在
    if [ ! -f "logs/catalina.out" ]; then
        echo "警告：未找到logs/catalina.out文件，尝试查找实际的日志文件位置..."
        CATALINA_LOG=$(find . -name "catalina.out" 2>/dev/null | head -1)
        if [ -z "$CATALINA_LOG" ]; then
            echo "错误：找不到catalina.out日志文件"
            touch "$CATALINA_LOG"
            echo "已创建空日志文件：$CATALINA_LOG"
        else
            echo "找到日志文件：$CATALINA_LOG"
        fi
    else
        CATALINA_LOG="logs/catalina.out"
    fi
    
    # 使用新的方法监控日志：只关注新写入的内容
    WAIT_COUNT=0
    
    echo "等待Tomcat启动完成..."
    while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
        # 只读取日志文件中新增的部分
        # 使用dd命令从LOG_SIZE位置开始读取
        if [ -f "$CATALINA_LOG" ]; then
            # 方式1: 使用dd命令读取新增内容并保存到临时文件
            dd if="$CATALINA_LOG" of="$TEMP_LOG" bs=1 skip=${LOG_SIZE} 2>/dev/null
            
            # 方式2: 同时使用tail -f方式监控实时写入
            # (tail -f "$CATALINA_LOG" -n +$(($LOG_SIZE/40+1)) &> "$TEMP_LOG" &)
            # TAIL_PID=$!
            
            # 检查临时日志文件中是否包含启动信息
            STARTUP_LOG=$(grep -E "$STARTUP_PATTERN" "$TEMP_LOG" | tail -1)
            if [ -n "$STARTUP_LOG" ]; then
                echo "检测到Tomcat启动完成（新写入的日志）"
                eval "$LIB_REPLACE_CMD"
                echo "Tomcat启动结束"
                # 清理临时文件
                rm -f "$TEMP_LOG"
                break
            fi
        fi
        
        # 每2秒检查一次
        sleep 2
        WAIT_COUNT=$((WAIT_COUNT+2))
    done
    
    # 如果超时
    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
        echo "警告：Tomcat启动监控超时（${MAX_WAIT}秒）"
        # 清理临时文件
        rm -f "$TEMP_LOG"
        exit 1
    fi
}

# 当监控完成后，才会执行到这里
if [ $? -eq 0 ]; then
    echo "Tomcat启动成功..."
else
    echo "Tomcat启动监控过程出现异常"
fi
