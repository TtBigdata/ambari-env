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

echo "############## SETUP ANT_IVY start #############"

# 定义变量
ANT_URL="https://mirrors.huaweicloud.com/apache//ant/binaries/apache-ant-1.10.12-bin.tar.gz"
IVY_URL="https://mirrors.huaweicloud.com/apache//ant/ivy/2.5.0/apache-ivy-2.5.0-bin.tar.gz"
ANT_TAR="/opt/modules/apache-ant-1.10.12-bin.tar.gz"
IVY_TAR="/opt/modules/apache-ivy-2.5.0-bin.tar.gz"
ANT_DIR="/opt/modules/apache-ant-1.10.12"
IVY_DIR="/opt/modules/apache-ivy-2.5.0"

# 创建安装目录
sudo mkdir -p /opt/modules

# 下载文件的函数
download_if_not_exists() {
    local url=$1
    local file=$2
    if [ ! -f "$file" ]; then
        echo "正在下载 $file..."
        wget -q "$url" -O "$file"
    else
        echo "$file 已存在，跳过下载。"
    fi
}

# 解压文件的函数
extract_if_not_exists() {
    local file=$1
    local dir=$2
    if [ ! -d "$dir" ]; then
        echo "正在解压 $file..."
        sudo tar -xzf "$file" -C /opt/modules
    else
        echo "$dir 已存在，跳过解压。"
    fi
}

# 配置环境变量的函数
configure_env_variable() {
    local var_name=$1
    local var_value=$2
    local profile_file="/etc/profile"
    if ! grep -q "export $var_name=" "$profile_file"; then
        echo "正在配置 $var_name 到 $profile_file..."
        echo "export $var_name=$var_value" | sudo tee -a "$profile_file"
        echo 'export PATH=$PATH:$'"$var_name"'/bin' | sudo tee -a "$profile_file"
    else
        echo "$var_name 已配置在 $profile_file 中。"
    fi
}

# 下载 Ant 和 Ivy
download_if_not_exists "$ANT_URL" "$ANT_TAR"
download_if_not_exists "$IVY_URL" "$IVY_TAR"

# 解压 Ant 和 Ivy
extract_if_not_exists "$ANT_TAR" "$ANT_DIR"
extract_if_not_exists "$IVY_TAR" "$IVY_DIR"

# 配置环境变量
configure_env_variable "ANT_HOME" "$ANT_DIR"
configure_env_variable "IVY_HOME" "$IVY_DIR"

# 重新加载 /etc/profile
source /etc/profile

echo "############## SETUP ANT_IVY end #############"