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
JOIN_COMMAND=""
CONTAINER_RUNTIME="docker"
KUBE_PROXY_MODE="iptables"

# 帮助信息
print_help() {
    echo -e "${COLOR_BLUE}Kubernetes Worker节点加入集群脚本使用说明:${COLOR_RESET}"
    echo -e "  $0 [选项]"
    echo -e "\n选项:"
    echo -e "  --join-command      指定Worker节点加入命令，从Master节点获取"
    echo -e "  --runtime, -r       指定容器运行时(docker/containerd)，默认: $CONTAINER_RUNTIME"
    echo -e "  --proxy-mode        指定kube-proxy模式(iptables/ipvs)，默认: $KUBE_PROXY_MODE"
    echo -e "  --help, -h          显示帮助信息"
    echo -e "\n使用示例:"
    echo -e "  $0 --join-command='kubeadm join 192.168.1.100:6443 --token abcdef.1234567890abcdef --discovery-token-ca-cert-hash sha256:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'"
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --join-command=*) JOIN_COMMAND="${1#*=}"; shift ;;
            --runtime=*|-r=*) CONTAINER_RUNTIME="${1#*=}"; shift ;;
            --proxy-mode=*) KUBE_PROXY_MODE="${1#*=}"; shift ;;
            --help|-h) print_help; exit 0 ;;
            *) echo -e "${COLOR_RED}未知选项: $1${COLOR_RESET}"; print_help; exit 1 ;;
        esac
    done

    if [[ -z "$JOIN_COMMAND" ]]; then
        echo -e "${COLOR_RED}错误: 必须指定--join-command参数，从Master节点获取加入命令${COLOR_RESET}"
        print_help
        exit 1
    fi

    # 验证容器运行时
    if [[ "$CONTAINER_RUNTIME" != "docker" && "$CONTAINER_RUNTIME" != "containerd" ]]; then
        echo -e "${COLOR_RED}错误: 容器运行时必须是docker或containerd${COLOR_RESET}"
        exit 1
    fi

    # 验证kube-proxy模式
    if [[ "$KUBE_PROXY_MODE" != "iptables" && "$KUBE_PROXY_MODE" != "ipvs" ]]; then
        echo -e "${COLOR_RED}错误: kube-proxy模式必须是iptables或ipvs${COLOR_RESET}"
        exit 1
    fi
}

# 检测操作系统类型
detect_os() {
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
        echo -e "${COLOR_RED}不支持的操作系统，请使用CentOS/RHEL 7/8、Ubuntu 18.04+/Debian 10+${COLOR_RESET}"
        exit 1
    fi
    echo -e "${COLOR_GREEN}检测到操作系统: $OS $OS_VERSION${COLOR_RESET}"
}

# 配置系统环境
configure_system() {
    echo -e "${COLOR_BLUE}开始配置系统环境...${COLOR_RESET}"
    
    # 关闭防火墙
    if [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
        systemctl stop firewalld && systemctl disable firewalld
        sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
        setenforce 0 || true
    elif [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        ufw disable || true
    fi

    # 关闭swap
    swapoff -a
    sed -i '/swap/s/^/#/' /etc/fstab

    # 配置内核参数
    cat > /etc/sysctl.d/k8s.conf << EOF
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
vm.swappiness = 0
EOF

    # 加载内核模块
    modprobe br_netfilter
    sysctl --system

    # 配置时间同步
    if [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
        yum install -y chrony
        systemctl enable chronyd && systemctl restart chronyd
    elif [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        apt-get update && apt-get install -y ntpdate
        ntpdate time1.aliyun.com
        timedatectl set-timezone Asia/Shanghai
    fi
    echo -e "${COLOR_GREEN}系统环境配置完成${COLOR_RESET}"
}

# 安装Docker
install_docker() {
    echo -e "${COLOR_BLUE}开始安装Docker...${COLOR_RESET}"
    
    if [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
        yum install -y yum-utils device-mapper-persistent-data lvm2
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io
    elif [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        apt-get update
        apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io
    fi

    # 配置Docker daemon
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

    systemctl daemon-reload
    systemctl enable docker && systemctl start docker
    echo -e "${COLOR_GREEN}Docker安装完成${COLOR_RESET}"
}

# 安装Containerd
install_containerd() {
    echo -e "${COLOR_BLUE}开始安装Containerd...${COLOR_RESET}"
    
    if [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
        yum install -y containerd.io
    elif [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        apt-get update && apt-get install -y containerd.io
    fi

    # 配置Containerd
    mkdir -p /etc/containerd
    containerd config default > /etc/containerd/config.toml
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    sed -i 's/registry.k8s.io/registry.aliyuncs.com\/k8sxio/g' /etc/containerd/config.toml

    systemctl daemon-reload
    systemctl enable containerd && systemctl start containerd
    echo -e "${COLOR_GREEN}Containerd安装完成${COLOR_RESET}"
}

# 安装Kubernetes组件
install_k8s_components() {
    echo -e "${COLOR_BLUE}开始安装Kubernetes组件...${COLOR_RESET}"
    
    # 获取Kubernetes版本号
    K8S_VERSION="$(echo "$JOIN_COMMAND" | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "v1.28.0")"
    K8S_VERSION="${K8S_VERSION:1}"  # 去掉前面的v
    echo -e "${COLOR_YELLOW}检测到Kubernetes版本: $K8S_VERSION${COLOR_RESET}"

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
        yum install -y kubelet-$K8S_VERSION kubeadm-$K8S_VERSION kubectl-$K8S_VERSION
        
        # 配置kubelet
        cat > /etc/sysconfig/kubelet << EOF
KUBELET_EXTRA_ARGS=--cgroup-driver=systemd
EOF
    elif [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        # 配置Kubernetes APT源
        apt-get update
        apt-get install -y apt-transport-https ca-certificates curl
        curl -fsSL https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -
        cat > /etc/apt/sources.list.d/kubernetes.list << EOF
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF
        
        # 安装kubeadm、kubelet、kubectl
        apt-get update
        apt-get install -y kubelet=$K8S_VERSION-00 kubeadm=$K8S_VERSION-00 kubectl=$K8S_VERSION-00
        apt-mark hold kubelet kubeadm kubectl
    fi

    # 启动kubelet服务
    systemctl daemon-reload
    systemctl enable kubelet && systemctl start kubelet
    echo -e "${COLOR_GREEN}Kubernetes组件安装完成${COLOR_RESET}"
}

# 加入Kubernetes集群
join_k8s_cluster() {
    echo -e "${COLOR_BLUE}开始加入Kubernetes集群...${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}执行加入命令: $JOIN_COMMAND${COLOR_RESET}"
    
    # 执行加入命令
    eval "$JOIN_COMMAND"
    
    # 配置kubectl（可选）
    echo -e "${COLOR_BLUE}配置kubectl...${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}注意：Worker节点默认没有管理权限，如需配置完整权限，请从Master节点复制admin.conf文件。${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}命令示例：scp root@<master-ip>:/etc/kubernetes/admin.conf $HOME/.kube/config && chown $(id -u):$(id -g) $HOME/.kube/config${COLOR_RESET}"
    
    echo -e "${COLOR_GREEN}Worker节点加入集群完成！${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}请在Master节点上执行 'kubectl get nodes' 命令查看节点状态。${COLOR_RESET}"
}

# 主函数
main() {
    echo -e "${COLOR_BLUE}==================================================${COLOR_RESET}"
    echo -e "${COLOR_BLUE}      Kubernetes Worker节点加入集群脚本 v1.0${COLOR_RESET}"
    echo -e "${COLOR_BLUE}==================================================${COLOR_RESET}"

    # 检查是否为root用户
    if [[ $EUID -ne 0 ]]; then
        echo -e "${COLOR_RED}错误: 必须以root用户运行此脚本${COLOR_RESET}"
        exit 1
    fi

    # 解析命令行参数
    parse_args "$@"

    # 检测操作系统
    detect_os

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
    join_k8s_cluster

    echo -e "${COLOR_GREEN}\n==================================================${COLOR_RESET}"
    echo -e "${COLOR_GREEN}      Kubernetes Worker节点加入集群脚本执行完成${COLOR_RESET}"
    echo -e "${COLOR_GREEN}==================================================${COLOR_RESET}"
}

# 执行主函数
main "$@"