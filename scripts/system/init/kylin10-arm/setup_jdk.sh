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

########### JDK_INIT start

echo "############## SETUP JDK_INIT start #############"

# ------- 架构检查 -------
ARCH="$(uname -m)"
[[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]] || { echo "ERROR: 当前架构不是 aarch64: $ARCH"; exit 1; }

# ------- JDK 8 相关参数（毕昇JDK 8 aarch64，华为国内 CDN；Adoptium 兜底） -------
# 毕昇JDK（Bisheng JDK）：华为为 Kunpeng/ARM 专项优化的 OpenJDK 发行版，有国内 CDN 加速
JDK8_FILENAME="bisheng-jdk-8u472-b11-linux-aarch64.tar.gz"
JDK8_FILE_PATH="/opt/modules/${JDK8_FILENAME}"
JDK8_FILE_HOME_PATH="/opt/modules/bisheng-jdk-8u472-b11"
JDK8_DOWNLOAD_URL="https://mirrors.huaweicloud.com/kunpeng/archive/compiler/bisheng_jdk/${JDK8_FILENAME}"
JDK8_DOWNLOAD_URL_FALLBACK="https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u472-b11/OpenJDK8U-jdk_aarch64_linux_hotspot_8u472b11.tar.gz"
JDK8_FALLBACK_HOME="/opt/modules/jdk8u472-b11"

# ------- JDK 17 相关参数（毕昇JDK 17，同镜像） -------
JDK17_FILENAME="bisheng-jdk-17.0.17-b11-linux-aarch64.tar.gz"
JDK17_DOWNLOAD_URL="https://mirrors.huaweicloud.com/kunpeng/archive/compiler/bisheng_jdk/${JDK17_FILENAME}"
JDK17_FILE_PATH="/opt/modules/${JDK17_FILENAME}"


JDK_FILE_PATH_LOCK="/data/.setup_jdk.lock"
TAR_LOCK="/data/.setup_jdk_tar.lock"
mkdir -p /data /opt/modules

# 解压缩函数
extract_tar_gz() {
    local file_path=$1
    local dest_dir=$2

    if [ -f "$TAR_LOCK" ]; then
        return
    else
        touch $TAR_LOCK
    fi

    echo "Extracting file $file_path to directory $dest_dir..."
    tar -zxvf "$file_path" -C "$dest_dir"
    if [ $? -eq 0 ]; then
        echo "File extracted successfully: $dest_dir"
    else
        echo "File extraction failed"
        exit 1
    fi

    rm -f $TAR_LOCK
}

# 检查并下载 JDK 文件（支持多个备用 URL）
check_and_download_jdk() {
    local file_path=$1
    shift
    local urls=("$@")   # 剩余参数均为下载 URL，依次尝试

    if [ -f "$file_path" ]; then
        echo "JDK file exists: $file_path"
    elif [ -f "$JDK_FILE_PATH_LOCK" ]; then
        echo "Other instance downloading..."
    else
        touch $JDK_FILE_PATH_LOCK
        mkdir -p "$(dirname "$file_path")"

        local ok=0
        for url in "${urls[@]}"; do
            echo "尝试下载: $url"
            if curl -L --retry 3 --retry-delay 2 --connect-timeout 30 --max-time 600 \
                    -o "$file_path" "$url" && [ -s "$file_path" ]; then
                echo "下载成功: $file_path"
                ok=1
                break
            else
                echo "下载失败，切换到下一个源..."
                rm -f "$file_path"
            fi
        done

        if [ $ok -eq 0 ]; then
            echo "所有源下载均失败！"
            rm -f $JDK_FILE_PATH_LOCK
            exit 1
        fi

        rm -f $JDK_FILE_PATH_LOCK
    fi

    while [ -f "$JDK_FILE_PATH_LOCK" ]; do
        echo "Waiting for the lock to be released..."
        sleep 1
    done

    echo "Lock released. Continuing..."
}

# 配置 JAVA_HOME
configure_java8_home() {
    # 删除旧配置
    sed -i '/^export JAVA_HOME=/d' /etc/profile
    sed -i '/JAVA_HOME\/bin/d' /etc/profile
    # 新增 JDK8 配置
    echo "export JAVA_HOME=${JDK8_FILE_HOME_PATH}" | tee -a /etc/profile
    echo 'export PATH=$PATH:$JAVA_HOME/bin' | tee -a /etc/profile
    source /etc/profile
    echo "JAVA_HOME is set to: $JAVA_HOME"
}

main() {
    # ------- JDK 8：毕昇优先，Adoptium 兜底 -------
    # 先尝试毕昇 JDK（国内 CDN）
    check_and_download_jdk "$JDK8_FILE_PATH" \
        "$JDK8_DOWNLOAD_URL" \
        "$JDK8_DOWNLOAD_URL_FALLBACK"

    # 根据实际下载到的包确定解压目录
    if [ -f "$JDK8_FILE_PATH" ] && [ ! -d "$JDK8_FILE_HOME_PATH" ]; then
        extract_tar_gz "$JDK8_FILE_PATH" "/opt/modules"
    fi
    # 若毕昇包下载失败、实际落盘的是 Adoptium，更新 HOME 路径
    if [ ! -d "$JDK8_FILE_HOME_PATH" ] && [ -d "$JDK8_FALLBACK_HOME" ]; then
        JDK8_FILE_HOME_PATH="$JDK8_FALLBACK_HOME"
    fi

    # ------- JDK 17：华为镜像 aarch64 -------
    check_and_download_jdk "$JDK17_FILE_PATH" "$JDK17_DOWNLOAD_URL"
    local jdk17_home_dir
    jdk17_home_dir=$(ls -d /opt/modules/jdk-17.0.* 2>/dev/null | head -n 1)
    [ -d "$jdk17_home_dir" ] || extract_tar_gz "$JDK17_FILE_PATH" "/opt/modules"

    configure_java8_home

    echo "当前默认 JAVA_HOME 为 JDK 8（${JDK8_FILE_HOME_PATH}），如需切换 JDK 17，手动修改 /etc/profile 并 source 一下即可。"
}

main

########### JDK_INIT end

echo "############## SETUP JDK_INIT end #############"
