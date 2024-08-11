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

echo "############## SETUP CONFIGURE_NPM_REPO end #############"

# Nexus 服务器信息
NEXUS_URL="http://localhost:8081"
USERNAME="admin"
PASSWORD="admin123"

# 要创建的仓库列表
REPOS=(
  "npm-taobao|https://registry.npmmirror.com/"
  "npm-huawei|https://mirrors.huaweicloud.com/repository/npm/"
  "npm-tencent|http://mirrors.cloud.tencent.com/npm/"
)

# 检查仓库是否存在的函数
check_repo_exists() {
  local repo_name=$1
  echo "检查仓库 ${repo_name} 是否存在..."
  local response
  response=$(curl -s -u "${USERNAME}:${PASSWORD}" -X GET "${NEXUS_URL}/service/rest/v1/repositories/${repo_name}")
  if [[ $response == *"\"name\" : \"${repo_name}\""* ]]; then
    echo "仓库 ${repo_name} 已存在。"
    return 0
  else
    echo "仓库 ${repo_name} 不存在。"
    return 1
  fi
}

# 创建代理仓库的函数
create_proxy_repo() {
  local repo_name=$1
  local remote_url=$2
  echo "创建代理仓库 ${repo_name}，远程 URL 为 ${remote_url}..."
  local repo_config
  repo_config=$(cat <<EOF
{
  "name": "${repo_name}",
  "online": true,
  "storage": {
    "blobStoreName": "default",
    "strictContentTypeValidation": true,
    "writePolicy": "ALLOW"
  },
  "proxy": {
    "remoteUrl": "${remote_url}",
    "contentMaxAge": 1440,
    "metadataMaxAge": 1440
  },
  "negativeCache": {
    "enabled": true,
    "timeToLive": 1440
  },
  "httpClient": {
    "blocked": false,
    "autoBlock": true
  },
  "routingRuleName": "default"
}
EOF
  )
  curl -u "${USERNAME}:${PASSWORD}" -X POST "${NEXUS_URL}/service/rest/v1/repositories/npm/proxy" -H "Content-Type: application/json" -d "${repo_config}"
  echo "代理仓库 ${repo_name} 创建完成。"
}

# 检查组仓库是否存在的函数
check_group_repo_exists() {
  local group_name=$1
  echo "检查组仓库 ${group_name} 是否存在..."
  local response
  response=$(curl -s -u "${USERNAME}:${PASSWORD}" -X GET "${NEXUS_URL}/service/rest/v1/repositories/${group_name}")
  if [[ $response == *"\"name\" : \"${group_name}\""* ]]; then
    echo "组仓库 ${group_name} 已存在。"
    return 0
  else
    echo "组仓库 ${group_name} 不存在。"
    return 1
  fi
}

# 创建组仓库的函数
create_group_repo() {
  local group_name=$1
  shift
  local members=("$@")
  local member_repos=$(printf '", "%s' "${members[@]}")
  member_repos="${member_repos:3}\""  # 去掉前面的 '", "'
  echo "创建组仓库 ${group_name}，成员包括：${member_repos}..."
  local repo_config
  repo_config=$(cat <<EOF
{
  "name": "${group_name}",
  "online": true,
  "storage": {
    "blobStoreName": "default",
    "strictContentTypeValidation": true
  },
  "group": {
    "memberNames": [${member_repos}]
  }
}
EOF
  )
  curl -u "${USERNAME}:${PASSWORD}" -X POST "${NEXUS_URL}/service/rest/v1/repositories/npm/group" -H "Content-Type: application/json" -d "${repo_config}"
  echo "组仓库 ${group_name} 创建完成。"
}

# 创建代理仓库
for repo in "${REPOS[@]}"; do
  IFS='|' read -r repo_name remote_url <<< "$repo"
  if ! check_repo_exists "$repo_name"; then
    create_proxy_repo "$repo_name" "$remote_url"
  fi
done

# 创建组仓库
GROUP_NAME="npm-group"
if ! check_group_repo_exists "$GROUP_NAME"; then
  create_group_repo "$GROUP_NAME" "${REPOS[@]%%|*}"
fi

echo "############## SETUP CONFIGURE_NPM_REPO end #############"
