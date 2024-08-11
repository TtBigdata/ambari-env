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

# 获取主机名
HOST_NAME=$(hostname)

# 获取 IP 地址
IP_ADDRESS=$(cat /etc/hosts | grep -v '^#' | grep -v '127.0.0.1' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | awk '{print $1}')

# 生成要添加的内容
CONTENT="${HOST_NAME}@${IP_ADDRESS}"

# 检查文件中是否已经存在相同的内容
if ! grep -Fxq "$CONTENT" /scripts/.init_done; then
    # 如果不存在，则追加到文件
    echo "$CONTENT" >> /scripts/.init_done
fi
