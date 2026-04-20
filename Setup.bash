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
SSH_PUB_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM7ZRY5p7YOXqaqCelSQUmo05+EKkhgL70Q6l3dQAIDh liuzibo@DESKTOP-7JL03RK"

BASIC_PACKAGES=("wget" "vim" "screen" "tree" "less" "man" "zip" "unzip" "jdk17-openjdk" "fastfetch" "htop")


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



# ===================== 功能函数 =====================
install_ssh_key() {

    sudo pacman -Syu --noconfirm >/dev/null 2>&1
    sudo pacman -S --needed --noconfirm openssh >/dev/null 2>&1
    sudo systemctl enable sshd >/dev/null 2>&1

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

    mkdir -p "$USER_HOME/software"
    mkdir -p "$USER_HOME/code"
    mkdir -p "$USER_HOME/code/java"
    mkdir -p "$USER_HOME/code/go"
    mkdir -p "$USER_HOME/code/oss"
    mkdir -p "$USER_HOME/code/setup"

    sudo pacman -Syu --noconfirm >/dev/null 2>&1

    # 安装软件
    sudo pacman -S --needed --noconfirm "${BASIC_PACKAGES[@]}" >/dev/null 2>&1
}


# 3. 安装Fish
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


install_davfs() {
    sudo pacman -S --needed --noconfirm davfs2 >/dev/null 2>&1

    if ! sudo grep -q "http://192.168.100.129:5005/ liuzibo Aliu1019zeber." /etc/davfs2/secrets; then
        echo "http://192.168.100.129:5005/ liuzibo Aliu1019zeber." | sudo tee -a /etc/davfs2/secrets > /dev/null 2>&1
    fi

    sudo mkdir -p /mnt/dav
    fish -c "alias mount 'sudo mount -t davfs http://192.168.100.129:5005/ /mnt/dav'; funcsave mount" > /dev/null 2>&1
    fish -c "alias umount 'sudo umount /mnt/dav'; funcsave umount" > /dev/null 2>&1
}


install_git() {

    sudo pacman -S --needed --noconfirm git >/dev/null 2>&1

    # 设置全局用户名和邮箱
    git config --global user.name "liuzibo"
    git config --global user.email "liuzibo1925@outlook.com"

}

#安装并配置Clash服务
install_clash() {

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
    # sudo systemctl enable clash.service >/dev/null 2>&1
}

install_proxy() {
    if [ ! -f $FISH_CONFIG_FILE ] || ! grep -q "function proxy" $FISH_CONFIG_FILE; then
        cat >> $FISH_CONFIG_FILE << EOF
function proxy
    set -xg ALL_PROXY http://192.168.235.1:7897
end

function noproxy
    set -e ALL_PROXY
end
EOF
    fi
}


install_docker() {

    # 安装Docker
    sudo pacman -S --needed --noconfirm docker >/dev/null 2>&1    

    # 添加Docker配置
    sudo mkdir -p /etc/docker
    local TEMP_FILE="/tmp/daemon.json"

    sudo cat > $TEMP_FILE << EOF
{
    "proxies": {
        "http-proxy": "http://192.168.235.1:7897",
        "https-proxy": "http://192.168.235.1:7897"
    }
}
EOF
    sudo mv $TEMP_FILE /etc/docker/daemon.json

    # 设置开机自启
    sudo systemctl enable docker.socket >/dev/null 2>&1

}


install_mariadb() {

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
    sudo systemctl enable mariadb.service > /dev/null 2>&1
    sudo systemctl start mariadb.service > /dev/null 2>&1

    # 配置用户

    sudo mariadb -u root -p201654 -e "CREATE USER 'liuzibo'@'localhost' IDENTIFIED BY '201654';"
    sudo mariadb -u root -p201654 -e "CREATE USER 'liuzibo'@'%' IDENTIFIED BY '201654';"
    sudo mariadb -u root -p201654 -e "GRANT ALL PRIVILEGES ON *.* TO 'liuzibo'@'localhost';"
    sudo mariadb -u root -p201654 -e "GRANT ALL PRIVILEGES ON *.* TO 'liuzibo'@'%';"
    sudo mariadb -u root -p201654 -e "FLUSH PRIVILEGES;"
}

install_nginx() {

    if [ -d "/etc/nginx" ]; then
        info "Nginx已安装, 跳过安装"
        return
    fi

    # 安装Nginx
    sudo pacman -S --needed --noconfirm nginx-mainline >/dev/null 2>&1    

    # 设置开机自启
    sudo systemctl enable nginx.service >/dev/null 2>&1
    sudo systemctl start nginx.service >/dev/null 2>&1
}


install_go() {

    sudo pacman -S --needed --noconfirm go >/dev/null 2>&1

    # 设置环境变量
    go env -w GO111MODULE=on
    go env -w GOPROXY=https://goproxy.cn,direct
    go env -w GOPATH=/home/liuzibo/code/go
}


install_opencode(){

    sudo pacman -S --needed --noconfirm opencode >/dev/null 2>&1
    # 设置API
    mkdir -p $USER_HOME/.config/opencode/

    cat > $USER_HOME/.config/opencode/opencode.json << EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "model": "baidu/glm-5.1",
  "provider": {
    "baidu": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Baidu",
      "options": {
        "baseURL": "https://qianfan.baidubce.com/v2"
      },
      "models": {
        "glm-5.1": {
          "name": "GLM 5.1"
        }
      }
    }
  }
}
EOF
}


install_frpc() {

    mkdir -p "$USER_HOME/software/frpc"

    local TEMP_FILE="/tmp/frpc.service"
    local SERVICE_DIR="/etc/systemd/system/"

    cat > "$FRPC_CONFIG_FILE" << EOF
serverAddr = "123.57.175.213"
serverPort = 7000

[[proxies]]
name = "Arch10022"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
remotePort = 10022
EOF


    cat > "$TEMP_FILE" << EOF
[Unit]
Description = frp client
After = network.target syslog.target
Wants = network.target

[Service]
Type = simple
ExecStart = /home/liuzibo/software/frpc/frpc -c /home/liuzibo/software/frpc/frpc.toml
Restart = on-failure
RestartSec = 30


[Install]
WantedBy = multi-user.target
EOF
    sudo mv "$TEMP_FILE" "$SERVICE_DIR"
}



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


main() {
    check_sudo
    info "1. Install SSH key"
    install_ssh_key
    info "2. Install common softwares"
    install_common_softwares
    info "3. Install Fish"
    install_fish
    info "4. Install Davfs"
    # install_davfs
    info "5. Install Git"
    install_git
    info "6. Install Clash"
    # install_clash
    info "7. Install Proxy"
    install_docker
    info "8. Install MariaDB"
    install_mariadb
    info "9. Install Nginx"
    install_nginx
    info "10. Install Go"
    install_go
    info "11. Install OpenCode"
    install_opencode
    info "12. Install Frpc"
    install_frpc
    info "13. Install Miniconda"
    install_miniconda
}

main