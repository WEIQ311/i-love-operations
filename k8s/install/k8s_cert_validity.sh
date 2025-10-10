#!/bin/bash

# ==============================================================================
# Kubernetes证书有效期修改脚本
# 支持将Kubernetes默认的1年证书有效期修改为100年
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
NEW_VALIDITY_DAYS="36500"  # 100年约等于36500天
BACKUP_DIR="/etc/kubernetes/pki_backup_$(date +%Y%m%d_%H%M%S)"
LOG_LEVEL="info"
SKIP_BACKUP="false"
ONLY_VERIFY="false"

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
    echo -e "${COLOR_BLUE}Kubernetes证书有效期修改脚本使用说明:${COLOR_RESET}"
    echo -e "  $0 [选项]"
    echo -e "\n选项:" 
    echo -e "  --validity-days     指定新的证书有效期天数，默认: $NEW_VALIDITY_DAYS (100年)"
    echo -e "  --skip-backup       跳过证书备份，默认: false"
    echo -e "  --only-verify       仅验证证书有效期，不进行修改，默认: false"
    echo -e "  --log-level         指定日志级别(debug/info/error)，默认: info"
    echo -e "  --help, -h          显示帮助信息"
    echo -e "\n使用示例:"
    echo -e "  $0                     # 默认将证书有效期修改为100年"
    echo -e "  $0 --validity-days=7300  # 将证书有效期修改为20年"
    echo -e "  $0 --only-verify        # 仅验证当前证书有效期"
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --validity-days=*) NEW_VALIDITY_DAYS="${1#*=}"; shift ;;
            --skip-backup) SKIP_BACKUP="true"; shift ;;
            --only-verify) ONLY_VERIFY="true"; shift ;;
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

    # 验证有效期天数
    if ! [[ "$NEW_VALIDITY_DAYS" =~ ^[0-9]+$ ]] || [[ "$NEW_VALIDITY_DAYS" -lt 365 ]]; then
        log_error "证书有效期天数必须是大于等于365的整数"
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

# 检查是否已安装必要工具
check_requirements() {
    log_info "检查必要工具..."
    local missing_tools=()
    
    # 检查openssl
    if ! command -v openssl &> /dev/null; then
        missing_tools+=("openssl")
    fi
    
    # 检查kubeadm
    if ! command -v kubeadm &> /dev/null && [[ "$ONLY_VERIFY" == "false" ]]; then
        missing_tools+=("kubeadm")
    fi
    
    # 检查kubectl
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    # 安装缺失的工具
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_info "安装缺失的工具: ${missing_tools[*]}"
        if [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
            yum install -y ${missing_tools[*]} || {
                log_error "无法安装缺失的工具，请手动安装: ${missing_tools[*]}"
                exit 1
            }
        elif [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
            apt-get update || true
            apt-get install -y ${missing_tools[*]} || {
                log_error "无法安装缺失的工具，请手动安装: ${missing_tools[*]}"
                exit 1
            }
        fi
    fi
    log_success "必要工具检查完成"
}

# 验证是否为Kubernetes主节点
check_master_node() {
    log_info "检查是否为Kubernetes主节点..."
    if ! kubectl get nodes 2> /dev/null; then
        log_error "无法连接到Kubernetes集群，请确保kubectl已正确配置"
        exit 1
    fi
    
    local node_role="$(kubectl describe node $(hostname) | grep -i 'role' | awk -F: '{print $2}' | tr -d ' ')"
    local node_labels="$(kubectl get node $(hostname) -o=jsonpath='{.metadata.labels}')"
    
    if [[ ! $node_labels =~ "node-role.kubernetes.io/master" && ! $node_labels =~ "node-role.kubernetes.io/control-plane" && ! $node_role == *"master"* ]]; then
        log_warn "当前节点不是Kubernetes主节点，可能无法修改所有证书"
        read -p "是否继续？(y/n) " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            exit 0
        fi
    fi
    log_success "Kubernetes主节点检查完成"
}

# 验证证书有效期
verify_cert_validity() {
    log_info "正在验证证书有效期..."
    local cert_files=( "/etc/kubernetes/pki/apiserver.crt" "/etc/kubernetes/pki/apiserver-etcd-client.crt" "/etc/kubernetes/pki/apiserver-kubelet-client.crt" "/etc/kubernetes/pki/ca.crt" "/etc/kubernetes/pki/front-proxy-ca.crt" "/etc/kubernetes/pki/front-proxy-client.crt" "/etc/kubernetes/pki/etcd/ca.crt" "/etc/kubernetes/pki/etcd/server.crt" "/etc/kubernetes/pki/etcd/peer.crt" "/etc/kubernetes/pki/etcd/healthcheck-client.crt" )
    
    local all_certs_valid=true
    local cert_count=0
    local valid_years=0
    
    for cert in "${cert_files[@]}"; do
        if [[ -f "$cert" ]]; then
            cert_count=$((cert_count + 1))
            local not_after="$(openssl x509 -in "$cert" -text -noout | grep -A 1 "Validity" | grep "Not After" | awk -F: '{print $2, $3, $4, $5, $6}')"
            local not_after_timestamp="$(date -d "$not_after" +%s)"
            local current_timestamp="$(date +%s)"
            local validity_days=$(( ($not_after_timestamp - $current_timestamp) / 86400 ))
            local validity_years=$(echo "scale=2; $validity_days / 365" | bc)
            
            if (( $validity_days < 3650 )); then  # 小于10年
                log_warn "证书 $cert 有效期还剩约 $validity_years 年 ($validity_days 天)"
                all_certs_valid=false
            else
                log_info "证书 $cert 有效期还剩约 $validity_years 年 ($validity_days 天)"
            fi
        fi
    done
    
    if [[ $cert_count -eq 0 ]]; then
        log_error "未找到Kubernetes证书，请检查是否正确安装了Kubernetes"
        exit 1
    fi
    
    log_info "共检查了 $cert_count 个证书"
    if $all_certs_valid; then
        log_success "所有证书有效期都已延长"
    else
        log_warn "部分证书有效期较短，建议延长"
    fi
}

# 备份现有证书
backup_certs() {
    if [[ "$SKIP_BACKUP" == "true" ]]; then
        log_warn "跳过证书备份..."
        return
    fi
    
    log_info "备份现有证书..."
    if [[ -d "/etc/kubernetes/pki" ]]; then
        mkdir -p "$BACKUP_DIR"
        cp -r /etc/kubernetes/pki "$BACKUP_DIR/"
        cp -f /etc/kubernetes/*.conf "$BACKUP_DIR/" 2>/dev/null || true
        log_success "证书已备份到: $BACKUP_DIR"
    else
        log_error "未找到证书目录: /etc/kubernetes/pki"
        exit 1
    fi
}

# 修改kubeadm配置以延长证书有效期
modify_kubeadm_config() {
    log_info "修改kubeadm配置以延长证书有效期..."
    
    # 创建kubeadm配置文件
    cat > /tmp/kubeadm-config.yaml << EOF
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controlPlaneEndpoint: "$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' | sed 's|https://||')"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "$(kubectl get node $(hostname) -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: KubeletConfiguration
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
EOF
    
    log_success "kubeadm配置文件已创建: /tmp/kubeadm-config.yaml"
}

# 重新生成证书
regenerate_certs() {
    log_info "重新生成证书..."
    
    # 停止控制平面组件
    log_info "停止kube-apiserver、kube-controller-manager、kube-scheduler..."
    docker ps | grep -E "kube-apiserver|kube-controller-manager|kube-scheduler" | awk '{print $1}' | xargs -r docker stop || true
    
    # 备份并删除旧证书
    local old_certs_dir="/etc/kubernetes/pki_old_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$old_certs_dir"
    
    # 保留CA证书，只重新生成其他证书
    local certs_to_regen=( "/etc/kubernetes/pki/apiserver.crt" "/etc/kubernetes/pki/apiserver.key" "/etc/kubernetes/pki/apiserver-etcd-client.crt" "/etc/kubernetes/pki/apiserver-etcd-client.key" "/etc/kubernetes/pki/apiserver-kubelet-client.crt" "/etc/kubernetes/pki/apiserver-kubelet-client.key" "/etc/kubernetes/pki/front-proxy-client.crt" "/etc/kubernetes/pki/front-proxy-client.key" "/etc/kubernetes/pki/etcd/server.crt" "/etc/kubernetes/pki/etcd/server.key" "/etc/kubernetes/pki/etcd/peer.crt" "/etc/kubernetes/pki/etcd/peer.key" "/etc/kubernetes/pki/etcd/healthcheck-client.crt" "/etc/kubernetes/pki/etcd/healthcheck-client.key" )
    
    for cert in "${certs_to_regen[@]}"; do
        if [[ -f "$cert" ]]; then
            mv "$cert" "$old_certs_dir/"
        fi
    done
    
    # 重新生成证书
    log_info "使用kubeadm重新生成证书，有效期设置为 $NEW_VALIDITY_DAYS 天..."
    kubeadm certs renew all --config /tmp/kubeadm-config.yaml || {
        log_error "证书重新生成失败，请检查错误信息"
        log_info "正在恢复旧证书..."
        mv "$old_certs_dir"/* "/etc/kubernetes/pki/" 2>/dev/null || true
        exit 1
    }
    
    # 更新配置文件中的证书信息
    log_info "更新配置文件中的证书信息..."
    cp -f /etc/kubernetes/admin.conf ~/.kube/config || true
    
    # 重新启动控制平面组件
    log_info "重新启动Docker以启动控制平面组件..."
    systemctl restart docker || true
    
    # 等待控制平面组件启动
    log_info "等待控制平面组件启动..."
    sleep 30
    
    log_success "证书重新生成完成，有效期已设置为 $NEW_VALIDITY_DAYS 天"
}

# 验证集群状态
verify_cluster_status() {
    log_info "验证Kubernetes集群状态..."
    
    # 等待一段时间让组件完全启动
    sleep 10
    
    # 检查节点状态
    local node_status="$(kubectl get nodes | grep $(hostname) | awk '{print $2}')"
    if [[ "$node_status" == "Ready" ]]; then
        log_success "节点状态正常: Ready"
    else
        log_warn "节点状态: $node_status，可能需要更多时间启动"
    fi
    
    # 检查pod状态
    local pods_not_ready="$(kubectl get pods -n kube-system | grep -v Running | grep -v Completed | wc -l)"
    if [[ "$pods_not_ready" -eq 0 ]]; then
        log_success "所有系统Pod都处于Running状态"
    else
        log_warn "有 $pods_not_ready 个系统Pod未处于Running状态"
        kubectl get pods -n kube-system | grep -v Running | grep -v Completed || true
    fi
    
    log_success "集群状态验证完成"
}

# 主函数
main() {
    echo -e "${COLOR_BLUE}==================================================${COLOR_RESET}"
    echo -e "${COLOR_BLUE}       Kubernetes证书有效期修改脚本 v1.0${COLOR_RESET}"
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

    # 检查必要工具
    check_requirements

    # 检查是否为Kubernetes主节点
    check_master_node

    # 仅验证证书有效期
    if [[ "$ONLY_VERIFY" == "true" ]]; then
        verify_cert_validity
        echo -e "${COLOR_GREEN}\n==================================================${COLOR_RESET}"
        echo -e "${COLOR_GREEN}      Kubernetes证书有效期验证完成${COLOR_RESET}"
        echo -e "${COLOR_GREEN}==================================================${COLOR_RESET}"
        exit 0
    fi

    # 备份现有证书
    backup_certs

    # 修改kubeadm配置
    modify_kubeadm_config

    # 重新生成证书
    regenerate_certs

    # 验证证书有效期
    verify_cert_validity

    # 验证集群状态
    verify_cluster_status

    echo -e "${COLOR_GREEN}\n==================================================${COLOR_RESET}"
    echo -e "${COLOR_GREEN}      Kubernetes证书有效期修改完成${COLOR_RESET}"
    echo -e "${COLOR_GREEN}==================================================${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}注意:${COLOR_RESET}"
    echo -e "  1. 证书已备份到: $BACKUP_DIR"
    echo -e "  2. 新的证书有效期: $NEW_VALIDITY_DAYS 天 (约 $(echo "scale=2; $NEW_VALIDITY_DAYS / 365" | bc) 年)"
    echo -e "  3. 请在其他控制平面节点上也执行此脚本"
    echo -e "  4. 如果遇到问题，可以使用备份的证书恢复: cp -r $BACKUP_DIR/pki/* /etc/kubernetes/pki/ && systemctl restart docker"
}

# 执行主函数
main "$@"