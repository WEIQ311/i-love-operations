#!/bin/bash

# SSH密钥配置辅助脚本
# 此脚本帮助您配置SSH密钥，以便无需密码即可连接服务器

# 定义用户名和密码变量（与主脚本保持一致）
USERNAME="root"
PASSWORD="your_password_here"

# 定义IP地址文件路径
IP_FILE="$(dirname "$0")/server_ip.txt"

# 检测可用的密码输入工具
detect_password_tool() {
    if command -v sshpass &> /dev/null; then
        echo "sshpass"
    elif command -v expect &> /dev/null; then
        echo "expect"
    else
        echo "none"
    fi
}

PASSWORD_TOOL=$(detect_password_tool)

# 检查IP文件是否存在
if [ ! -f "$IP_FILE" ]; then
    echo "错误: IP地址文件不存在: $IP_FILE"
    exit 1
fi

# 检查是否已有SSH密钥
check_existing_key() {
    if [ -f "$HOME/.ssh/id_rsa" ] || [ -f "$HOME/.ssh/id_ed25519" ] || [ -f "$HOME/.ssh/id_ecdsa" ]; then
        echo "检测到已存在的SSH密钥"
        read -p "是否使用现有密钥？(y/n): " use_existing
        if [ "$use_existing" != "y" ] && [ "$use_existing" != "Y" ]; then
            return 1
        fi
        return 0
    fi
    return 1
}

# 生成SSH密钥
generate_ssh_key() {
    echo "正在生成SSH密钥..."
    read -p "请输入密钥保存路径（直接回车使用默认路径 ~/.ssh/id_rsa）: " key_path
    
    if [ -z "$key_path" ]; then
        key_path="$HOME/.ssh/id_rsa"
    fi
    
    # 确保.ssh目录存在
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    
    # 生成密钥
    ssh-keygen -t rsa -b 2048 -f "$key_path" -N ""
    
    if [ $? -eq 0 ]; then
        echo "SSH密钥生成成功: $key_path"
        echo "$key_path"
        return 0
    else
        echo "SSH密钥生成失败"
        return 1
    fi
}

# 使用sshpass复制公钥到服务器
copy_key_with_sshpass() {
    local ip=$1
    local username=$2
    local key_path=$3
    local password=$4
    
    if command -v ssh-copy-id &> /dev/null; then
        sshpass -p "$password" ssh-copy-id -i "${key_path}.pub" -o StrictHostKeyChecking=no "$username@$ip" 2>/dev/null
    else
        # 手动复制：通过管道传递公钥内容
        cat "${key_path}.pub" | sshpass -p "$password" ssh -o StrictHostKeyChecking=no "$username@$ip" \
            "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys" 2>/dev/null
    fi
}

# 使用expect复制公钥到服务器
copy_key_with_expect() {
    local ip=$1
    local username=$2
    local key_path=$3
    local password=$4
    
    local expect_script=$(mktemp)
    cat > "$expect_script" << 'EXPECT_EOF'
#!/usr/bin/expect -f
set timeout 30
set ip [lindex $argv 0]
set username [lindex $argv 1]
set key_file [lindex $argv 2]
set password [lindex $argv 3]

# 优先使用ssh-copy-id
if {[file executable "/usr/bin/ssh-copy-id"] || [file executable "/bin/ssh-copy-id"]} {
    spawn ssh-copy-id -i $key_file -o StrictHostKeyChecking=no $username@$ip
    expect {
        "password:" {
            send "$password\r"
            exp_continue
        }
        "yes/no" {
            send "yes\r"
            exp_continue
        }
        eof {
            # 正常结束
        }
        timeout {
            exit 1
        }
    }
} else {
    # 手动复制公钥：先读取公钥内容，然后通过SSH命令传递
    set fp [open $key_file r]
    set pub_key [read $fp]
    close $fp
    
    spawn ssh -o StrictHostKeyChecking=no $username@$ip "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$pub_key' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
    expect {
        "password:" {
            send "$password\r"
            exp_continue
        }
        "yes/no" {
            send "yes\r"
            exp_continue
        }
        eof {
            # 正常结束
        }
        timeout {
            exit 1
        }
    }
}

catch wait result
set exit_code [lindex $result 3]
exit $exit_code
EXPECT_EOF
    
    chmod +x "$expect_script"
    "$expect_script" "$ip" "$username" "${key_path}.pub" "$password" > /dev/null 2>&1
    local result=$?
    rm -f "$expect_script"
    return $result
}

# 手动复制公钥到服务器（需要用户输入密码）
copy_key_manual() {
    local ip=$1
    local username=$2
    local key_path=$3
    
    echo "提示: 请手动输入 $ip 的密码"
    
    if command -v ssh-copy-id &> /dev/null; then
        ssh-copy-id -i "${key_path}.pub" -o StrictHostKeyChecking=no "$username@$ip"
    else
        cat "${key_path}.pub" | ssh -o StrictHostKeyChecking=no "$username@$ip" \
            "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
    fi
}

# 复制公钥到服务器（统一接口）
copy_key_to_server() {
    local ip=$1
    local username=$2
    local key_path=$3
    local password=$4
    local tool=$5
    
    echo ""
    echo "正在配置服务器: $ip"
    
    case "$tool" in
        sshpass)
            copy_key_with_sshpass "$ip" "$username" "$key_path" "$password"
            ;;
        expect)
            copy_key_with_expect "$ip" "$username" "$key_path" "$password"
            ;;
        *)
            copy_key_manual "$ip" "$username" "$key_path"
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        echo "✓ $ip 配置成功"
        return 0
    else
        echo "✗ $ip 配置失败，请检查用户名和密码"
        return 1
    fi
}

# 测试SSH连接
test_ssh_connection() {
    local ip=$1
    local username=$2
    
    echo "测试连接 $ip ..."
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes \
        "$username@$ip" "echo '连接成功'" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "✓ $ip 连接测试成功（无需密码）"
        return 0
    else
        echo "✗ $ip 连接测试失败（仍需要密码）"
        return 1
    fi
}

# 主程序
echo "=========================================="
echo "SSH密钥配置工具"
echo "=========================================="
echo ""

# 显示使用的工具
case "$PASSWORD_TOOL" in
    sshpass)
        echo "检测到 sshpass，将自动使用密码变量"
        ;;
    expect)
        echo "检测到 expect，将自动使用密码变量"
        ;;
    none)
        echo "未检测到 sshpass 或 expect"
        echo "提示: 如果希望自动输入密码，可以安装以下工具之一："
        echo "  - sshpass: yum install sshpass -y 或 apt-get install sshpass"
        echo "  - expect: yum install expect -y 或 apt-get install expect"
        echo "如果没有安装，将需要手动输入每台服务器的密码"
        echo ""
        read -p "是否继续？(y/n): " continue_choice
        if [ "$continue_choice" != "y" ] && [ "$continue_choice" != "Y" ]; then
            exit 0
        fi
        ;;
esac
echo ""

# 检查是否已有密钥
key_path=""
if check_existing_key; then
    # 使用现有密钥
    if [ -f "$HOME/.ssh/id_rsa" ]; then
        key_path="$HOME/.ssh/id_rsa"
    elif [ -f "$HOME/.ssh/id_ed25519" ]; then
        key_path="$HOME/.ssh/id_ed25519"
    elif [ -f "$HOME/.ssh/id_ecdsa" ]; then
        key_path="$HOME/.ssh/id_ecdsa"
    fi
else
    # 生成新密钥
    key_path=$(generate_ssh_key)
    if [ $? -ne 0 ]; then
        exit 1
    fi
fi

echo ""
echo "开始配置所有服务器的SSH密钥..."
echo ""

# 读取IP地址文件并配置每个服务器
success_count=0
total_count=0

while IFS= read -r ip || [ -n "$ip" ]; do
    # 跳过空行和注释行
    [[ -z "$ip" || "$ip" =~ ^#.*$ ]] && continue
    
    # 去除前后空格
    ip=$(echo "$ip" | xargs)
    
    if [ -z "$ip" ]; then
        continue
    fi
    
    total_count=$((total_count + 1))
    
    # 复制密钥到服务器
    if copy_key_to_server "$ip" "$USERNAME" "$key_path" "$PASSWORD" "$PASSWORD_TOOL"; then
        success_count=$((success_count + 1))
    fi
done < "$IP_FILE"

echo ""
echo "=========================================="
echo "配置完成！成功: $success_count/$total_count"
echo "=========================================="
echo ""

# 测试所有连接
echo "正在测试所有服务器的连接..."
test_success=0
while IFS= read -r ip || [ -n "$ip" ]; do
    [[ -z "$ip" || "$ip" =~ ^#.*$ ]] && continue
    ip=$(echo "$ip" | xargs)
    [ -z "$ip" ] && continue
    
    if test_ssh_connection "$ip" "$USERNAME"; then
        test_success=$((test_success + 1))
    fi
done < "$IP_FILE"

echo ""
if [ $test_success -eq $total_count ]; then
    echo "✓ 所有服务器配置成功！现在可以运行 collect_server_info.sh 了"
else
    echo "警告: 部分服务器配置可能未成功，请检查上述错误信息"
fi

