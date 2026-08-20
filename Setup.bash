#!/bin/bash

set -euo pipefail


# 颜色输出定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'


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


# 配置项
SSH_PUB_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGCKAlmyiZFcRjJ9iYWVL4C0MOPEHMiUOCrbn04ugdsN liuzibo@DESKTOP-STCR04C"

BASIC_PACKAGES=("wget" "vim" "screen" "tree" "less" "man" "zip" "unzip" "fastfetch" "htop")


# 定义路径常量
USER_HOME=$(eval echo ~$(logname))

FISH_CONFIG_FILE="$USER_HOME/.config/fish/config.fish"

SSH_CONFIG_FILE="$USER_HOME/.ssh/authorized_keys"

OPENCODE_CONFIG_FILE="$USER_HOME/.config/opencode/opencode.json"

FRPC_CONFIG_FILE="$USER_HOME/software/frpc/frpc.toml"



# 检查sudo权限
check_sudo() {
    if ! sudo -v >/dev/null 2>&1; then
        error "No sudo permission"
    fi
}
check_sudo


install_ssh_key() {

    # 创建SSH目录
    mkdir -p "$USER_HOME/.ssh" 

    # 如果不存在，则配置SSH密钥
    if  [ ! -f "$USER_HOME/.ssh/id_ed25519" ]; then
        ssh-keygen -t ed25519 -f "$USER_HOME/.ssh/id_ed25519" -N "" >/dev/null 2>&1
    fi

    # 写入公钥
    # 如果已经存在，则跳过
    if [ ! -f $SSH_CONFIG_FILE ] || ! grep -q "$SSH_PUB_KEY" $SSH_CONFIG_FILE; then
        echo "$SSH_PUB_KEY" >> $SSH_CONFIG_FILE
    fi
}
info "1. Install SSH key"
install_ssh_key


install_common_softwares() {

    mkdir -p "$USER_HOME/software"
    mkdir -p "$USER_HOME/code"
    mkdir -p "$USER_HOME/code/go"

    sudo pacman -Syu --noconfirm >/dev/null 2>&1

    # 安装软件
    sudo pacman -S --needed --noconfirm "${BASIC_PACKAGES[@]}" >/dev/null 2>&1
}
info "2. Install common softwares"
install_common_softwares


install_fish() {
    if [ -f $FISH_CONFIG_FILE ]; then
        info "3. Fish已安装, 跳过安装"
        return
    fi

    # 安装Fish
    sudo pacman -S --needed --noconfirm fish >/dev/null 2>&1

    # 设置默认shell
    sudo usermod -s /usr/bin/fish $(logname) >/dev/null 2>&1

    # 添加fish_greeting配置
    mkdir -p "$USER_HOME/.config/fish"
    # 如果存在，则跳过
    if [ ! -f $FISH_CONFIG_FILE ] || ! grep -q "set fish_greeting" $FISH_CONFIG_FILE; then
        echo "set fish_greeting" >> $FISH_CONFIG_FILE
    fi

    # 添加常用别名
    fish -c "alias del 'mkdir -p $USER_HOME/.trash; mv -t $USER_HOME/.trash'; funcsave del" > /dev/null 2>&1
    fish -c "alias update 'sudo pacman -Syu'; funcsave update" > /dev/null 2>&1
    fish -c "alias shutdown 'sudo shutdown -h now'; funcsave shutdown" > /dev/null 2>&1
    fish -c "alias reboot 'sudo reboot'; funcsave reboot" > /dev/null 2>&1
}
info "3. Install Fish"
install_fish


install_git() {

    sudo pacman -S --needed --noconfirm git >/dev/null 2>&1

    # 设置全局用户名和邮箱
    git config --global user.name "liuzibo"
    git config --global user.email "liuzibo1925@outlook.com"

}
info "4. Install Git"
install_git


install_proxy() {
    if [ ! -f $FISH_CONFIG_FILE ] || ! grep -q "function proxy" $FISH_CONFIG_FILE; then
        cat >> $FISH_CONFIG_FILE << EOF
function proxy
    set -xg ALL_PROXY http://192.168.223.1:7897
end

function noproxy
    set -e ALL_PROXY
end
EOF
    fi
}
info "5. Install Proxy"
install_proxy

install_go() {

    sudo pacman -S --needed --noconfirm go >/dev/null 2>&1

    # 设置环境变量
    go env -w GO111MODULE=on
    go env -w GOPROXY=https://goproxy.cn,direct
    go env -w GOPATH=/home/liuzibo/code/go
}
info "5. Install Go"
install_go


install_opencode(){

    sudo pacman -S --needed --noconfirm opencode >/dev/null 2>&1
    # 设置API
    mkdir -p $USER_HOME/.config/opencode/

    cat > $USER_HOME/.config/opencode/opencode.json << EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "model": "baidu/glm-5.2",
  "provider": {
    "baidu": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Baidu",
      "options": {
        "baseURL": "http://127.0.0.1:3000/v1"
      },
      "models": {
        "glm-5.2": {
          "name": "GLM 5.2"
        }
      }
    }
  }
}
EOF
}
info "6. Install OpenCode"
install_opencode


install_miniconda() {

    local INSTALL_DIR="$USER_HOME/software/miniconda"

    # 如果已经安装，直接返回
    if [ -d "$INSTALL_DIR" ]; then
        info "Miniconda已安装, 跳过安装"
        return
    fi

    # 定义参数
    local MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
    local TMP_DIR=$(mktemp -d)  # 创建临时目录


    # 下载安装脚本
    info "下载Miniconda安装脚本到临时目录: $TMP_DIR"
    wget -q -O "$TMP_DIR/Miniconda3-latest-Linux-x86_64.sh" "$MINICONDA_URL"

    # 赋予执行权限并安装
    chmod +x "$TMP_DIR/Miniconda3-latest-Linux-x86_64.sh"
    bash "$TMP_DIR/Miniconda3-latest-Linux-x86_64.sh" -b -p "$INSTALL_DIR" >/dev/null 2>&1

    # 配置conda
    $INSTALL_DIR/bin/conda init fish >/dev/null 2>&1
    $INSTALL_DIR/bin/conda config --set auto_activate false >/dev/null 2>&1

    # 清理临时文件
    rm -rf "$TMP_DIR"
}
info "7. Install Miniconda"
install_miniconda

