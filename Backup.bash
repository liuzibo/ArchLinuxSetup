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


# 定义路径常量
USER_HOME=$(eval echo ~$(logname))
BACKUP_DIR=/mnt/smb/Backup/Code_$(date +%Y%m%d)
CODE_DIR=$USER_HOME/software

backup() {
    info "开始备份配置文件..."

    if [ -d $BACKUP_DIR ]; then
        warn "备份目录已存在"
        return
    fi

    sudo mkdir -p $BACKUP_DIR

    for folder in $CODE_DIR/*/; do
        info "正在备份 $folder..."
        folder_name=$(basename "$folder")
        cd $CODE_DIR
        tar -zcvf $folder_name.tar.gz $folder_name > /dev/null 2>&1
        sudo mv $folder_name.tar.gz $BACKUP_DIR
    info "所有文件备份完成"
    done
}

backup