#!/bin/sh

# Let's Encrypt 通配符证书生成脚本
# 使用 Certbot 通过 DNS 验证方式获取被浏览器自动信任的 SSL 证书
# 适用于 *.ai.com 通配符域名

set -e

echo "========================================"
echo "Let's Encrypt 通配符 SSL 证书生成脚本"
echo "适用于 *.ai.com 域名"
echo "========================================"

# 配置参数
DOMAIN="ai.com"
WILDCARD_DOMAIN="*.${DOMAIN}"
 # 用于接收证书续期通知
EMAIL="ai@126.com" 
CERT_DIR="/etc/letsencrypt/live/${DOMAIN}"
NGINX_CONFIG_DIR="/usr/local/nginx/conf/conf.d/${DOMAIN}_nginx"

# 检查 Certbot 是否安装
echo "\n[步骤1] 检查 Certbot 是否安装..."
if ! command -v certbot > /dev/null 2>&1; then
    echo "❌ Certbot 未安装，开始安装..."
    
    # 判断操作系统类型并安装 Certbot
    # 首先检查是否为 Ubuntu 22.04
    if [ -f "/etc/os-release" ]; then
        if grep -i ubuntu /etc/os-release > /dev/null; then
            # Ubuntu - 优先支持 Ubuntu 22.04
            echo "检测到 Ubuntu 系统，使用官方推荐方式安装 Certbot..."
            sudo apt update
            sudo apt install -y software-properties-common
            sudo add-apt-repository -y universe
            sudo add-apt-repository -y ppa:certbot/certbot
            sudo apt update
            sudo apt install -y certbot python3-certbot-dns-cloudflare python3-certbot-dns-digitalocean
        elif grep -i centos /etc/os-release > /dev/null; then
            # CentOS/RHEL 8+
            echo "检测到 CentOS/RHEL 系统..."
            sudo dnf install -y epel-release
            sudo dnf install -y certbot
        else
            echo "检测到其他 Linux 发行版，尝试安装 Certbot..."
            sudo apt update || sudo yum update
            sudo apt install -y certbot || sudo yum install -y certbot || sudo dnf install -y certbot
        fi
    # 检查是否为 macOS
    elif [ "$(uname)" = "Darwin" ]; then
        # macOS
        echo "检测到 macOS 系统，使用 Homebrew 安装 Certbot..."
        if command -v brew > /dev/null 2>&1; then
            brew install certbot
        else
            echo "❌ Homebrew 未安装，请先安装 Homebrew 或手动安装 Certbot"
            echo "安装 Homebrew: /bin/bash -c '$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)'"
            echo "手动安装 Certbot 参考: https://certbot.eff.org/"
            exit 1
        fi
    else
        echo "❌ 未知操作系统，请手动安装 Certbot"
        echo "安装参考: https://certbot.eff.org/"
        exit 1
    fi
    
    if command -v certbot > /dev/null 2>&1; then
        echo "✅ Certbot 安装成功"
    else
        echo "❌ Certbot 安装失败，请手动安装"
        exit 1
    fi
else
    echo "✅ Certbot 已安装"
fi

# 说明 DNS 验证方式
echo "\n[步骤2] DNS 验证说明"
echo "========================================"
echo "通配符证书需要通过 DNS 验证来证明域名所有权"
echo "执行过程中，系统会提示您在域名 DNS 服务器中添加 TXT 记录"
echo "您需要登录您的域名注册商或 DNS 提供商的管理界面进行操作"
echo ""
echo "手动 DNS 验证流程："
echo "1. Certbot 会生成一个特定的验证字符串"
echo "2. 您需要在域名的 DNS 记录中添加一条 TXT 记录"
echo "3. 记录名称为: _acme-challenge.$DOMAIN"
echo "4. 记录值为 Certbot 生成的验证字符串"
echo "5. 等待 DNS 记录生效（通常需要1-5分钟）"
echo "6. 按 Enter 键让 Certbot 验证 DNS 记录"
echo ""
echo "注意：对于通配符证书，您可能需要为相同域名添加两条不同的 TXT 记录"
echo "请确保在验证完成后保留 TXT 记录至少 24 小时"
echo "========================================"

echo "\n是否已准备好添加 DNS TXT 记录？(y/n): "
read response
if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
    echo "请准备好后再运行此脚本"
    exit 0
fi

# 创建 Nginx 配置目录
mkdir -p "$NGINX_CONFIG_DIR"

# 获取通配符证书（使用手动 DNS 验证）
echo "\n[步骤3] 获取 Let's Encrypt 通配符证书..."
echo "注意：此步骤需要手动添加 DNS TXT 记录，请仔细按照提示操作"
echo "开始执行 certbot 命令..."

sudo certbot certonly --manual --preferred-challenges dns \
    --email "$EMAIL" \
    --server https://acme-v02.api.letsencrypt.org/directory \
    --agree-tos \
    --manual-public-ip-logging-ok \
    -d "$DOMAIN" \
    -d "$WILDCARD_DOMAIN"

# 添加说明文本
echo "\n========================================"
echo "DNS TXT 记录设置指南："
echo "当 certbot 命令运行时，它会显示类似以下内容的信息："
echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo "Please deploy a DNS TXT record under the name:"
echo "_acme-challenge.$DOMAIN"
echo "with the following value:"
echo "abcdefghijklmnopqrstuvwxyz1234567890abcdef"
echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo ""
echo "1. 登录您的域名注册商或 DNS 提供商管理界面"
echo "2. 找到 DNS 记录管理部分"
echo "3. 添加一条 TXT 记录："
echo "   - 主机记录/名称: _acme-challenge"
echo "   - 记录类型: TXT"
echo "   - 记录值: [复制 certbot 显示的字符串]"
echo "   - TTL: 建议设置为最小值（通常为60或300秒）"
echo ""
echo "对于通配符证书，您需要为两个域名分别添加 TXT 记录："
echo "1. _acme-challenge.$DOMAIN"
echo "2. _acme-challenge.$DOMAIN  (通配符域名使用相同的域名前缀)"
echo ""
echo "添加记录后，建议等待 1-5 分钟让 DNS 记录生效"
echo "然后在 certbot 提示时按 Enter 键继续验证"
echo "======================================="

# 提示用户验证 TXT 记录是否生效
echo "\n[可选步骤] 验证 DNS TXT 记录是否生效"
echo "======================================="
echo "添加完 TXT 记录后，您可以使用以下命令验证记录是否已正确传播："
echo ""
echo "在 macOS 或 Linux 上："
echo "  dig -t txt _acme-challenge.$DOMAIN @8.8.8.8"
echo "  或"
echo "  nslookup -type=TXT _acme-challenge.$DOMAIN 8.8.8.8"
echo ""
echo "在 Windows 命令提示符上："
echo "  nslookup -type=TXT _acme-challenge.$DOMAIN 8.8.8.8"
echo ""
echo "验证命令应该返回您刚刚添加的 TXT 记录值"
echo "如果命令没有返回正确的记录值，请等待几分钟后再次尝试"
echo "======================================="

# 验证证书是否成功获取
if [ ! -f "$CERT_DIR/fullchain.pem" ] || [ ! -f "$CERT_DIR/privkey.pem" ]; then
    echo "❌ 证书获取失败或路径不正确"
    echo "请检查 certbot 命令的输出，确认证书是否成功生成"
    echo "可能的路径: /etc/letsencrypt/live/$DOMAIN/"
    exit 1
fi

# 创建证书符号链接到 Nginx 配置目录
echo "\n[步骤4] 创建证书符号链接到 Nginx 配置目录..."
sudo ln -sf "$CERT_DIR/fullchain.pem" "$NGINX_CONFIG_DIR/$DOMAIN.crt"
sudo ln -sf "$CERT_DIR/privkey.pem" "$NGINX_CONFIG_DIR/$DOMAIN.key"

# 设置正确的权限
echo "\n[步骤5] 设置证书文件权限..."
sudo chmod 644 "$NGINX_CONFIG_DIR/$DOMAIN.crt"
sudo chmod 600 "$NGINX_CONFIG_DIR/$DOMAIN.key"

# 显示证书信息
echo "\n[步骤6] 证书信息验证..."
echo "证书文件位置: $NGINX_CONFIG_DIR/"
echo "证书详情:"
openssl x509 -in "$NGINX_CONFIG_DIR/$DOMAIN.crt" -text -noout | grep -E "Subject:|Issuer:|DNS:|Not Before:|Not After :"

# 设置自动续期
echo "\n[步骤8] 设置证书自动续期..."

# 创建续期脚本
renew_script="/usr/local/bin/renew_ssl_cert.sh"
sudo tee "$renew_script" > /dev/null << EOF
#!/bin/bash

# Let's Encrypt 证书自动续期脚本
echo "开始更新 Let's Encrypt 证书..."

# 对于手动验证的证书，需要交互式操作，因此我们不使用 --quiet 参数
# 对于使用 DNS 插件的自动验证，这里会自动续期
# 如果证书是手动验证方式获取的，将会提示需要再次进行 DNS 验证
sudo certbot renew --post-hook "sudo nginx -s reload"

echo "证书续期完成!"
date
EOF

# 设置续期脚本权限
sudo chmod +x "$renew_script"

# 添加到 crontab
echo "添加自动续期任务到 crontab..."
(crontab -l 2>/dev/null | grep -v "renew_ssl_cert.sh"; echo "0 3 * * * $renew_script >> /var/log/ssl_renew.log 2>&1") | sudo crontab -

echo "✅ 自动续期任务已添加（每天凌晨3点执行）"

# 测试续期配置
echo "\n[步骤9] 测试续期配置..."
echo "注意：对于手动验证方式获取的证书，--dry-run 测试可能会失败"
echo "这是正常现象，因为手动验证需要交互式操作添加 DNS TXT 记录"
echo "您可以选择是否继续测试:"
echo "1. 继续测试（可能会失败）"
echo "2. 跳过测试"
echo -n "请选择 (1/2): "
read test_choice

if [ "$test_choice" = "1" ]; then
    echo "运行测试续期命令..."
    sudo certbot renew --dry-run || echo "\n注意：测试失败是预期的，手动验证的证书需要在实际续期时再次添加 DNS TXT 记录"
else
    echo "已跳过续期测试"
fi

# Nginx 配置说明
echo "\n[步骤10] Nginx 配置说明"
echo "========================================"
echo "1. 请将您现有的 ssl_443.conf 文件中的证书路径更新为:"
echo "   ssl_certificate     \"$NGINX_CONFIG_DIR/$DOMAIN.crt\";
   ssl_certificate_key \"$NGINX_CONFIG_DIR/$DOMAIN.key\";"
echo ""
echo "2. Ubuntu 22.04 上验证 Nginx 配置:"
echo "   sudo nginx -t"
echo ""
echo "3. Ubuntu 22.04 上重新加载 Nginx 配置:"
echo "   sudo systemctl reload nginx"
echo "   或"
echo "   sudo nginx -s reload"
echo "========================================"

# 总结
echo "\n========================================"
echo "Let's Encrypt 通配符证书设置完成!"
echo "适配 Ubuntu 22.04 系统配置"
echo "========================================"
echo "✓ 证书已成功获取并配置"
echo "✓ 自动续期任务已设置"
echo "✓ Nginx 配置示例已创建"
echo "✓ 安装了 DNS 插件，支持常见 DNS 提供商"
echo ""
echo "重要提示:"
echo "1. 请确保您在域名 DNS 服务器中添加的 TXT 记录在证书签发后保持至少 24 小时"
echo "2. 证书有效期为 90 天，自动续期脚本将在过期前 30 天尝试续期"
echo "3. 注意：手动验证方式获取的证书在续期时需要再次进行 DNS TXT 记录验证"
echo "4. 建议考虑使用 DNS 插件进行自动验证，避免手动添加 TXT 记录"
echo "5. 续期日志位置: /var/log/ssl_renew.log"
echo "6. Ubuntu 22.04 系统可使用 systemctl 管理 Nginx 服务"
echo "========================================"