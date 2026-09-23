#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "please using root"
  exit 1
fi


echo ">>> 1. Config pacman"
echo "Server = https://mirrors.ustc.edu.cn/archlinux/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist


echo ">>> 2. Update System"
pacman -Syyu --noconfirm
pacman -S vim sudo openssh --noconfirm

echo ">>> 3. Create User"
USERNAME="liuzibo"
DEFAULT_PASS="201654"
useradd -m -s /bin/bash -G wheel "$USERNAME"
echo "$USERNAME:$DEFAULT_PASS" | chpasswd

echo ">>> 4. Config Sudo"
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/10-wheel-group
chmod 0440 /etc/sudoers.d/10-wheel-group


echo ">>> 5. Config SSH"
ssh-keygen -A

