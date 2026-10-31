# Kubernetes 安装脚本集

本脚本集提供了完整的 Kubernetes 集群安装、配置和管理工具，支持多种 Linux 发行版，并包含详细的使用指南。

## 脚本列表

| 脚本名称 | 功能描述 |
|---------|---------|
| `k8s_install.sh` | Kubernetes 集群安装脚本，支持 Master 节点和 Worker 节点安装 |
| `k8s_uninstall.sh` | Kubernetes 集群卸载脚本，可清理所有相关组件和数据 |
| `k8s_worker_join.sh` | Worker 节点专用加入集群脚本，简化节点扩展流程 |
| `k8s_cert_validity.sh` | Kubernetes 证书有效期修改脚本，支持将默认1年证书有效期延长至100年 |

## 系统要求

- **操作系统**：CentOS/RHEL 7/8、Ubuntu 18.04/20.04/22.04、Debian 10/11
- **硬件配置**：
  - Master 节点：至少 2 CPU、4GB 内存、20GB 磁盘空间
  - Worker 节点：至少 1 CPU、2GB 内存、20GB 磁盘空间
- **网络要求**：所有节点之间网络互通，推荐使用千兆网络
- **用户权限**：必须以 root 用户身份运行脚本

## 脚本功能特点

### k8s_install.sh 特点
- 自动检测操作系统类型和版本
- 支持 Docker 或 Containerd 作为容器运行时
- 可自定义 Kubernetes 版本（默认 1.28.0）
- 支持配置 Pod 网络 CIDR 和 Service CIDR
- 自动配置系统环境（关闭防火墙、禁用 swap、配置内核参数等）
- 集成国内镜像源，加速下载
- 自动安装 Flannel 网络插件
- 支持 Master 节点初始化和 Worker 节点配置

### k8s_uninstall.sh 特点
- 完全卸载 Kubernetes 所有组件
- 可选卸载容器运行时
- 清理网络配置和 iptables 规则
- 可选择彻底清理所有相关数据
- 恢复系统默认配置

### k8s_worker_join.sh 特点
- 专用 Worker 节点加入集群脚本
- 自动识别并安装匹配的 Kubernetes 版本
- 支持从 Master 节点获取的加入命令
- 简化 Worker 节点配置流程

### k8s_cert_validity.sh 特点
- 将 Kubernetes 默认的1年证书有效期修改为自定义天数（默认为100年/36500天）
- 支持证书有效期验证功能，无需修改即可查看当前证书状态
- 自动备份现有证书，确保安全可回滚
- 重新生成控制平面所有证书
- 保留 CA 证书，避免影响整个集群证书体系
- 提供详细的证书有效期信息和操作日志
- 支持多系统（CentOS/RHEL、Ubuntu、Debian）
- 提供跳过备份选项（不推荐在生产环境使用）

## 使用方法

### 1. 安装 Master 节点

```bash
# 使用默认配置安装 Master 节点
./k8s_install.sh --master

# 自定义 Kubernetes 版本安装
./k8s_install.sh --master --version=1.27.3

# 指定使用 containerd 作为容器运行时
./k8s_install.sh --master --runtime=containerd

# 自定义网络配置
./k8s_install.sh --master --pod-cidr=10.244.0.0/16 --service-cidr=10.96.0.0/12
```

安装完成后，脚本会输出 Worker 节点加入集群的命令，类似于：
```
kubeadm join 192.168.1.100:6443 --token abcdef.1234567890abcdef --discovery-token-ca-cert-hash sha256:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
```

### 2. 使用专用脚本添加 Worker 节点

```bash
# 使用从 Master 节点获取的加入命令
./k8s_worker_join.sh --join-command='kubeadm join 192.168.1.100:6443 --token abcdef.1234567890abcdef --discovery-token-ca-cert-hash sha256:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'

# 指定使用 containerd 作为容器运行时
./k8s_worker_join.sh --join-command='...' --runtime=containerd
```

### 3. 使用通用脚本添加 Worker 节点

```bash
# 使用通用安装脚本配置 Worker 节点
./k8s_install.sh --worker

# 然后手动执行从 Master 节点获取的加入命令
kubeadm join 192.168.1.100:6443 --token abcdef.1234567890abcdef --discovery-token-ca-cert-hash sha256:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
```

### 4. 卸载 Kubernetes 集群

```bash
# 仅卸载 Kubernetes 组件，保留容器运行时
./k8s_uninstall.sh

# 卸载所有组件（包括容器运行时）
./k8s_uninstall.sh --all

# 卸载并彻底清理所有数据
./k8s_uninstall.sh --purge
```

### 5. 修改证书有效期

```bash
# 默认将证书有效期修改为100年
./k8s_cert_validity.sh

# 仅验证当前证书有效期，不进行修改
./k8s_cert_validity.sh --only-verify

# 自定义证书有效期为20年（7300天）
./k8s_cert_validity.sh --validity-days=7300

# 跳过证书备份（不推荐）
./k8s_cert_validity.sh --skip-backup
```
# 完全卸载并清理所有内容
./k8s_uninstall.sh --all --purge
```

## 验证安装

在 Master 节点上执行以下命令验证集群状态：

```bash
# 查看节点状态
kubectl get nodes

# 查看 Pod 状态
kubectl get pods -n kube-system

# 查看集群信息
kubectl cluster-info
```

## 注意事项

1. **网络要求**：确保所有节点之间网络连通，特别是 Master 节点的 6443 端口（API Server）必须可访问
2. **防火墙配置**：脚本会自动关闭防火墙，生产环境中请根据需求配置适当的防火墙规则
3. **Swap 禁用**：Kubernetes 要求禁用 Swap，脚本会自动禁用系统 Swap
4. **内核参数**：脚本会配置必要的内核参数，可能需要系统重启以确保参数生效
5. **镜像源**：脚本使用国内镜像源加速下载，确保节点可以访问这些镜像源
6. **权限问题**：Worker 节点默认没有完整的集群管理权限，如需配置完整权限，请从 Master 节点复制 admin.conf 文件
7. **卸载警告**：卸载脚本会删除所有 Kubernetes 相关数据，请谨慎使用

## 常见问题解答

### 1. 安装过程中下载镜像失败怎么办？

检查网络连接和镜像源访问权限，确保节点可以访问 `registry.aliyuncs.com/google_containers` 等镜像源。

### 2. 如何获取新的 Worker 节点加入命令？

在 Master 节点上执行：
```bash
kubeadm token create --print-join-command
```

### 3. 节点加入集群后状态为 NotReady 怎么办？

检查网络插件是否正常安装，执行：
```bash
kubectl get pods -n kube-system
```
查看网络插件（如 flannel）的 Pod 是否正常运行。

### 4. 如何修改 Kubernetes 默认参数？

可以通过脚本提供的命令行参数进行自定义，如 `--version`、`--pod-cidr` 等。

### 5. 卸载后如何完全清理系统环境？

使用 `--all --purge` 参数运行卸载脚本，然后重启系统：
```bash
./k8s_uninstall.sh --all --purge
reboot
```

## 版本历史

- **v1.1** (2025-10-10): 添加了证书有效期修改脚本，优化了现有脚本的日志系统和错误处理
- **v1.0** (2025-10-10): 初始版本，支持 CentOS/RHEL、Ubuntu、Debian 系统，提供完整的 Kubernetes 安装、配置和卸载功能