#!/bin/bash
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License. You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Author: JaneTTR

# 定义默认用户名和密码
DEFAULT_USER="root"
DEFAULT_PASS="root"

# 定义主机名和IP地址的映射关系
MACHINES=(
    "centos2@172.20.0.4"
    "centos3@172.20.0.3"
    "centos1@172.20.0.5"
)

# 打印 MACHINES 数组以验证内容
echo "MACHINES 数组内容："
for MACHINE in "${MACHINES[@]}"; do
    echo "$MACHINE"
done

# 安装 sshpass 工具（如果未安装）
if ! command -v sshpass &> /dev/null; then
    echo "sshpass 未安装，正在安装..."
    sudo yum install -y sshpass || { echo "Failed to install sshpass"; exit 1; }
fi

# 检查 known_hosts 文件是否存在
KNOWN_HOSTS_FILE="/root/.ssh/known_hosts"
if [[ ! -f "$KNOWN_HOSTS_FILE" ]]; then
    touch "$KNOWN_HOSTS_FILE" || { echo "Failed to create $KNOWN_HOSTS_FILE"; exit 1; }
fi

# 函数：删除已知主机记录
remove_known_host() {
    local host=$1
    ssh-keygen -R "$host" &>/dev/null || { echo "Failed to remove known host for $host"; exit 1; }
}

# 函数：生成 SSH 密钥对
generate_ssh_key() {
    local user=$1
    local host=$2
    local pass=$3
    echo "正在 $host 上生成 SSH 密钥对..."
    sshpass -p "$pass" ssh -o StrictHostKeyChecking=no "$user@$host" "mkdir -p ~/.ssh && if [ ! -f ~/.ssh/id_rsa ]; then ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ''; fi" || { echo "Failed to generate SSH key on $host"; exit 1; }
}

# 函数：获取公钥内容
get_public_key() {
    local user=$1
    local host=$2
    local pass=$3
    sshpass -p "$pass" ssh -o StrictHostKeyChecking=no "$user@$host" "cat ~/.ssh/id_rsa.pub" || { echo "Failed to read public key from $host"; exit 1; }
}

# 函数：分发公钥
distribute_public_key() {
    local pub_key=$1
    local user=$2
    local target_host=$3
    local target_pass=$4
    echo "正在将公钥分发到 $target_host..."
    sshpass -p "$target_pass" ssh -o StrictHostKeyChecking=no "$user@$target_host" "mkdir -p ~/.ssh && echo '$pub_key' >> ~/.ssh/authorized_keys && sort -u -o ~/.ssh/authorized_keys ~/.ssh/authorized_keys" || { echo "Failed to distribute public key to $target_host"; exit 1; }
}

# 函数：验证无密码登录
verify_passwordless_ssh() {
    local user=$1
    local host=$2
    local pass=$3
    local target_user=$4
    local target_host=$5
    echo "验证从 $host 到 $target_host 的无密码登录..."
    sshpass -p "$pass" ssh -o StrictHostKeyChecking=no "$user@$host" "ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no $target_user@$target_host 'echo Passwordless SSH setup successful from $host to $target_host!'" || { echo "Passwordless SSH setup failed from $host to $target_host"; exit 1; }
}

# 函数：更新 /etc/hosts 文件
update_hosts_file() {
    local user=$1
    local host=$2
    local pass=$3
    local machines=("${!4}")
    echo "更新 $host 的 /etc/hosts 文件..."
    for machine in "${machines[@]}"; do
        local hostname=$(echo "$machine" | cut -d'@' -f1)
        local ip=$(echo "$machine" | cut -d'@' -f2)
        sshpass -p "$pass" ssh -o StrictHostKeyChecking=no "$user@$host" "
            if ! grep -q '$ip $hostname' /etc/hosts; then
                echo '$ip $hostname' >> /etc/hosts
            fi
        " || { echo "Failed to update /etc/hosts on $host"; exit 1; }
    done
}

# 更新所有机器的 /etc/hosts 文件
for machine in "${MACHINES[@]}"; do
    ip=$(echo "$machine" | cut -d'@' -f2)
    update_hosts_file "$DEFAULT_USER" "$ip" "$DEFAULT_PASS" MACHINES[@]
done

# 处理主机名之间的密钥生成和分发
for machine in "${MACHINES[@]}"; do
    USER=$DEFAULT_USER
    HOSTNAME=$(echo "$machine" | cut -d'@' -f1)
    IP=$(echo "$machine" | cut -d'@' -f2)
    PASS=$DEFAULT_PASS

    remove_known_host "$HOSTNAME"
    generate_ssh_key "$USER" "$HOSTNAME" "$PASS"
    PUB_KEY_CONTENT=$(get_public_key "$USER" "$HOSTNAME" "$PASS")

    for target_machine in "${MACHINES[@]}"; do
        TARGET_USER=$DEFAULT_USER
        TARGET_HOSTNAME=$(echo "$target_machine" | cut -d'@' -f1)
        TARGET_IP=$(echo "$target_machine" | cut -d'@' -f2)
        TARGET_PASS=$DEFAULT_PASS

        if [ "$HOSTNAME" != "$TARGET_HOSTNAME" ]; then
            remove_known_host "$TARGET_HOSTNAME"
            distribute_public_key "$PUB_KEY_CONTENT" "$TARGET_USER" "$TARGET_HOSTNAME" "$TARGET_PASS"
        fi
    done
done

# 处理 IP 之间的密钥生成和分发
for machine in "${MACHINES[@]}"; do
    USER=$DEFAULT_USER
    HOSTNAME=$(echo "$machine" | cut -d'@' -f1)
    IP=$(echo "$machine" | cut -d'@' -f2)
    PASS=$DEFAULT_PASS

    remove_known_host "$IP"
    generate_ssh_key "$USER" "$IP" "$PASS"
    PUB_KEY_CONTENT=$(get_public_key "$USER" "$IP" "$PASS")

    for target_machine in "${MACHINES[@]}"; do
        TARGET_USER=$DEFAULT_USER
        TARGET_HOSTNAME=$(echo "$target_machine" | cut -d'@' -f1)
        TARGET_IP=$(echo "$target_machine" | cut -d'@' -f2)
        TARGET_PASS=$DEFAULT_PASS

        if [ "$IP" != "$TARGET_IP" ]; then
            remove_known_host "$TARGET_IP"
            distribute_public_key "$PUB_KEY_CONTENT" "$TARGET_USER" "$TARGET_IP" "$TARGET_PASS"
        fi
    done
done

# 验证主机名之间的无密码登录
for machine in "${MACHINES[@]}"; do
    USER=$DEFAULT_USER
    HOSTNAME=$(echo "$machine" | cut -d'@' -f1)
    IP=$(echo "$machine" | cut -d'@' -f2)
    PASS=$DEFAULT_PASS

    for target_machine in "${MACHINES[@]}"; do
        TARGET_USER=$DEFAULT_USER
        TARGET_HOSTNAME=$(echo "$target_machine" | cut -d'@' -f1)
        TARGET_IP=$(echo "$target_machine" | cut -d'@' -f2)
        TARGET_PASS=$DEFAULT_PASS

        if [ "$HOSTNAME" != "$TARGET_HOSTNAME" ]; then
            remove_known_host "$TARGET_HOSTNAME"
            verify_passwordless_ssh "$USER" "$HOSTNAME" "$PASS" "$TARGET_USER" "$TARGET_HOSTNAME"
        fi
    done
done

# 验证 IP 之间的无密码登录
for machine in "${MACHINES[@]}"; do
    USER=$DEFAULT_USER
    HOSTNAME=$(echo "$machine" | cut -d'@' -f1)
    IP=$(echo "$machine" | cut -d'@' -f2)
    PASS=$DEFAULT_PASS

    for target_machine in "${MACHINES[@]}"; do
        TARGET_USER=$DEFAULT_USER
        TARGET_HOSTNAME=$(echo "$target_machine" | cut -d'@' -f1)
        TARGET_IP=$(echo "$target_machine" | cut -d'@' -f2)
        TARGET_PASS=$DEFAULT_PASS

        if [ "$IP" != "$TARGET_IP" ]; then
            remove_known_host "$TARGET_IP"
            verify_passwordless_ssh "$USER" "$IP" "$PASS" "$TARGET_USER" "$TARGET_IP"
        fi
    done
done
