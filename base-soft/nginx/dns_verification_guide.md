# Let's Encrypt 通配符证书 DNS TXT 记录验证指南

本文档详细说明在使用 Certbot 获取 Let's Encrypt 通配符证书时，如何正确设置 DNS TXT 记录以完成域名所有权验证。

## 一、DNS 验证原理

Let's Encrypt 要求验证域名所有权，对于通配符证书（如 `*.ai.com`），必须使用 DNS 验证方式：

1. Certbot 会生成特定的验证字符串
2. 您需要在域名的 DNS 记录中添加相应的 TXT 记录
3. Let's Encrypt 的服务器会检查这些 TXT 记录是否存在且内容正确
4. 验证成功后，才会签发证书

## 二、设置 DNS TXT 记录步骤

### 步骤 1: 运行 Certbot 并获取验证信息

当您运行 `generate_letsencrypt_cert.sh` 脚本时，Certbot 会在某个步骤暂停并显示类似以下内容的提示：

```
Please deploy a DNS TXT record under the name
_acme-challenge.ai.com with the following value:

abcdef1234567890abcdef1234567890abcdef123

Before continuing, verify the record is deployed.
(This must be set up in addition to the previous challenges; do not remove, replace, or undo the previous challenge tasks yet)
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Press Enter to Continue
```

### 步骤 2: 记录需要添加的 TXT 记录信息

从提示中记录下：
- **主机名/名称**：`_acme-challenge.ai.com`
- **记录类型**：`TXT`
- **记录值**：随机生成的长字符串（如示例中的 `abcdef1234567890abcdef1234567890abcdef123`）

### 步骤 3: 登录您的 DNS 提供商管理界面

登录您注册 `ai.com` 域名的服务商或 DNS 托管服务提供商的管理控制台。常见的 DNS 提供商包括：

- 阿里云/万网
- 腾讯云
- GoDaddy
- CloudFlare
- AWS Route 53
- DNSPod
- 华为云
- Google Domains

### 步骤 4: 添加 TXT 记录

根据您的 DNS 提供商，以下是常见提供商的具体操作步骤：

#### 阿里云/万网

1. 登录阿里云控制台，进入「域名管理」
2. 找到 `ai.com` 域名，点击「解析」
3. 点击「添加记录」
4. 填写以下信息：
   - 记录类型：选择「TXT」
   - 主机记录：填写 `_acme-challenge`（注意：不是完整的 `_acme-challenge.ai.com`）
   - 记录值：粘贴 Certbot 提供的验证字符串
   - TTL：选择默认值或 10 分钟
5. 点击「确定」保存记录

#### 腾讯云

1. 登录腾讯云控制台，进入「云解析 DNS」
2. 找到 `ai.com` 域名，点击「解析」
3. 点击「添加记录」
4. 填写以下信息：
   - 主机记录：填写 `_acme-challenge`
   - 记录类型：选择「TXT」
   - 记录值：粘贴 Certbot 提供的验证字符串
   - TTL：选择默认值或 10 分钟
5. 点击「保存」

#### CloudFlare

1. 登录 CloudFlare 控制面板，选择您的域名
2. 进入「DNS」标签页
3. 点击「添加记录」
4. 填写以下信息：
   - 类型：选择「TXT」
   - 名称：填写 `_acme-challenge`
   - 内容：粘贴 Certbot 提供的验证字符串
   - TTL：选择「Auto」
   - 代理状态：确保关闭（灰色云图标）
5. 点击「保存」

#### GoDaddy

1. 登录 GoDaddy 账户，进入「我的产品」-「域名」
2. 找到 `ai.com` 域名，点击「DNS」
3. 滚动到「记录」部分，点击「添加」
4. 选择「TXT」记录类型
5. 填写以下信息：
   - 主机：填写 `_acme-challenge`
   - TXT 值：粘贴 Certbot 提供的验证字符串
   - TTL：选择默认值或 600 秒
6. 点击「保存」

## 三、验证 TXT 记录是否生效

DNS 记录更新可能需要一些时间（通常几分钟到几小时不等）。在按 Enter 继续 Certbot 之前，请验证记录是否已生效：

### 使用命令行验证（Linux/Mac）

打开新的终端窗口，运行以下命令：

```bash
dig -t txt _acme-challenge.ai.com
```

或者使用 nslookup：

```bash
nslookup -type=TXT _acme-challenge.ai.com
```

如果记录已生效，您应该能看到与您添加的 TXT 值完全匹配的结果。

### 使用在线工具验证

您也可以使用在线 DNS 查询工具：
- [DNS Checker](https://dnschecker.org)
- [MXToolbox](https://mxtoolbox.com/TXTLookup.aspx)
- [WhatsMyDNS](https://www.whatsmydns.net/)

在这些工具中，选择 TXT 记录类型，输入 `_acme-challenge.ai.com` 进行查询。

## 四、特殊情况处理

### 1. 需要验证多个域名

对于同时验证主域名 (`ai.com`) 和通配符域名 (`*.ai.com`)，Certbot 通常会要求添加两条不同的 TXT 记录：

- 第一条用于验证 `ai.com`：通常是 `_acme-challenge.ai.com`
- 第二条用于验证 `*.ai.com`：也是 `_acme-challenge.ai.com`，但值不同

**重要提示**：不要删除第一条记录，而是添加第二条记录。DNS 支持在同一主机名下有多个 TXT 记录。

### 2. DNS 传播延迟

如果您已添加 TXT 记录，但 Certbot 验证失败，请：

1. 等待更长时间让 DNS 记录传播（有时需要 10-30 分钟）
2. 清除本地 DNS 缓存
3. 再次运行 `dig` 或 `nslookup` 确认记录已生效
4. 如果记录确实已生效但验证失败，尝试重新运行脚本

### 3. 通配符证书的特殊注意事项

- 通配符证书 (`*.ai.com`) 仅匹配一级子域名，如 `nexus.ai.com`、`file.ai.com`
- 不匹配二级子域名，如 `test.nexus.ai.com`（如果需要，需要单独申请或使用更高级的通配符）

## 五、完成验证

一旦您确认 TXT 记录已正确添加并生效：

1. 返回 Certbot 命令窗口
2. 按下 Enter 键继续验证过程
3. 如果验证成功，Certbot 将继续并生成证书

## 六、验证完成后的操作

- **保留记录至少 24 小时**：虽然 Let's Encrypt 通常在验证后不需要保留 TXT 记录，但为确保证书签发过程顺利完成，建议至少保留 24 小时
- **证书续期**：当证书需要续期时，您可能需要再次执行类似的 DNS 验证过程（除非使用 DNS 插件自动完成）

## 七、自动化验证（推荐）

为了避免每次续期都需要手动添加 TXT 记录，建议配置 DNS 插件实现自动验证：

1. **CloudFlare 用户**：使用 `python3-certbot-dns-cloudflare` 插件
2. **AWS Route 53 用户**：使用 `python3-certbot-dns-route53` 插件
3. **腾讯云用户**：使用 `certbot-dns-tencentcloud` 插件
4. **阿里云用户**：使用 `certbot-dns-aliyun` 插件

使用这些插件需要配置相应的 API 密钥，详细配置方法请参考各插件的官方文档。

## 八、常见问题解答

### Q: 我需要为每个子域名单独添加 TXT 记录吗？

A: 不需要。通配符证书验证只需为 `ai.com` 和 `*.ai.com` 添加 TXT 记录，验证成功后，证书将对所有一级子域名生效。

### Q: TXT 记录可以有多长？

A: 大多数 DNS 提供商支持长度不超过 255 个字符的 TXT 记录。如果验证字符串超过这个长度，DNS 提供商会自动将其分割为多条记录。

### Q: 验证失败怎么办？

A: 检查以下几点：
- TXT 记录值是否完全匹配（区分大小写）
- 主机名是否正确设置为 `_acme-challenge`
- DNS 记录是否已传播（可使用多个 DNS 查询工具检查）
- 网络是否存在防火墙或代理阻止验证请求

### Q: 证书续期时需要再次添加 TXT 记录吗？

A: 是的，除非您使用了 DNS 插件实现自动验证。默认情况下，证书有效期为 90 天，续期时需要再次完成验证。