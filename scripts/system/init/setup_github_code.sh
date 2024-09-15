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
echo "############## SETUP GITHUB_CODE_DOWNLOAD start #############"
# 目标目录和分支版本
declare -A REPOS=(
  ["/opt/modules/ambari"]="branch-2.8 https://ghp.ci/https://github.com/apache/ambari.git"
  ["/opt/modules/ambari-metrics"]="branch-3.0 https://ghp.ci/https://github.com/apache/ambari-metrics.git"
  ["/opt/modules/bigtop"]="release-3.2.0 https://ghp.ci/https://github.com/apache/bigtop.git"
  ["/opt/modules/ambari-infra"]="master https://ghp.ci/https://github.com/apache/ambari-infra.git"
)

# 创建目标目录的父目录
mkdir -p /opt/modules

# 遍历每个仓库配置
for TARGET_DIR in "${!REPOS[@]}"; do
  IFS=' ' read -r BRANCH_VERSION REPO_URL <<<"${REPOS[$TARGET_DIR]}"

  # 提取仓库名称
  REPO_NAME=$(basename -s .git "$REPO_URL")

  # 检查目标目录是否存在
  if [ -d "$TARGET_DIR" ]; then
    echo "目录已存在: $TARGET_DIR"
  else
    echo "正在处理仓库: $REPO_NAME"
    echo "目录不存在，正在检出仓库到 $TARGET_DIR..."
    # 检出仓库
    git clone -b "$BRANCH_VERSION" "$REPO_URL" "$TARGET_DIR"
    if [ $? -eq 0 ]; then
      echo "仓库检出成功: $TARGET_DIR"
    else
      echo "仓库检出失败: $TARGET_DIR"
      exit 1
    fi
  fi
done
echo "############## SETUP GITHUB_CODE_DOWNLOAD end #############"
