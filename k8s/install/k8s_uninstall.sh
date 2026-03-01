#!/bin/bash

# ==============================================================================
# Kubernetes完整卸载脚本
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
LOG_LEVEL="info"
REMOVE_ALL=false
PURGE=false

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
    echo -e "${COLOR_BLUE}Kubernetes卸载脚本使用说明:${COLOR_RESET}"
    echo -e "  $0 [选项]"
    echo -e "\n选项:" 
    echo -e "  --all          卸载所有Kubernetes组件和容器运行时"
    echo -e "  --purge        彻底清理数据（包括配置文件和存储数据）"
    echo -e "  --log-level    指定日志级别(debug/info/error)，默认: info"
    echo -e "  --help, -h     显示帮助信息"
    echo -e "\n使用示例:"
    echo -e "  卸载Kubernetes核心组件: $0"
    echo -e "  卸载所有组件和运行时: $0 --all"
    echo -e "  彻底清理所有数据: $0 --all --purge"
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all) REMOVE_ALL=true; shift ;;
            --purge) PURGE=true; shift ;;
            --log-level=*) LOG_LEVEL="${1#*=}"; shift ;;
            --help|-h) print_help; exit 0 ;;
            *) log_error "未知选项: $1"; print_help; exit 1 ;;
        esac
    done

    # 验证日志级别
    if [[ "$LOG_LEVEL" != "debug" && "$LOG_LEVEL" != "info" && "$LOG_LEVEL" != "error" ]]; then
        log_error "日志级别必须是debug、info或error"
        exit 1
    fi

    if [[ "$PURGE" == true && "$REMOVE_ALL" == false ]]; then
        log_warn "--purge选项通常与--all一起使用，单独使用可能导致不完整的清理"
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

# 停止Kubernetes服务
stop_k8s_services() {
    log_info "开始停止Kubernetes服务..."
    
    # 停止所有Pod
    log_info "停止所有运行中的Pod..."
    kubectl drain --ignore-daemonsets --force --delete-local-data $(hostname) || true
    kubectl delete all --all --all-namespaces || true

    # 停止kubelet服务
    log_info "停止kubelet服务..."
    systemctl stop kubelet || true
    systemctl disable kubelet || true

    # 停止相关服务
    log_info "停止相关服务..."
    systemctl stop kube-apiserver || true
    systemctl stop kube-controller-manager || true
    systemctl stop kube-scheduler || true
    systemctl stop etcd || true
    systemctl stop kube-proxy || true

    # 重置kubeadm
    log_info "重置kubeadm配置..."
    kubeadm reset -f || true
    rm -rf /etc/kubernetes/ || true

    log_success "Kubernetes服务停止完成"
}

# 卸载Kubernetes组件
uninstall_k8s_components() {
    log_info "开始卸载Kubernetes组件..."
    
    if [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
        # 卸载kubeadm、kubelet、kubectl
        log_info "卸载kubeadm、kubelet、kubectl..."
        yum remove -y kubeadm kubelet kubectl || true
        yum autoremove -y || true
        # 删除YUM源
        rm -f /etc/yum.repos.d/kubernetes.repo || true
        # 清除YUM缓存
        yum clean all || true
        rm -rf /var/cache/yum || true
    elif [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        # 卸载kubeadm、kubelet、kubectl
        log_info "卸载kubeadm、kubelet、kubectl..."
        apt-get purge -y kubeadm kubelet kubectl || true
        apt-get autoremove -y || true
        # 删除APT源
        rm -f /etc/apt/sources.list.d/kubernetes.list || true
        # 清除APT缓存
        apt-get clean || true
        rm -rf /var/cache/apt/archives/* || true
    fi

    log_success "Kubernetes组件卸载完成"
}

# 卸载容器运行时
uninstall_container_runtime() {
    if [[ "$REMOVE_ALL" == true ]]; then
        log_info "开始卸载容器运行时..."
        
        # 检查是否安装了Docker
        if command -v docker &> /dev/null; then
            log_info "卸载Docker..."
            if [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
                yum remove -y docker-ce docker-ce-cli containerd.io || true
            elif [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
                apt-get purge -y docker-ce docker-ce-cli containerd.io || true
            fi
            # 删除Docker数据
            if [[ "$PURGE" == true ]]; then
                log_info "清理Docker数据..."
                rm -rf /var/lib/docker /etc/docker || true
                rm -rf /run/docker.sock || true
            fi
        fi

        # 检查是否安装了Containerd
        if command -v containerd &> /dev/null && command -v docker &> /dev/null; then
            log_info "卸载Containerd..."
            if [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
                yum remove -y containerd.io || true
            elif [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
                apt-get purge -y containerd.io || true
            fi
            # 删除Containerd数据
            if [[ "$PURGE" == true ]]; then
                log_info "清理Containerd数据..."
                rm -rf /var/lib/containerd /etc/containerd || true
            fi
        fi

        log_success "容器运行时卸载完成"
    fi
}

# 清理网络配置
cleanup_network_config() {
    log_info "开始清理网络配置..."
    
    # 清除网络接口
    log_info "删除Kubernetes相关网络接口..."
    ip link delete cni0 || true
    ip link delete flannel.1 || true
    ip link delete weave || true
    ip link delete cali* || true

    # 清理iptables规则
    log_info "清理iptables规则..."
    iptables -F || true
    iptables -X || true
    iptables -Z || true
    iptables -t nat -F || true
    iptables -t nat -X || true
    iptables -t nat -Z || true
    iptables -t mangle -F || true
    iptables -t mangle -X || true
    iptables -t mangle -Z || true
    iptables -t raw -F || true
    iptables -t raw -X || true
    iptables -t raw -Z || true

    # 清理ipvs规则
    if command -v ipvsadm &> /dev/null; then
        log_info "清理ipvs规则..."
        ipvsadm -C || true
    fi

    # 保存iptables规则
    if [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
        service iptables save || true
    elif [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        iptables-save > /etc/iptables/rules.v4 || true
    fi

    log_success "网络配置清理完成"
}

# 清理系统配置和数据
cleanup_system_data() {
    log_info "开始清理系统配置和数据..."
    
    # 删除Kubernetes相关目录
    log_info "删除Kubernetes相关目录..."
    rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/kube-proxy /var/lib/cni /var/run/kubernetes /opt/cni || true
    rm -rf ~/.kube || true
    rm -f /etc/sysctl.d/k8s.conf || true
    rm -f /etc/systemd/system/kubelet.service.d/10-kubeadm.conf || true

    # 移除加载的内核模块
    log_info "移除Kubernetes相关内核模块..."
    modprobe -r br_netfilter || true
    modprobe -r ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh nf_conntrack || true

    # 如果启用了彻底清理，恢复系统配置
    if [[ "$PURGE" == true ]]; then
        log_info "恢复系统默认配置..."
        # 恢复swap设置
        sed -i '/^#.*swap/s/^#//' /etc/fstab || true
        swapon -a || true

        # 恢复SELinux设置（仅CentOS/RHEL）
        if [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
            sed -i 's/^SELINUX=disabled/SELINUX=enforcing/' /etc/selinux/config || true
            setenforce 1 || true
        fi

        # 恢复防火墙设置
        if [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
            systemctl start firewalld || true
            systemctl enable firewalld || true
        elif [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
            ufw enable || true
        fi
    fi

    # 重新加载系统配置
    log_info "重新加载系统配置..."
    sysctl --system || true

    log_success "系统配置和数据清理完成"
}

# 验证卸载是否成功
verify_uninstall() {
    log_info "验证Kubernetes卸载是否成功..."
    
    # 检查Kubernetes组件是否残留
    COMPONENTS=("kubeadm" "kubelet" "kubectl" "docker" "containerd")
   残留_COMPONENTS=()
    
    for component in "${COMPONENTS[@]}"; do
        if command -v "$component" &> /dev/null; then
            残留_COMPONENTS+=($component)
        fi
    done
    
    # 检查Kubernetes相关目录是否残留
    DIRS=("/etc/kubernetes" "/var/lib/kubelet" "/etc/docker" "/var/lib/docker")
    残留_DIRS=()
    
    for dir in "${DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            残留_DIRS+=($dir)
        fi
    done
    
    # 输出验证结果
    if [[ ${#残留_COMPONENTS[@]} -eq 0 && ${#残留_DIRS[@]} -eq 0 ]]; then
        log_success "Kubernetes卸载成功，未发现残留组件和目录"
    else
        if [[ ${#残留_COMPONENTS[@]} -gt 0 ]]; then
            log_warn "发现残留组件: ${残留_COMPONENTS[*]}"
        fi
        if [[ ${#残留_DIRS[@]} -gt 0 ]]; then
            log_warn "发现残留目录: ${残留_DIRS[*]}"
        fi
        log_info "建议手动清理残留组件和目录以确保完全卸载"
    fi
}

# 主函数
main() {
    echo -e "${COLOR_BLUE}==================================================${COLOR_RESET}"
    echo -e "${COLOR_BLUE}          Kubernetes卸载脚本 v1.0${COLOR_RESET}"
    echo -e "${COLOR_BLUE}==================================================${COLOR_RESET}"

    # 提示用户确认
    log_warn "警告: 此脚本将卸载Kubernetes及其相关组件！"
    read -p "请确认是否继续卸载操作？(y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "卸载操作已取消"
        exit 0
    fi

    # 检查是否为root用户
    if [[ $EUID -ne 0 ]]; then
        log_error "必须以root用户运行此脚本"
        exit 1
    fi

    # 解析命令行参数
    parse_args "$@"

    # 检测操作系统
    detect_os

    # 停止Kubernetes服务
    stop_k8s_services

    # 卸载Kubernetes组件
    uninstall_k8s_components

    # 卸载容器运行时
    uninstall_container_runtime

    # 清理网络配置
    cleanup_network_config

    # 清理系统配置和数据
    cleanup_system_data

    # 验证卸载是否成功
    verify_uninstall

    echo -e "${COLOR_GREEN}\n==================================================${COLOR_RESET}"
    echo -e "${COLOR_GREEN}          Kubernetes卸载脚本执行完成${COLOR_RESET}"
    echo -e "${COLOR_GREEN}==================================================${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}注意:${COLOR_RESET}"
    echo -e "  1. 如果启用了--purge选项，系统配置已恢复默认值"
    echo -e "  2. 建议重启系统以确保所有更改生效"
    echo -e "  3. 如有残留组件，请手动清理"
}

# 执行主函数
main "$@"