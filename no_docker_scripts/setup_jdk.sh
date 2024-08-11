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

set -ex

###########JDK_INIT start

echo "############## JDK 初始化开始 #############"

# JDK path and URL
JDK_FILE_PATH="/opt/modules/jdk-8u202-linux-x64.tar.gz"
JDK_FILE_HOME_PATH="/opt/modules/jdk1.8.0_202"
JDK_DOWNLOAD_URL="https://repo.huaweicloud.com/java/jdk/8u202-b08/jdk-8u202-linux-x64.tar.gz"
mkdir -p /data

# 解压缩函数
extract_tar_gz() {
    local file_path=$1
    local dest_dir=$2

    echo "正在将文件 $file_path 解压到目录 $dest_dir..."
    tar -zxvf "$file_path" -C "$dest_dir"

    if [ $? -eq 0 ]; then
        echo "文件解压成功：$dest_dir"
    else
        echo "文件解压失败"
        exit 1
    fi
}

# 配置 JAVA_HOME 函数
configure_java_home() {
    # 使用 sed 命令更新或添加 JAVA_HOME 变量
    if grep -q "^export JAVA_HOME=" /etc/profile; then
        sudo sed -i "s#^export JAVA_HOME=.*#export JAVA_HOME=${JDK_FILE_HOME_PATH}#" /etc/profile
    else
        echo "export JAVA_HOME=${JDK_FILE_HOME_PATH}" | sudo tee -a /etc/profile
    fi

    # 更新 PATH 变量以包含 JAVA_HOME/bin
    if ! grep -q "^export PATH=.*\$JAVA_HOME/bin" /etc/profile; then
        echo "export PATH=\$PATH:\$JAVA_HOME/bin" | sudo tee -a /etc/profile
    fi

    # 重新加载 /etc/profile 文件以应用更改
    source /etc/profile

    # 验证 JAVA_HOME 设置
    echo "JAVA_HOME 已设置为：$JAVA_HOME"
}

# 检查并下载 JDK 文件
check_and_download_jdk() {
    if [ -f "$JDK_FILE_PATH" ]; then
        echo "JDK 文件已存在：$JDK_FILE_PATH"
    else
        echo "JDK 文件不存在，正在下载..."
        mkdir -p "$(dirname "$JDK_FILE_PATH")"
        curl -o "$JDK_FILE_PATH" "$JDK_DOWNLOAD_URL"

        if [ $? -eq 0 ]; then
            echo "JDK 下载成功：$JDK_FILE_PATH"
            extract_tar_gz "$JDK_FILE_PATH" "/opt/modules"
        else
            echo "JDK 下载失败！！"
            exit 1
        fi
    fi
}

# 添加并配置 update-alternatives
configure_update_alternatives() {
    sudo update-alternatives --install /usr/bin/java java ${JDK_FILE_HOME_PATH}/bin/java 2
    sudo update-alternatives --install /usr/bin/javac javac ${JDK_FILE_HOME_PATH}/bin/javac 2

    sudo update-alternatives --set java ${JDK_FILE_HOME_PATH}/bin/java
    sudo update-alternatives --set javac ${JDK_FILE_HOME_PATH}/bin/javac

    # 验证 Java 版本
    java -version
}

main() {
    check_and_download_jdk

    if [ -d "$JDK_FILE_HOME_PATH" ]; then
        echo "JDK 目录已存在：$JDK_FILE_HOME_PATH"
    else
        extract_tar_gz "$JDK_FILE_PATH" "/opt/modules"
    fi

    configure_java_home
    configure_update_alternatives
}

main

###########JDK_INIT end

echo "############## JDK 初始化结束 #############"
