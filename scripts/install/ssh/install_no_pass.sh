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

set -e
echo "############## INSTALL NO_PASS start #############"

mkdir -p /root/.ssh/

# 定义默认用户名和密码
DEFAULT_USER="root"
DEFAULT_PASS="root"

# 定义两个空的数组，分别存储主机名和IP地址
HOSTNAMES=()
IPS=()

# 读取文件内容并分别存储主机名和IP地址
FILE_PATH="/scripts/.init_done"  # 请确保文件路径正确
if [[ -f "$FILE_PATH" ]]; then
    while IFS= read -r line; do
        # 拆分主机名和IP地址
        HOSTNAME=$(echo "$line" | cut -d'@' -f1)
        IP=$(echo "$line" | cut -d'@' -f2)
        HOSTNAMES+=("$HOSTNAME")
        IPS+=("$IP")
    done < "$FILE_PATH"
else
    echo "文件 $FILE_PATH 不存在"
    exit 1
fi

# 打印 HOSTNAMES 和 IPS 数组以验证内容
echo "HOSTNAMES 数组内容："
for HOST in "${HOSTNAMES[@]}"; do
    echo "$HOST"
done

echo "IPS 数组内容："
for IP in "${IPS[@]}"; do
    echo "$IP"
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
    local hostnames=("${!4}")
    local ips=("${!5}")
    echo "更新 $host 的 /etc/hosts 文件..."
    for ((i=0; i<${#hostnames[@]}; i++)); do
        sshpass -p "$pass" ssh -o StrictHostKeyChecking=no "$user@$host" "
            if ! grep -q '${ips[i]} ${hostnames[i]}' /etc/hosts; then
                echo '${ips[i]} ${hostnames[i]}' >> /etc/hosts
            fi
        " || { echo "Failed to update /etc/hosts on $host"; exit 1; }
    done
}

# 更新所有机器的 /etc/hosts 文件
for ((i=0; i<${#IPS[@]}; i++)); do
    for ((j=0; j<${#IPS[@]}; j++)); do
        update_hosts_file "$DEFAULT_USER" "${IPS[j]}" "$DEFAULT_PASS" HOSTNAMES[@] IPS[@]
    done
done

# 处理主机名之间的密钥生成和分发
for ((i=0; i<${#HOSTNAMES[@]}; i++)); do
    USER=$DEFAULT_USER
    HOST=${HOSTNAMES[i]}
    PASS=$DEFAULT_PASS

    remove_known_host "$HOST"
    generate_ssh_key "$USER" "$HOST" "$PASS"
    PUB_KEY_CONTENT=$(get_public_key "$USER" "$HOST" "$PASS")

    for ((j=0; j<${#HOSTNAMES[@]}; j++)); do
        TARGET_USER=$DEFAULT_USER
        TARGET_HOST=${HOSTNAMES[j]}
        TARGET_PASS=$DEFAULT_PASS

        remove_known_host "$TARGET_HOST"
        distribute_public_key "$PUB_KEY_CONTENT" "$TARGET_USER" "$TARGET_HOST" "$TARGET_PASS"
    done
done

# 处理 IP 之间的密钥生成和分发
for ((i=0; i<${#IPS[@]}; i++)); do
    USER=$DEFAULT_USER
    HOST=${IPS[i]}
    PASS=$DEFAULT_PASS

    remove_known_host "$HOST"
    generate_ssh_key "$USER" "$HOST" "$PASS"
    PUB_KEY_CONTENT=$(get_public_key "$USER" "$HOST" "$PASS")

    for ((j=0; j<${#IPS[@]}; j++)); do
        TARGET_USER=$DEFAULT_USER
        TARGET_HOST=${IPS[j]}
        TARGET_PASS=$DEFAULT_PASS

        remove_known_host "$TARGET_HOST"
        distribute_public_key "$PUB_KEY_CONTENT" "$TARGET_USER" "$TARGET_HOST" "$TARGET_PASS"
    done
done

# 验证主机名之间的无密码登录
for ((i=0; i<${#HOSTNAMES[@]}; i++)); do
    USER=$DEFAULT_USER
    HOST=${HOSTNAMES[i]}
    PASS=$DEFAULT_PASS

    for ((j=0; j<${#HOSTNAMES[@]}; j++)); do
        TARGET_USER=$DEFAULT_USER
        TARGET_HOST=${HOSTNAMES[j]}
        TARGET_PASS=$DEFAULT_PASS

        remove_known_host "$TARGET_HOST"
        verify_passwordless_ssh "$USER" "$HOST" "$PASS" "$TARGET_USER" "$TARGET_HOST"
    done
done

# 验证 IP 之间的无密码登录
for ((i=0; i<${#IPS[@]}; i++)); do
    USER=$DEFAULT_USER
    HOST=${IPS[i]}
    PASS=$DEFAULT_PASS

    for ((j=0; j<${#IPS[@]}; j++)); do
        TARGET_USER=$DEFAULT_USER
        TARGET_HOST=${IPS[j]}
        TARGET_PASS=$DEFAULT_PASS

        remove_known_host "$TARGET_HOST"
        verify_passwordless_ssh "$USER" "$HOST" "$PASS" "$TARGET_USER" "$TARGET_HOST"
    done
done

# 为自身配置免密登录
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ''
fi

cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
sort -u -o ~/.ssh/authorized_keys ~/.ssh/authorized_keys

# 验证自身通过主机名的免密登录
HOSTNAME=$(hostname)
ssh -o PasswordAuthentication=no "$HOSTNAME" /bin/true
if [ $? -ne 0 ]; then
    echo "Passwordless SSH setup failed for hostname $HOSTNAME"
    exit 1
fi

# 验证自身通过IP的免密登录
IP=$(hostname -I | awk '{print $1}')
ssh -o PasswordAuthentication=no "$IP" /bin/true
if [ $? -ne 0 ]; then
    echo "Passwordless SSH setup failed for IP $IP"
    exit 1
fi

echo "############## INSTALL NO_PASS end #############"
