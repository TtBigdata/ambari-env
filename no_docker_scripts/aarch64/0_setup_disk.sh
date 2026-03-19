#!/bin/bash

DISK=/dev/vdb
PART=${DISK}1
MOUNT=/data

# 创建分区
echo -e "n\np\n1\n\n\nw" | fdisk $DISK

# 刷新分区表
partprobe $DISK
sleep 2

# 格式化
mkfs.xfs -f $PART

# 创建挂载目录
mkdir -p $MOUNT

# 获取UUID
UUID=$(blkid -s UUID -o value $PART)

# 写入fstab
echo "UUID=$UUID $MOUNT xfs defaults,noatime,nodiratime 0 0" >> /etc/fstab

# 挂载
mount -a

# 查看结果
df -h