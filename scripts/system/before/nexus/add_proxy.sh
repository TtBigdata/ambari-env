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
echo "############## ADD NEXUS_PROXY start #############"

LOCK_FILE="/scripts/system/before/nexus/.lock"
NEXUS_LOG="/nexus-data/log/nexus.log"
rm -rf "$LOCK_FILE"

# Start Nexus
/opt/sonatype/start-nexus-repository-manager.sh &
nexus_pid=$!

# Wait for Nexus to start
echo "等待Nexus 服务启动中。。。"
while [ ! -e "$NEXUS_LOG" ]; do
  echo "等待日志文件生成中..."
  sleep 1
done

tail -f -n 1 "$NEXUS_LOG" | while read -r line; do
  if echo "$line" | grep -q "Started Sonatype Nexus OSS 3.69.0-02"; then
    echo "Nexus has started."
    break
  fi
done

# 设置mvn仓库
bash /scripts/system/after/nexus/setup_mvn_proxy.sh

# 设置yum 仓库
bash /scripts/system/after/nexus/setup_yum_proxy.sh

# 设置yum 仓库
bash /scripts/system/after/nexus/setup_npm_proxy.sh

# 将本机ip写入到
cat /etc/hosts | grep -v '^#' | grep -v '127.0.0.1' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | awk '{print $1}' >> /scripts/system/before/nexus/.lock

wait $nexus_pid
echo "############## ADD NEXUS_PROXY end #############"
