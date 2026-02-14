#!/bin/bash

# ==============================================================================
# Kubernetes完整安装脚本
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
POD_NETWORK_CIDR="10.244.0.0/16" # Flannel默认网段
SERVICE_CIDR="10.96.0.0/12"
APISERVER_ADVERTISE_ADDRESS=""
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
    echo -e "${COLOR_BLUE}Kubernetes安装脚本使用说明:${COLOR_RESET}"
    echo -e "  $0 [选项]"
    echo -e "\n选项:" 
    echo -e "  --version, -v      指定Kubernetes版本，默认: $K8S_VERSION"
    echo -e "  --runtime, -r      指定容器运行时(docker/containerd)，默认: $CONTAINER_RUNTIME"
    echo -e "  --pod-cidr         指定Pod网络CIDR，默认: $POD_NETWORK_CIDR"
    echo -e "  --service-cidr     指定Service网络CIDR，默认: $SERVICE_CIDR"
    echo -e "  --apiserver        指定API Server广播地址，默认使用第一个非lo网卡地址"
    echo -e "  --proxy-mode       指定kube-proxy模式(iptables/ipvs)，默认: $KUBE_PROXY_MODE"
    echo -e "  --master           仅安装Master节点"
    echo -e "  --worker           仅安装Worker节点"
    echo -e "  --log-level        指定日志级别(debug/info/error)，默认: info"
    echo -e "  --help, -h         显示帮助信息"
    echo -e "\n使用示例:"
    echo -e "  安装Master节点: $0 --master"
    echo -e "  安装Worker节点: $0 --worker"
    echo -e "  自定义版本安装: $0 --master --version=1.27.3"
}

# 解析命令行参数
parse_args() {
    INSTALL_MODE=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --version=*|-v=*) K8S_VERSION="${1#*=}"; shift ;;
            --runtime=*|-r=*) CONTAINER_RUNTIME="${1#*=}"; shift ;;
            --pod-cidr=*) POD_NETWORK_CIDR="${1#*=}"; shift ;;
            --service-cidr=*) SERVICE_CIDR="${1#*=}"; shift ;;
            --apiserver=*) APISERVER_ADVERTISE_ADDRESS="${1#*=}"; shift ;;
            --proxy-mode=*) KUBE_PROXY_MODE="${1#*=}"; shift ;;
            --master) INSTALL_MODE="master"; shift ;;
            --worker) INSTALL_MODE="worker"; shift ;;
            --log-level=*) LOG_LEVEL="${1#*=}"; shift ;;
            --help|-h) print_help; exit 0 ;;
            *) log_error "未知选项: $1"; print_help; exit 1 ;;
        esac
    done

    if [[ -z "$INSTALL_MODE" ]]; then
        log_error "必须指定安装模式(--master或--worker)"
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
    if [[ "$CPU_CORES" -lt 2 && "$INSTALL_MODE" == "master" ]]; then
        log_warn "Master节点建议至少2个CPU核心，当前只有$CPU_CORES个"
    elif [[ "$CPU_CORES" -lt 1 ]]; then
        log_error "Worker节点至少需要1个CPU核心"
        exit 1
    fi
    
    # 检查内存
    MEMORY_MB="$(free -m | grep Mem | awk '{print $2}')"
    if [[ "$MEMORY_MB" -lt 3500 && "$INSTALL_MODE" == "master" ]]; then
        log_warn "Master节点建议至少4GB内存，当前只有${MEMORY_MB}MB"
    elif [[ "$MEMORY_MB" -lt 1500 ]]; then
        log_error "Worker节点至少需要2GB内存"
        exit 1
    fi
    
    # 检查磁盘空间
    DISK_SPACE_GB="$(df -h / | tail -1 | awk '{print $4}' | sed 's/G//')"
    if (( $(echo "$DISK_SPACE_GB < 15" | bc -l) )); then
        log_warn "根目录剩余空间不足20GB，可能影响安装和运行"
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
    
    # 获取第一个非lo网卡的IP地址作为默认API Server地址
    if [[ -z "$APISERVER_ADVERTISE_ADDRESS" ]]; then
        APISERVER_ADVERTISE_ADDRESS="$(ip -o -4 addr show | grep -v lo | head -1 | awk '{print $4}' | cut -d/ -f1)"
    fi
    log_info "使用API Server广播地址: $APISERVER_ADVERTISE_ADDRESS"

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
        log_info "安装kubeadm、kubelet、kubectl..."
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
        log_info "安装kubeadm、kubelet、kubectl..."
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

# 初始化Master节点
initialize_master() {
    log_info "开始初始化Master节点..."
    
    # 初始化kubeadm
    log_info "执行kubeadm init..."
    kubeadm init \
        --kubernetes-version=v$K8S_VERSION \
        --apiserver-advertise-address=$APISERVER_ADVERTISE_ADDRESS \
        --service-cidr=$SERVICE_CIDR \
        --pod-network-cidr=$POD_NETWORK_CIDR \
        --image-repository=registry.aliyuncs.com/google_containers \
        --ignore-preflight-errors=Swap

    # 配置kubectl
    log_info "配置kubectl..."
    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config

    # 安装Flannel网络插件
    log_info "安装Flannel网络插件..."
    kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

    # 配置kube-proxy模式
    if [[ "$KUBE_PROXY_MODE" == "ipvs" ]]; then
        log_info "配置kube-proxy为IPVS模式..."
        kubectl -n kube-system patch configmap kube-proxy -p '{"data":{"config.conf":"apiVersion: kubeproxy.config.k8s.io/v1alpha1\nkind: KubeProxyConfiguration\nmode: ipvs\n"}}'
        kubectl -n kube-system rollout restart daemonset kube-proxy
    fi

    # 等待CoreDNS就绪
    log_info "等待CoreDNS就绪..."
    kubectl wait --for=condition=ready pod -l k8s-app=kube-dns -n kube-system --timeout=300s || true

    # 显示集群状态
    log_info "显示集群状态..."
    kubectl get nodes || true
    kubectl get pods -n kube-system || true

    # 生成Worker节点加入命令
    log_warn "\nWorker节点加入命令:\n"
    JOIN_COMMAND="$(kubeadm token create --print-join-command)"
    echo "$JOIN_COMMAND"

    log_success "\nMaster节点初始化完成！"
    log_success "请使用上述命令将Worker节点加入集群。"
    log_info "可以使用\`kubectl get nodes\`命令查看节点状态"
    log_info "可以使用\`kubectl get pods -n kube-system\`命令查看系统组件状态"
}

# 配置Worker节点
configure_worker() {
    log_success "Worker节点配置完成，请使用Master节点生成的join命令加入集群。"
    log_info "示例命令格式: kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash <hash>"
}

# 验证集群状态
verify_cluster_status() {
    if [[ "$INSTALL_MODE" == "master" ]]; then
        log_info "等待集群初始化完成..."
        sleep 10
        log_info "验证集群状态..."
        kubectl get nodes || true
        kubectl get pods -n kube-system || true
    fi
}

# 主函数
main() {
    echo -e "${COLOR_BLUE}==================================================${COLOR_RESET}"
    echo -e "${COLOR_BLUE}          Kubernetes安装脚本 v1.0${COLOR_RESET}"
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

    # 根据安装模式执行不同操作
    if [[ "$INSTALL_MODE" == "master" ]]; then
        initialize_master
        # 验证集群状态
        verify_cluster_status
    elif [[ "$INSTALL_MODE" == "worker" ]]; then
        configure_worker
    fi

    echo -e "${COLOR_GREEN}\n==================================================${COLOR_RESET}"
    echo -e "${COLOR_GREEN}          Kubernetes安装脚本执行完成${COLOR_RESET}"
    echo -e "${COLOR_GREEN}==================================================${COLOR_RESET}"
}

# 执行主函数
main "$@"