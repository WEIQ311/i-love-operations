#!/bin/bash

# 定义用户名变量
USERNAME="root"

# 定义IP地址文件路径
IP_FILE="$(dirname "$0")/server_ip.txt"

# 定义输出JSON文件路径
OUTPUT_FILE="$(dirname "$0")/server_info.json"

# 检查IP文件是否存在
if [ ! -f "$IP_FILE" ]; then
    echo "错误: IP地址文件不存在: $IP_FILE"
    exit 1
fi

# 检查SSH密钥是否存在
check_ssh_key() {
    if [ ! -f "$HOME/.ssh/id_rsa" ] && [ ! -f "$HOME/.ssh/id_ed25519" ] && [ ! -f "$HOME/.ssh/id_ecdsa" ]; then
        echo "警告: 未找到SSH密钥文件"
        echo "请先运行 setup_ssh_key.sh 配置SSH密钥，或手动配置SSH密钥"
        echo ""
        echo "手动配置方法："
        echo "1. 生成SSH密钥: ssh-keygen -t rsa -b 2048"
        echo "2. 复制公钥到服务器: ssh-copy-id $USERNAME@<IP地址>"
        exit 1
    fi
}

# 函数：获取服务器信息（使用SSH密钥认证）
get_server_info() {
    local ip=$1
    local username=$2
    
    # 通过SSH执行命令获取系统信息
    local result=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        -o BatchMode=yes \
        "$username@$ip" 2>/dev/null << 'EOF'
        # 获取CPU信息
        CPU_CORES=$(nproc)
        # 获取CPU使用率（取1秒的平均值）
        CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
        # 如果上面的方法失败，使用另一种方法
        if [ -z "$CPU_USAGE" ] || [ "$CPU_USAGE" = "100" ]; then
            CPU_USAGE=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$3+$4+$5)} END {print usage}')
        fi
        
        # 获取内存信息（GB）
        MEM_TOTAL=$(free -m | awk 'NR==2{printf "%.2f", $2/1024}')
        MEM_USED=$(free -m | awk 'NR==2{printf "%.2f", $3/1024}')
        MEM_FREE=$(free -m | awk 'NR==2{printf "%.2f", $4/1024}')
        MEM_USAGE=$(free | awk 'NR==2{printf "%.2f", $3*100/$2}')
        
        # 获取磁盘信息（根分区，转换为GB）
        DISK_INFO=$(df -BG / | awk 'NR==2')
        if [ -n "$DISK_INFO" ]; then
            DISK_TOTAL=$(echo "$DISK_INFO" | awk '{print $2}' | sed 's/G//')
            DISK_USED=$(echo "$DISK_INFO" | awk '{print $3}' | sed 's/G//')
            DISK_FREE=$(echo "$DISK_INFO" | awk '{print $4}' | sed 's/G//')
            DISK_USAGE=$(echo "$DISK_INFO" | awk '{print $5}' | sed 's/%//')
        else
            # 如果df -BG不支持，使用df -h并转换
            DISK_TOTAL=$(df -h / | awk 'NR==2 {gsub(/[^0-9.]/, "", $2); print $2}')
            DISK_USED=$(df -h / | awk 'NR==2 {gsub(/[^0-9.]/, "", $3); print $3}')
            DISK_FREE=$(df -h / | awk 'NR==2 {gsub(/[^0-9.]/, "", $4); print $4}')
            DISK_USAGE=$(df -h / | awk 'NR==2 {gsub(/[^0-9.]/, "", $5); print $5}')
        fi
        
        # 输出JSON格式
        cat << JSON
{
  "cpu_cores": $CPU_CORES,
  "cpu_usage": $CPU_USAGE,
  "memory": {
    "total_gb": $MEM_TOTAL,
    "used_gb": $MEM_USED,
    "free_gb": $MEM_FREE,
    "usage_percent": $MEM_USAGE
  },
  "disk": {
    "total_gb": $DISK_TOTAL,
    "used_gb": $DISK_USED,
    "free_gb": $DISK_FREE,
    "usage_percent": $DISK_USAGE
  }
}
JSON
EOF
    )
    
    if [ $? -eq 0 ] && [ -n "$result" ]; then
        echo "$result"
        return 0
    else
        echo "{\"error\": \"无法连接到服务器或执行命令失败\"}"
        return 1
    fi
}

# 检查SSH密钥
check_ssh_key

# 主程序
echo "开始收集服务器信息（使用SSH密钥认证）..." >&2

# 创建临时文件存储JSON数组
TEMP_FILE=$(mktemp)
echo "[" > "$TEMP_FILE"

# 读取IP地址文件并处理每个IP
first=true
ip_count=0
success_count=0

while IFS= read -r ip || [ -n "$ip" ]; do
    # 跳过空行和注释行
    [[ -z "$ip" || "$ip" =~ ^#.*$ ]] && continue
    
    # 去除前后空格
    ip=$(echo "$ip" | xargs)
    
    if [ -z "$ip" ]; then
        continue
    fi
    
    ip_count=$((ip_count + 1))
    echo "正在收集 $ip 的信息... ($ip_count/$(wc -l < "$IP_FILE" | xargs))" >&2
    
    # 获取服务器信息
    server_info=$(get_server_info "$ip" "$USERNAME")
    
    # 检查是否成功
    if echo "$server_info" | grep -q '"error"'; then
        echo "警告: $ip 信息获取失败（请检查SSH密钥是否已配置）" >&2
    else
        success_count=$((success_count + 1))
    fi
    
    # 添加逗号（除了第一个）
    if [ "$first" = true ]; then
        first=false
    else
        echo "," >> "$TEMP_FILE"
    fi
    
    # 输出服务器信息（包含IP地址）
    echo "  {" >> "$TEMP_FILE"
    echo "    \"ip\": \"$ip\"," >> "$TEMP_FILE"
    # 将服务器信息缩进后追加，跳过第一行和最后一行的大括号，并处理JSON格式
    echo "$server_info" | sed '1d;$d' | sed 's/^/    /' >> "$TEMP_FILE"
    echo "  }" >> "$TEMP_FILE"
    
done < "$IP_FILE"

echo "" >> "$TEMP_FILE"
echo "]" >> "$TEMP_FILE"

# 将结果保存到输出文件
mv "$TEMP_FILE" "$OUTPUT_FILE"

echo "" >&2
echo "收集完成！成功: $success_count/$ip_count" >&2
echo "服务器信息已保存到: $OUTPUT_FILE" >&2
