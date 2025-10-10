#!/bin/bash

# ==============================================================================
# Kubernetes卸载脚本
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

# 帮助信息
print_help() {
    echo -e "${COLOR_BLUE}Kubernetes卸载脚本使用说明:${COLOR_RESET}"
    echo -e "  $0 [选项]"
    echo -e "\n选项:"
    echo -e "  --all, -a      卸载所有组件(包括容器运行时)"
    echo -e "  --purge, -p    彻底清理所有相关数据"
    echo -e "  --help, -h     显示帮助信息"
}

# 解析命令行参数
parse_args() {
    UNINSTALL_ALL=false
    PURGE_DATA=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all|-a) UNINSTALL_ALL=true; shift ;;
            --purge|-p) PURGE_DATA=true; shift ;;
            --help|-h) print_help; exit 0 ;;
            *) echo -e "${COLOR_RED}未知选项: $1${COLOR_RESET}"; print_help; exit 1 ;;
        esac
    done
}

# 检测操作系统类型
detect_os() {
    if [[ -f /etc/centos-release ]]; then
        OS="centos"
    elif [[ -f /etc/redhat-release ]]; then
        OS="rhel"
    elif [[ -f /etc/ubuntu-release || -f /etc/lsb-release ]]; then
        OS="ubuntu"
    elif [[ -f /etc/debian_version ]]; then
        OS="debian"
    else
        echo -e "${COLOR_RED}不支持的操作系统，请使用CentOS/RHEL 7/8、Ubuntu 18.04+/Debian 10+${COLOR_RESET}"
        exit 1
    fi
    echo -e "${COLOR_GREEN}检测到操作系统: $OS${COLOR_RESET}"
}

# 停止Kubernetes服务
stop_k8s_services() {
    echo -e "${COLOR_BLUE}停止Kubernetes服务...${COLOR_RESET}"
    systemctl stop kubelet || true
    systemctl disable kubelet || true
    
    # 停止所有容器
    echo -e "${COLOR_BLUE}停止所有容器...${COLOR_RESET}"
    if command -v docker &> /dev/null; then
        docker stop $(docker ps -aq) || true
        docker rm $(docker ps -aq) || true
    fi
    
    if command -v crictl &> /dev/null; then
        crictl stop $(crictl ps -aq) || true
        crictl rm $(crictl ps -aq) || true
    fi
}

# 卸载Kubernetes组件
uninstall_k8s_components() {
    echo -e "${COLOR_BLUE}卸载Kubernetes组件...${COLOR_RESET}"
    
    if [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
        yum remove -y kubelet kubeadm kubectl
        rm -f /etc/yum.repos.d/kubernetes.repo
    elif [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        apt-get purge -y kubelet kubeadm kubectl
        rm -f /etc/apt/sources.list.d/kubernetes.list
        apt-get autoremove -y
    fi
    
    # 清理Kubernetes配置文件
    echo -e "${COLOR_BLUE}清理Kubernetes配置文件...${COLOR_RESET}"
    rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/cni /var/run/kubernetes
    rm -rf $HOME/.kube
    rm -f /etc/sysconfig/kubelet
}

# 卸载容器运行时
uninstall_container_runtime() {
    if [[ "$UNINSTALL_ALL" == "false" ]]; then
        echo -e "${COLOR_YELLOW}跳过容器运行时卸载...${COLOR_RESET}"
        return
    fi
    
    echo -e "${COLOR_BLUE}卸载容器运行时...${COLOR_RESET}"
    
    if command -v docker &> /dev/null; then
        echo -e "${COLOR_BLUE}卸载Docker...${COLOR_RESET}"
        systemctl stop docker || true
        systemctl disable docker || true
        
        if [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
            yum remove -y docker-ce docker-ce-cli containerd.io
            rm -f /etc/yum.repos.d/docker-ce.repo
        elif [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
            apt-get purge -y docker-ce docker-ce-cli containerd.io
            apt-get autoremove -y
        fi
    elif command -v containerd &> /dev/null; then
        echo -e "${COLOR_BLUE}卸载Containerd...${COLOR_RESET}"
        systemctl stop containerd || true
        systemctl disable containerd || true
        
        if [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
            yum remove -y containerd.io
        elif [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
            apt-get purge -y containerd.io
            apt-get autoremove -y
        fi
    fi
    
    # 清理容器运行时数据
    rm -rf /var/lib/docker /var/lib/containerd /etc/docker
}

# 清理网络配置
clean_network_config() {
    echo -e "${COLOR_BLUE}清理网络配置...${COLOR_RESET}"
    
    # 清理网络接口
    for i in $(ip -o link show | grep -E 'cni|flannel' | awk '{print $2}' | sed 's/://'); do
        ip link delete $i || true
    done
    
    # 清理iptables规则
    iptables -F || true
    iptables -X || true
    iptables -t nat -F || true
    iptables -t nat -X || true
    iptables -t mangle -F || true
    iptables -t mangle -X || true
    iptables -t raw -F || true
    iptables -t raw -X || true
    
    # 清理ipvs规则
    if command -v ipvsadm &> /dev/null; then
        ipvsadm -C || true
    fi
    
    # 移除Kubernetes相关的内核模块
    rmmod ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh nf_conntrack_ipv4 nf_conntrack cni bridge br_netfilter || true
}

# 清理系统配置
clean_system_config() {
    if [[ "$PURGE_DATA" == "false" ]]; then
        echo -e "${COLOR_YELLOW}跳过系统配置清理...${COLOR_RESET}"
        return
    fi
    
    echo -e "${COLOR_BLUE}清理系统配置...${COLOR_RESET}"
    
    # 恢复swap
    sed -i '/#.*swap/s/^#//' /etc/fstab || true
    swapon -a || true
    
    # 移除Kubernetes相关的sysctl配置
    rm -f /etc/sysctl.d/k8s.conf || true
    
    # 重启sysctl
    sysctl --system || true
}

# 主函数
main() {
    echo -e "${COLOR_BLUE}==================================================${COLOR_RESET}"
    echo -e "${COLOR_BLUE}          Kubernetes卸载脚本 v1.0${COLOR_RESET}"
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
    
    # 停止Kubernetes服务
    stop_k8s_services
    
    # 卸载Kubernetes组件
    uninstall_k8s_components
    
    # 卸载容器运行时
    uninstall_container_runtime
    
    # 清理网络配置
    clean_network_config
    
    # 清理系统配置
    clean_system_config
    
    echo -e "${COLOR_GREEN}\n==================================================${COLOR_RESET}"
    echo -e "${COLOR_GREEN}          Kubernetes卸载脚本执行完成${COLOR_RESET}"
    echo -e "${COLOR_GREEN}==================================================${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}注意: 系统可能需要重启以完全清理所有组件。${COLOR_RESET}"
}

# 执行主函数
main "$@"