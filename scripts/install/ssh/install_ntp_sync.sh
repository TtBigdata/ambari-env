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

echo "############## INSTALL NTP_SYNC start #############"

# 读取文件内容并分别存储主机名和IP地址
FILE_PATH="/scripts/.init_done"  # 请确保文件路径正确
HOSTNAMES=()
IPS=()

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

# 从IP列表中选取最小的IP作为服务端，其他的作为客户端
IFS=$'\n' sorted_ips=($(sort <<<"${IPS[*]}"))
unset IFS
SERVER_IP="${sorted_ips[0]}"
CLIENT_IPS=("${sorted_ips[@]:1}")

# 检查并安装Chrony
install_chrony() {
  if ! command -v chronyd &> /dev/null; then
    echo "未安装Chrony。正在安装..."
    sudo yum install chrony -y
  else
    echo "Chrony已安装。"
  fi
}

# 停止已有的chronyd进程
stop_existing_chronyd() {
  if pgrep chronyd &> /dev/null; then
    echo "检测到已有的chronyd进程，正在停止..."
    sudo pkill chronyd
  fi
}

# 配置Chrony服务器
configure_server() {
  sudo tee /etc/chrony.conf > /dev/null <<EOL
# 使用国内NTP服务器作为上游时间源
server ntp.ntsc.ac.cn iburst
server ntp1.aliyun.com iburst
server ntp2.aliyun.com iburst
server ntp3.aliyun.com iburst

# 允许局域网内的其他机器访问
allow 172.20.0.0/24

# 本地时钟源
local stratum 10

# Drift文件
driftfile /var/lib/chrony/drift

# 日志文件
logdir /var/log/chrony
EOL

  stop_existing_chronyd
  sudo /usr/sbin/chronyd
  echo "Chrony服务器配置完成并已启动。"
}

# 配置Chrony客户端
configure_client() {
  local CLIENT_IP=$1
  ssh $CLIENT_IP "sudo tee /etc/chrony.conf > /dev/null <<EOL
# 设置$SERVER_IP为时间服务器
server $SERVER_IP iburst

# Drift文件
driftfile /var/lib/chrony/drift

# 日志文件
logdir /var/log/chrony
EOL
  $(declare -f install_chrony); install_chrony
  $(declare -f stop_existing_chronyd); stop_existing_chronyd
  sudo /usr/sbin/chronyd"
  echo "Chrony客户端$CLIENT_IP配置完成并已启动。"
}

# 验证Chrony客户端
verify_client() {
  local CLIENT_IP=$1
  ssh $CLIENT_IP "chronyc tracking"
}

# 主函数
main() {
  echo "在服务器上安装并配置Chrony..."
  install_chrony
  configure_server

  for CLIENT_IP in "${CLIENT_IPS[@]}"; do
    echo "在客户端$CLIENT_IP上安装并配置Chrony..."
    configure_client $CLIENT_IP
    echo "验证客户端$CLIENT_IP的Chrony配置..."
    verify_client $CLIENT_IP
  done

  echo "Chrony设置完成。"
}

# 执行主函数
main

echo "############## INSTALL NTP_SYNC end #############"
