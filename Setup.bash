#!/bin/bash

set -euo pipefail


# 颜色输出定义（增强可读性）
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'


# 配置项
SSH_PUB_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP9ZBbCFAxUJ4O5+dEO2QWVz0viCHqd4wcR9dFHM80uE liuzibo@DESKTOP-3I1U4UB"

BASIC_PACKAGES=("fish" "wget" "vim" "git" "clash")

USER_HOME=$(eval echo ~$(logname))

FISH_CONFIG_FILE="$USER_HOME/.config/fish/config.fish"

# ===================== 通用工具函数 =====================
info() {
    echo -e "$GREEN[INFO]$NC $1"
}

warn() {
    echo -e "$YELLOW[WARN]$NC $1"
}

error() {
    echo -e "$RED[ERROR]$NC $1"
    exit 1
}


# 检查sudo权限
check_sudo() {
    if ! sudo -v >/dev/null 2>&1; then
        error "需要sudo权限执行该操作，请确保当前用户已配置sudo权限"
    fi
}

# ===================== 功能函数 =====================

# 1. 安装SSH公钥
install_ssh_key() {
    info "开始配置SSH密钥..."

    # 创建SSH目录    
    mkdir -p "$USER_HOME/.ssh" 

    # 如果不存在，则配置SSH密钥
    if  [ ! -f "$USER_HOME/.ssh/id_ed25519" ]; then
        ssh-keygen -t ed25519 -f "$USER_HOME/.ssh/id_ed25519" -N "" >/dev/null 2>&1
    fi

    # 写入公钥
    # 如果已经存在，则跳过
    if ! grep -q "$SSH_PUB_KEY" "$USER_HOME/.ssh/authorized_keys"; then
        echo "$SSH_PUB_KEY" >> "$USER_HOME/.ssh/authorized_keys"
    fi

    info "SSH密钥配置完成"
}

# 2. 安装常用软件
install_common_softwares() {
    info "开始安装常用软件..."
    
    info "更新pacman缓存..."
    sudo pacman -Syu --noconfirm >/dev/null 2>&1

    # 安装软件
    sudo pacman -S --needed --noconfirm "${BASIC_PACKAGES[@]}" >/dev/null 2>&1

    info "常用软件安装完成"
}

# 3. 设置默认Shell为fish
set_default_shell() {
    info "开始配置默认Shell..."

    # 设置默认shell
    sudo usermod -s /usr/bin/fish $(logname) >/dev/null 2>&1

    # 添加fish_greeting配置
    mkdir -p "$USER_HOME/.config/fish"
    # 如果存在，则跳过
    if [ ! -f $FISH_CONFIG_FILE ] || ! grep -q "set fish_greeting" $FISH_CONFIG_FILE; then
        echo "set fish_greeting" >> $FISH_CONFIG_FILE
    fi

    info "fish Shell配置完成"
}

# 4. 配置Git全局信息
config_git() {
    info "开始配置Git全局信息..."

    # 设置全局用户名和邮箱
    git config --global user.name "liuzibo"
    git config --global user.email "liuzibo1925@outlook.com"

    info "Git配置完成"
}

# 5. 安装并配置Clash服务
config_clash() {
    info "开始配置Clash服务..."
    
    local TEMP_FILE="/tmp/clash.service"
    local SERVICE_DIR="/etc/systemd/system/"

    cat > "$TEMP_FILE" << EOF
[Unit]
Description=clash
After=network.target

[Service]
ExecStart=/usr/bin/clash -d /home/liuzibo/.config/clash/

[Install]
WantedBy=multi-user.target
EOF
    sudo mv "$TEMP_FILE" "$SERVICE_DIR"
    sudo systemctl enable clash.service

    info "Clash服务配置完成"
}

# 6. 配置代理
config_proxy() {
    info "开始配置代理..."

    if [ ! -f $FISH_CONFIG_FILE ] || ! grep -q "function proxy" $FISH_CONFIG_FILE; then
        cat >> $FISH_CONFIG_FILE << EOF
function proxy
    set -xg ALL_PROXY http://127.0.0.1:7890
end

function noproxy
    set -e ALL_PROXY
end
EOF
    fi

    info "代理配置完成"
}

# 7. 安装并配置Miniconda
install_miniconda() {
    info "开始安装Miniconda..."

    # 定义参数
    local MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
    local INSTALL_DIR="$USER_HOME/software/miniconda"
    local TMP_DIR=$(mktemp -d)  # 创建临时目录
    # 如果已经安装，直接返回
    if [ -d "$INSTALL_DIR" ]; then
        info "Miniconda已安装，跳过安装"
        return
    fi

    # 下载安装脚本
    info "下载Miniconda安装脚本到临时目录: $TMP_DIR"
    wget -q -O "$TMP_DIR/Miniconda3-latest-Linux-x86_64.sh" "$MINICONDA_URL"

    # 赋予执行权限并安装
    chmod +x "$TMP_DIR/Miniconda3-latest-Linux-x86_64.sh"
    info "安装Miniconda到: $INSTALL_DIR"
    bash "$TMP_DIR/Miniconda3-latest-Linux-x86_64.sh" -b -p "$INSTALL_DIR"

    # 配置conda
    info "配置Conda环境..."
    $INSTALL_DIR/bin/conda init fish
    $INSTALL_DIR/bin/conda config --set auto_activate false

    # 清理临时文件
    rm -rf "$TMP_DIR"

    info "Miniconda安装配置完成"
}

# ===================== 主执行流程 =====================
main() {
    # 检查sudo权限
    check_sudo

    # 1. 安装SSH公钥
    install_ssh_key

    # 2. 安装常用软件
    install_common_softwares

    # 3. 设置默认Shell
    set_default_shell

    # 4. 配置Git全局信息
    config_git

    # 5. 安装并配置Clash服务
    config_clash


    # 6. 开始配置代理
    config_proxy


    # 7. 安装并配置Miniconda
    install_miniconda
}

main