#!/bin/bash

# ==============================================================================
# Kubernetes Worker节点加入集群脚本
# 支持CentOS/RHEL 7/8、Ubuntu 18.04/20.04/22.04、Debian 10/11
# 作者: 技术专家
# 日期: 2025-10-10
# ==============================================================================

set -euo pipefail

export LANG=en_US.UTF-8
COLOR_RED="\033[31m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_BLUE="\033[34m"
COLOR_RESET="\033[0m"

# 默认配置
K8S_VERSION="1.28.0"
CONTAINER_RUNTIME="docker"
JOIN_COMMAND=""
KUBE_PROXY_MODE="iptables"
LOG_LEVEL="info"

# 日志函数
log_info() {
    if [[ "$LOG_LEVEL" != "error" ]]; then
        echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $1" >&2
    fi
}

log_warn() {
    if [[ "$LOG_LEVEL" != "error" ]]; then
        echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $1" >&2
    fi
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $1" >&2
}

log_success() {
    if [[ "$LOG_LEVEL" != "error" ]]; then
        echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $1" >&2
    fi
}

# 帮助信息
print_help() {
    echo -e "${COLOR_BLUE}Kubernetes Worker节点加入集群脚本使用说明:${COLOR_RESET}"
    echo -e "  $0 [选项]"
    echo -e "\n选项:" 
    echo -e "  --join-command, -j  指定从Master节点获取的加入命令（必填）"
    echo -e "  --version, -v       指定Kubernetes版本，默认: $K8S_VERSION"
    echo -e "  --runtime, -r       指定容器运行时(docker/containerd)，默认: $CONTAINER_RUNTIME"
    echo -e "  --proxy-mode        指定kube-proxy模式(iptables/ipvs)，默认: $KUBE_PROXY_MODE"
    echo -e "  --log-level         指定日志级别(debug/info/error)，默认: info"
    echo -e "  --help, -h          显示帮助信息"
    echo -e "\n使用示例:"
    echo -e "  $0 --join-command='kubeadm join 192.168.0.100:6443 --token abcdef.1234567890abcdef --discovery-token-ca-cert-hash sha256:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'"
    echo -e "  $0 --join-command='kubeadm join ...' --runtime=containerd --proxy-mode=ipvs"
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --join-command=*|-j=*) JOIN_COMMAND="${1#*=}"; shift ;;
            --version=*|-v=*) K8S_VERSION="${1#*=}"; shift ;;
            --runtime=*|-r=*) CONTAINER_RUNTIME="${1#*=}"; shift ;;
            --proxy-mode=*) KUBE_PROXY_MODE="${1#*=}"; shift ;;
            --log-level=*) LOG_LEVEL="${1#*=}"; shift ;;
            --help|-h) print_help; exit 0 ;;
            *) log_error "未知选项: $1"; print_help; exit 1 ;;
        esac
    done

    # 验证必填参数
    if [[ -z "$JOIN_COMMAND" ]]; then
        log_error "错误: 必须指定--join-command参数"
        print_help
        exit 1
    fi

    # 验证容器运行时
    if [[ "$CONTAINER_RUNTIME" != "docker" && "$CONTAINER_RUNTIME" != "containerd" ]]; then
        log_error "容器运行时必须是docker或containerd"
        exit 1
    fi

    # 验证kube-proxy模式
    if [[ "$KUBE_PROXY_MODE" != "iptables" && "$KUBE_PROXY_MODE" != "ipvs" ]]; then
        log_error "kube-proxy模式必须是iptables或ipvs"
        exit 1
    fi

    # 验证日志级别
    if [[ "$LOG_LEVEL" != "debug" && "$LOG_LEVEL" != "info" && "$LOG_LEVEL" != "error" ]]; then
        log_error "日志级别必须是debug、info或error"
        exit 1
    fi

    # 验证join命令格式
    if ! echo "$JOIN_COMMAND" | grep -q "kubeadm join"; then
        log_warn "join命令格式可能不正确，请确保它以'kubeadm join'开头"
    fi
}

# 检测操作系统类型
detect_os() {
    log_info "正在检测操作系统类型..."
    if [[ -f /etc/centos-release ]]; then
        OS="centos"
        OS_VERSION="$(cat /etc/centos-release | grep -o '[0-9]\+\.[0-9]\+' | head -1 | cut -d. -f1)"
    elif [[ -f /etc/redhat-release ]]; then
        OS="rhel"
        OS_VERSION="$(cat /etc/redhat-release | grep -o '[0-9]\+\.[0-9]\+' | head -1 | cut -d. -f1)"
    elif [[ -f /etc/ubuntu-release || -f /etc/lsb-release ]]; then
        OS="ubuntu"
        OS_VERSION="$(lsb_release -rs | cut -d. -f1)"
    elif [[ -f /etc/debian_version ]]; then
        OS="debian"
        OS_VERSION="$(cat /etc/debian_version | cut -d. -f1)"
    else
        log_error "不支持的操作系统，请使用CentOS/RHEL 7/8、Ubuntu 18.04+/Debian 10+"
        exit 1
    fi
    log_success "检测到操作系统: $OS $OS_VERSION"
}

# 检查系统要求
check_system_requirements() {
    log_info "正在检查系统要求..."
    
    # 检查CPU核心数
    CPU_CORES="$(grep -c '^processor' /proc/cpuinfo)"
    if [[ "$CPU_CORES" -lt 1 ]]; then
        log_error "Worker节点至少需要1个CPU核心"
        exit 1
    elif [[ "$CPU_CORES" -lt 2 ]]; then
        log_warn "Worker节点建议至少2个CPU核心，当前只有$CPU_CORES个"
    fi
    
    # 检查内存
    MEMORY_MB="$(free -m | grep Mem | awk '{print $2}')"
    if [[ "$MEMORY_MB" -lt 1500 ]]; then
        log_error "Worker节点至少需要2GB内存"
        exit 1
    elif [[ "$MEMORY_MB" -lt 3500 ]]; then
        log_warn "Worker节点建议至少4GB内存，当前只有${MEMORY_MB}MB"
    fi
    
    # 检查磁盘空间
    DISK_SPACE_GB="$(df -h / | tail -1 | awk '{print $4}' | sed 's/G//')"
    if (( $(echo "$DISK_SPACE_GB < 10" | bc -l) )); then
        log_warn "根目录剩余空间不足15GB，可能影响运行"
    fi
    
    log_success "系统要求检查通过"
}

# 配置系统环境
configure_system() {
    log_info "开始配置系统环境..."
    
    # 关闭防火墙
    log_info "配置防火墙..."
    if [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
        systemctl stop firewalld || true
        systemctl disable firewalld || true
        sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
        setenforce 0 || true
    elif [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        ufw disable || true
    fi

    # 关闭swap
    log_info "禁用Swap..."
    swapoff -a
    sed -i '/swap/s/^/#/' /etc/fstab

    # 配置内核参数
    log_info "配置内核参数..."
    cat > /etc/sysctl.d/k8s.conf << EOF
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
vm.swappiness = 0
EOF

    # 加载内核模块
    log_info "加载内核模块..."
    modprobe br_netfilter
    # 如果使用ipvs模式，加载ipvs相关模块
    if [[ "$KUBE_PROXY_MODE" == "ipvs" ]]; then
        modprobe ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh nf_conntrack || true
    fi
    sysctl --system || true

    # 配置时间同步
    log_info "配置时间同步..."
    if [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
        yum install -y chrony || true
        systemctl enable chronyd || true
        systemctl restart chronyd || true
    elif [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        apt-get update || true
        apt-get install -y ntpdate || true
        ntpdate time1.aliyun.com || true
        timedatectl set-timezone Asia/Shanghai || true
    fi
    log_success "系统环境配置完成"
}

# 安装Docker
install_docker() {
    log_info "开始安装Docker..."
    
    if [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
        yum install -y yum-utils device-mapper-persistent-data lvm2 || true
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || true
        yum install -y docker-ce docker-ce-cli containerd.io || true
    elif [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        apt-get update || true
        apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common || true
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - || true
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" || true
        apt-get update || true
        apt-get install -y docker-ce docker-ce-cli containerd.io || true
    fi

    # 配置Docker daemon
    log_info "配置Docker..."
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "registry-mirrors": [
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com",
    "https://docker.mirrors.ustc.edu.cn"
  ]
}
EOF

    systemctl daemon-reload || true
    systemctl enable docker || true
    systemctl start docker || true
    log_success "Docker安装完成"
}

# 安装Containerd
install_containerd() {
    log_info "开始安装Containerd..."
    
    if [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
        yum install -y containerd.io || true
    elif [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        apt-get update || true
        apt-get install -y containerd.io || true
    fi

    # 配置Containerd
    log_info "配置Containerd..."
    mkdir -p /etc/containerd
    containerd config default > /etc/containerd/config.toml || true
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml || true
    sed -i 's/registry.k8s.io/registry.aliyuncs.com\/k8sxio/g' /etc/containerd/config.toml || true

    systemctl daemon-reload || true
    systemctl enable containerd || true
    systemctl start containerd || true
    log_success "Containerd安装完成"
}

# 安装IPVS依赖包
install_ipvs_dependencies() {
    if [[ "$KUBE_PROXY_MODE" == "ipvs" ]]; then
        log_info "安装IPVS依赖包..."
        if [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
            yum install -y ipset ipvsadm || true
        elif [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
            apt-get update || true
            apt-get install -y ipset ipvsadm || true
        fi
        log_success "IPVS依赖包安装完成"
    fi
}

# 安装Kubernetes组件
install_k8s_components() {
    log_info "开始安装Kubernetes组件..."
    
    if [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
        # 配置Kubernetes YUM源
        cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
        
        # 安装kubeadm、kubelet、kubectl
        log_info "安装kubeadm、kubelet..."
        yum install -y kubelet-$K8S_VERSION kubeadm-$K8S_VERSION kubectl-$K8S_VERSION || true
        
        # 配置kubelet
        log_info "配置kubelet..."
        cat > /etc/sysconfig/kubelet << EOF
KUBELET_EXTRA_ARGS=--cgroup-driver=systemd
EOF
    elif [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        # 配置Kubernetes APT源
        log_info "配置Kubernetes源..."
        apt-get update || true
        apt-get install -y apt-transport-https ca-certificates curl || true
        curl -fsSL https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add - || true
        cat > /etc/apt/sources.list.d/kubernetes.list << EOF
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF
        
        # 安装kubeadm、kubelet、kubectl
        log_info "安装kubeadm、kubelet..."
        apt-get update || true
        apt-get install -y kubelet=$K8S_VERSION-00 kubeadm=$K8S_VERSION-00 kubectl=$K8S_VERSION-00 || true
        apt-mark hold kubelet kubeadm kubectl || true
    fi

    # 安装IPVS依赖包
    install_ipvs_dependencies

    # 启动kubelet服务
    log_info "启动kubelet服务..."
    systemctl daemon-reload || true
    systemctl enable kubelet || true
    systemctl start kubelet || true
    log_success "Kubernetes组件安装完成"
}

# 加入Kubernetes集群
join_cluster() {
    log_info "准备加入Kubernetes集群..."
    
    # 显示将要执行的join命令（隐藏敏感信息）
    HIDDEN_JOIN_COMMAND="$(echo "$JOIN_COMMAND" | sed 's/\(sha256:[a-f0-9]\{10\}\)[a-f0-9]*/\1.../g')"
    log_info "执行join命令: $HIDDEN_JOIN_COMMAND"
    
    # 执行join命令
    log_info "正在加入集群..."
    eval "$JOIN_COMMAND"
    
    # 配置kubectl（可选，但方便在Worker节点执行kubectl命令）
    log_info "配置kubectl（可选）..."
    log_info "注意: 在Worker节点使用kubectl命令需要从Master节点复制admin.conf文件"
    log_info "示例: scp root@<master-ip>:/etc/kubernetes/admin.conf ~/.kube/config"
    
    log_success "Worker节点已成功加入集群！"
}

# 验证节点状态
verify_node_status() {
    log_info "等待节点状态变为Ready..."
    sleep 10
    
    # 提示用户如何验证节点状态
    log_info "验证节点状态:"
    log_info "1. 在Master节点上执行: kubectl get nodes"
    log_info "2. 确保当前节点状态为Ready"
    log_info "3. 查看节点详细信息: kubectl describe node $(hostname)"
    
    # 如果本地有kubectl配置，可以直接查看
    if [[ -f ~/.kube/config ]]; then
        log_info "本地kubectl配置已存在，尝试查看节点状态..."
        kubectl get nodes || true
    else
        log_warn "本地没有kubectl配置文件，请在Master节点上验证节点状态"
    fi
}

# 配置kube-proxy模式
configure_kube_proxy() {
    if [[ "$KUBE_PROXY_MODE" == "ipvs" ]]; then
        log_info "提示: kube-proxy模式设置为ipvs，需要在Master节点上执行以下命令进行配置:"
        log_info "kubectl -n kube-system patch configmap kube-proxy -p '{"data":{"config.conf":"apiVersion: kubeproxy.config.k8s.io/v1alpha1\nkind: KubeProxyConfiguration\nmode: ipvs\n"}}'"
        log_info "kubectl -n kube-system rollout restart daemonset kube-proxy"
    fi
}

# 主函数
main() {
    echo -e "${COLOR_BLUE}==================================================${COLOR_RESET}"
    echo -e "${COLOR_BLUE}       Kubernetes Worker节点加入集群脚本 v1.0${COLOR_RESET}"
    echo -e "${COLOR_BLUE}==================================================${COLOR_RESET}"

    # 检查是否为root用户
    if [[ $EUID -ne 0 ]]; then
        log_error "必须以root用户运行此脚本"
        exit 1
    fi

    # 解析命令行参数
    parse_args "$@"

    # 检测操作系统
    detect_os

    # 检查系统要求
    check_system_requirements

    # 配置系统环境
    configure_system

    # 安装容器运行时
    if [[ "$CONTAINER_RUNTIME" == "docker" ]]; then
        install_docker
    elif [[ "$CONTAINER_RUNTIME" == "containerd" ]]; then
        install_containerd
    fi

    # 安装Kubernetes组件
    install_k8s_components

    # 加入Kubernetes集群
    join_cluster

    # 配置kube-proxy模式
    configure_kube_proxy

    # 验证节点状态
    verify_node_status

    echo -e "${COLOR_GREEN}\n==================================================${COLOR_RESET}"
    echo -e "${COLOR_GREEN}      Kubernetes Worker节点加入集群脚本执行完成${COLOR_RESET}"
    echo -e "${COLOR_GREEN}==================================================${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}注意:${COLOR_RESET}"
    echo -e "  1. 请在Master节点上验证Worker节点是否成功加入"
    echo -e "  2. 如果节点状态不是Ready，请检查网络连接和Pod网络插件"
    echo -e "  3. 如需在Worker节点使用kubectl命令，请从Master节点复制admin.conf文件"
}

# 执行主函数
main "$@"