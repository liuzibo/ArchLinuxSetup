#!/bin/bash

set -euo pipefail


# 颜色输出定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'


# 配置项
SSH_PUB_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP9ZBbCFAxUJ4O5+dEO2QWVz0viCHqd4wcR9dFHM80uE liuzibo@DESKTOP-3I1U4UB"

BASIC_PACKAGES=("wget" "vim" "screen" "tree" "less" "man" "zip" "unzip" "jdk17-openjdk")


# 定义路径常量
USER_HOME=$(eval echo ~$(logname))

FISH_CONFIG_FILE="$USER_HOME/.config/fish/config.fish"

SSH_CONFIG_FILE="$USER_HOME/.ssh/authorized_keys"


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
        error "没有Root权限"
    fi
}



# ===================== 功能函数 =====================

# 1. 安装SSH公钥
install_ssh_key() {
    info "1. 开始配置SSH密钥..."

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

# 2. 安装常用软件
install_common_softwares() {
    info "2. 开始安装常用软件..."
    
    sudo pacman -Syu --noconfirm >/dev/null 2>&1

    # 安装软件
    sudo pacman -S --needed --noconfirm "${BASIC_PACKAGES[@]}" >/dev/null 2>&1
}

# 3. 安装Fish
install_fish() {
    info "3. 开始安装Fish..."

    if [ -f $FISH_CONFIG_FILE ]; then
        info "Fish已安装, 跳过安装"
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

# 4. 安装Git
install_git() {
    info "4. 开始安装Git..."

    sudo pacman -S --needed --noconfirm git >/dev/null 2>&1

    # 设置全局用户名和邮箱
    git config --global user.name "liuzibo"
    git config --global user.email "liuzibo1925@outlook.com"

}

# 5. 安装并配置Clash服务
install_clash() {
    info "5. 开始安装Clash..."

    sudo pacman -S --needed --noconfirm clash >/dev/null 2>&1

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
}

# 6. 安装并配置Docker
install_docker() {
    info "6. 开始安装Docker..."

    # 安装Docker
    sudo pacman -S --needed --noconfirm docker >/dev/null 2>&1    

    # 添加Docker配置
    sudo mkdir -p /etc/docker
    local TEMP_FILE="/tmp/daemon.json"

    sudo cat > $TEMP_FILE << EOF
{
    "proxies": {
        "http-proxy": "http://127.0.0.1:7890",
        "https-proxy": "http://127.0.0.1:7890"
    }
}
EOF
    sudo mv $TEMP_FILE /etc/docker/daemon.json

    # 设置开机自启
    sudo systemctl enable docker.socket

}

# 7. 安装并配置MariaDB
install_mariadb() {
    info "7. 开始安装MariaDB..."

    if [ -d "/var/lib/mysql" ]; then
        info "MariaDB已安装, 跳过安装"
        return
    fi

    # 安装MariaDB
    sudo pacman -S --needed --noconfirm mariadb >/dev/null 2>&1    

    # 设置数据库文件夹不可压缩
    sudo chattr +C /var/lib/mysql >/dev/null 2>&1

    # 初始化数据库
    sudo mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql >/dev/null 2>&1

    # 设置开机自启
    sudo systemctl enable mariadb.service
    sudo systemctl start mariadb.service

    # 配置用户

    sudo mariadb -u root -p201654 -e "CREATE USER 'liuzibo'@'localhost' IDENTIFIED BY '201654';"
    sudo mariadb -u root -p201654 -e "CREATE USER 'liuzibo'@'%' IDENTIFIED BY '201654';"
    sudo mariadb -u root -p201654 -e "GRANT ALL PRIVILEGES ON *.* TO 'liuzibo'@'localhost';"
    sudo mariadb -u root -p201654 -e "GRANT ALL PRIVILEGES ON *.* TO 'liuzibo'@'%';"
    sudo mariadb -u root -p201654 -e "FLUSH PRIVILEGES;"

}

# 8. 安装并配置Nginx
install_nginx() {
    info "8. 开始安装Nginx..."
    
    if [ -d "/etc/nginx" ]; then
        info "Nginx已安装, 跳过安装"
        return
    fi

    # 安装Nginx
    sudo pacman -S --needed --noconfirm nginx >/dev/null 2>&1    

    # 设置开机自启
    sudo systemctl enable nginx.service
    sudo systemctl start nginx.service

}

# 9. 安装并配置Miniconda
install_miniconda() {
    info "9. 开始安装Miniconda..."

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
    bash "$TMP_DIR/Miniconda3-latest-Linux-x86_64.sh" -b -p "$INSTALL_DIR"

    # 配置conda
    $INSTALL_DIR/bin/conda init fish
    $INSTALL_DIR/bin/conda config --set auto_activate false

    # 清理临时文件
    rm -rf "$TMP_DIR"
}

# ===================== 主执行流程 =====================
main() {
    # 检查sudo权限
    check_sudo

    # 1. 安装SSH公钥
    install_ssh_key

    # 2. 安装常用软件
    install_common_softwares

    # 3. 安装Fish
    install_fish

    # 4. 安装Git
    install_git

    # 5. 安装并配置Clash服务
    install_clash

    # 6. 安装并配置Docker
    install_docker

    # 7. 安装并配置MariaDB
    install_mariadb

    # 8. 安装并配置Nginx
    install_nginx

    # 9. 安装并配置Miniconda
    install_miniconda
}

main