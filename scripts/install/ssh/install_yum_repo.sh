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

echo "############## INSTALL YUM REPO start #############"

# 文件路径和全局变量
FILE_PATH="/scripts/.init_done" # 请确保文件路径正确
REPO_DIR="/data/rpm-package"
NGINX_REPO_DIR="/usr/share/nginx/html/repo"
NGINX_CONF="/etc/nginx/conf.d/yum_repo.conf"
NGINX_BIN="/usr/sbin/nginx"
HOSTNAMES=()
IPS=()

mkdir -p "$NGINX_REPO_DIR"

# 读取文件内容并分别存储主机名和IP地址
read_file() {
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
}

# 从IP列表中选取最小的IP作为服务端，其他的作为客户端
select_server_and_clients() {
    IFS=$'\n' sorted_ips=($(sort <<<"${IPS[*]}"))
    unset IFS
    SERVER_IP="${sorted_ips[0]}"
    CLIENT_IPS=("${sorted_ips[@]:1}")
}

# 检查并安装所需的软件包
install_packages() {
    local packages=("nginx" "createrepo")
    for package in "${packages[@]}"; do
        if ! rpm -q $package &> /dev/null; then
            echo "未安装 $package。正在安装..."
            sudo yum install -y $package
        else
            echo "$package 已安装。"
        fi
    done
}

# 停止已有的nginx进程
stop_existing_nginx() {
    if pgrep nginx &> /dev/null; then
        echo "检测到已有的nginx进程，正在停止..."
        sudo pkill nginx
    fi
}

# 生成或更新YUM仓库元数据
update_repo_metadata() {
    if [ -d "${REPO_DIR}/repodata" ]; then
        createrepo --update ${REPO_DIR}
    else
        createrepo ${REPO_DIR}
    fi
}

# 创建软链接
create_symlink() {
    ln -sfn ${REPO_DIR} ${NGINX_REPO_DIR}/packages
}

# 配置Nginx
configure_nginx() {
    cat <<EOL | sudo tee ${NGINX_CONF}
server {
    listen 80;
    server_name localhost;
    location / {
        autoindex on;
        alias ${NGINX_REPO_DIR}/packages/;
    }
}
EOL
}

# 启动Nginx服务
start_nginx() {
    stop_existing_nginx
    sudo ${NGINX_BIN}
    echo "Nginx服务配置完成并已启动。"
}

# 验证Nginx是否正在运行
verify_nginx() {
    if pgrep nginx &> /dev/null; then
        echo "Nginx 正在运行。"
    else
        echo "Nginx 未能启动，请检查配置。"
        exit 1
    fi
}

# 配置客户端的YUM仓库
configure_client_repo() {
    local CLIENT_IP=$1
    ssh $CLIENT_IP "sudo tee /etc/yum.repos.d/CentOS-Ambari.repo > /dev/null <<EOL
[CentOS-Ambari]
name=CentOS-Ambari
baseurl=http://${SERVER_IP}/
enabled=1
gpgcheck=0
EOL"
}

# 主函数
main() {
    read_file
    select_server_and_clients
    install_packages
    update_repo_metadata
    create_symlink
    configure_nginx
    start_nginx
    verify_nginx

    for CLIENT_IP in "${CLIENT_IPS[@]}"; do
        configure_client_repo $CLIENT_IP
    done
}

main "$@"
echo "############## INSTALL YUM REPO end #############"
