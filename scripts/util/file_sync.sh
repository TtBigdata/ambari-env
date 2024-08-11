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

# 检查是否提供了源路径参数
if [ -z "$1" ]; then
    echo "使用方法: $0 <source_path>"
    exit 1
fi

# 获取当前用户名
USER=$(whoami)

# 获取源路径
SOURCE_PATH="$1"

# 如果源路径是相对路径，则转换为绝对路径
if [[ "$SOURCE_PATH" != /* ]]; then
    SOURCE_PATH="$(pwd)/$SOURCE_PATH"
fi

# 获取当前机器的IP地址
CURRENT_IP=$(hostname -I | awk '{print $1}')

# 定义日志文件路径
LOG_FILE="/var/log/file_sync.log"

# 确保日志文件路径存在
mkdir -p "$(dirname "$LOG_FILE")"

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
    echo "[$(date)] 文件 $FILE_PATH 不存在" | tee -a "$LOG_FILE"
    exit 1
fi

# 定义日志记录函数
log() {
    echo "[$(date)] $1" | tee -a "$LOG_FILE"
}

# 定义文件传输函数
transfer_files() {
    local target_ip=$1
    local start_time=$(date +%s)

    log "正在将文件传输到 $USER@$target_ip:$SOURCE_PATH"

    # 确保目标路径存在
    ssh $USER@$target_ip "mkdir -p $SOURCE_PATH"
    if [ $? -ne 0 ]; then
        log "无法在 $USER@$target_ip 上创建目录 $SOURCE_PATH"
        return 1
    fi

    # 统计要传输的文件个数
    file_count=$(find $SOURCE_PATH -type f | wc -l)

    scp -r $SOURCE_PATH/* $USER@$target_ip:$SOURCE_PATH
    if [ $? -eq 0 ]; then
        local end_time=$(date +%s)
        local elapsed_time=$((end_time - start_time))
        log "文件成功传输到 $USER@$target_ip:$SOURCE_PATH"
        log "传输文件个数: $file_count"
        log "传输时间: ${elapsed_time}秒"
    else
        log "文件传输到 $USER@$target_ip:$SOURCE_PATH 失败"
    fi
}

# 记录脚本开始时间
script_start_time=$(date +%s)

# 遍历目标主机列表并执行文件传输
for TARGET_IP in "${IPS[@]}"; do
    if [ "$TARGET_IP" != "$CURRENT_IP" ]; then
        transfer_files "$TARGET_IP" &
    else
        log "跳过传输到自身 ($CURRENT_IP)"
    fi
done

# 等待所有后台任务完成
wait

# 记录脚本结束时间
script_end_time=$(date +%s)
script_elapsed_time=$((script_end_time - script_start_time))

log "脚本执行总时间: ${script_elapsed_time}秒"
