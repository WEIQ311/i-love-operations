# Certbot DNS 自动验证指南

本文档介绍如何使用 Certbot 的 DNS 插件自动完成 Let's Encrypt 通配符证书的验证过程，无需手动添加 TXT 记录。

## 1. 为什么需要自动 DNS 验证？

使用手动 DNS 验证时，您需要：
1. 等待 Certbot 生成验证字符串
2. 手动登录 DNS 提供商界面添加 TXT 记录
3. 等待 DNS 传播
4. 按 Enter 继续验证

而使用 DNS 插件可以自动化这整个过程，特别是对于证书续期非常有用。

## 2. 支持的 DNS 插件

Certbot 支持多种 DNS 提供商的插件，常用的包括：

- Cloudflare: `python3-certbot-dns-cloudflare`
- AWS Route 53: `python3-certbot-dns-route53`
- Google Cloud DNS: `python3-certbot-dns-google`
- DigitalOcean: `python3-certbot-dns-digitalocean`
- Alibaba Cloud DNS: `python3-certbot-dns-aliyun` (需要单独安装)
- DNSPod: `python3-certbot-dns-dnspod` (需要单独安装)

## 3. DNS 插件使用方法

### 3.1 安装 DNS 插件

以 Cloudflare 为例：

```bash
# Ubuntu/Debian
sudo apt install python3-certbot-dns-cloudflare

# CentOS/RHEL
sudo dnf install python3-certbot-dns-cloudflare
```

### 3.2 配置 DNS API 凭证

以 Cloudflare 为例，创建 API 凭证配置文件：

```bash
# 创建配置文件目录
mkdir -p ~/.secrets/certbot

# 创建 Cloudflare API 配置文件
cat > ~/.secrets/certbot/cloudflare.ini << EOF
dns_cloudflare_email = your_cloudflare_email@example.com
dns_cloudflare_api_key = your_global_api_key
EOF

# 设置权限
sudo chmod 600 ~/.secrets/certbot/cloudflare.ini
```

> 注意：请替换为您自己的 Cloudflare 邮箱和全局 API 密钥

### 3.3 使用 DNS 插件获取证书

```bash
sudo certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials ~/.secrets/certbot/cloudflare.ini \
  --dns-cloudflare-propagation-seconds 60 \
  --email admin@ai.com \
  --server https://acme-v02.api.letsencrypt.org/directory \
  --agree-tos \
  -d ai.com \
  -d *.ai.com
```

## 4. 常用 DNS 插件配置示例

### 4.1 Alibaba Cloud DNS

首先安装插件：
```bash
pip install certbot-dns-aliyun
```

创建配置文件：
```bash
cat > ~/.secrets/certbot/aliyun.ini << EOF
dns_aliyun_access_key = your_access_key_id
dns_aliyun_access_secret = your_access_key_secret
EOF

sudo chmod 600 ~/.secrets/certbot/aliyun.ini
```

获取证书：
```bash
sudo certbot certonly \
  --dns-aliyun \
  --dns-aliyun-credentials ~/.secrets/certbot/aliyun.ini \
  --dns-aliyun-propagation-seconds 60 \
  --email admin@ai.com \
  --server https://acme-v02.api.letsencrypt.org/directory \
  --agree-tos \
  -d ai.com \
  -d *.ai.com
```

### 4.2 DNSPod

首先安装插件：
```bash
pip install certbot-dns-dnspod
```

创建配置文件：
```bash
cat > ~/.secrets/certbot/dnspod.ini << EOF
dns_dnspod_api_id = your_api_id
dns_dnspod_api_token = your_api_token
EOF

sudo chmod 600 ~/.secrets/certbot/dnspod.ini
```

获取证书：
```bash
sudo certbot certonly \
  --dns-dnspod \
  --dns-dnspod-credentials ~/.secrets/certbot/dnspod.ini \
  --dns-dnspod-propagation-seconds 60 \
  --email admin@ai.com \
  --server https://acme-v02.api.letsencrypt.org/directory \
  --agree-tos \
  -d ai.com \
  -d *.ai.com
```

## 5. 集成到自动续期脚本

当使用 DNS 插件时，证书续期可以完全自动化。修改之前的续期脚本：

```bash
#!/bin/bash

# Let's Encrypt 证书自动续期脚本
echo "开始更新 Let's Encrypt 证书..."

# 使用 Cloudflare DNS 插件自动续期
sudo certbot renew \
  --dns-cloudflare \
  --dns-cloudflare-credentials ~/.secrets/certbot/cloudflare.ini \
  --dns-cloudflare-propagation-seconds 60 \
  --quiet \
  --post-hook "sudo nginx -s reload"

echo "证书续期完成!"
date
```

## 6. 注意事项

1. 请妥善保管您的 DNS API 凭证，这些凭证可以完全控制您的 DNS 记录
2. 不同 DNS 提供商的 API 限制可能不同，请确保了解您的提供商的限制
3. 设置适当的 `--dns-*propagation-seconds` 值，以确保 DNS 记录有足够的时间传播
4. 对于阿里云、腾讯云等国内 DNS 提供商，传播时间可能需要更长

## 7. 故障排除

- 如果遇到 API 凭证错误，请检查凭证是否正确以及权限是否足够
- 如果遇到 DNS 传播问题，尝试增加传播等待时间
- 查看 Certbot 日志获取更多详细信息：`/var/log/letsencrypt/letsencrypt.log`