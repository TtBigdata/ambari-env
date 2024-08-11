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

echo "############## SETUP CONFIGURE_YUM_REPO start #############"

# Nexus 服务器信息
NEXUS_URL="http://localhost:8081"
USERNAME="admin"
PASSWORD="admin123"

# 要创建的仓库列表
REPOS=(
  "yum-huawei|https://repo.huaweicloud.com/centos/"
  "yum-aliyun|https://mirrors.aliyun.com/centos/"
  "yum-aliyun-epel|https://mirrors.aliyun.com/epel/"
  "yum-aliyun-mariadb|https://mirrors.aliyun.com/mariadb/"
)

# 检查仓库是否存在的函数
check_repo_exists() {
  local repo_name=$1
  local response
  response=$(curl -s -u "${USERNAME}:${PASSWORD}" -X GET "${NEXUS_URL}/service/rest/v1/repositories/${repo_name}")
  [[ $response == *"\"name\" : \"${repo_name}\""* ]]
}

# 创建代理仓库的函数
create_proxy_repo() {
  local repo_name=$1
  local remote_url=$2
  local repo_config

  repo_config=$(
    cat <<EOF
{
  "name": "${repo_name}",
  "online": true,
  "storage": {
    "blobStoreName": "default",
    "strictContentTypeValidation": true
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
  }
}
EOF
  )

  curl -u "${USERNAME}:${PASSWORD}" -X POST "${NEXUS_URL}/service/rest/v1/repositories/yum/proxy" \
    -H "Content-Type: application/json" \
    -d "${repo_config}"
}

# 获取组仓库成员的函数
get_group_members() {
  local repo_name=$1
  curl -s -u "${USERNAME}:${PASSWORD}" -X GET "${NEXUS_URL}/service/rest/v1/repositories/${repo_name}" | grep -oP '"memberNames" : \[\K[^\]]+' | tr -d '"' | tr ',' '\n'
}

# 创建组仓库的函数
create_group_repo() {
  local repo_name=$1
  shift
  local members=("$@")
  local members_json=$(printf '"%s",' "${members[@]}")
  members_json="[${members_json%,}]"

  local repo_config

  repo_config=$(
    cat <<EOF
{
  "name": "${repo_name}",
  "online": true,
  "storage": {
    "blobStoreName": "default",
    "strictContentTypeValidation": true
  },
  "group": {
    "memberNames": ${members_json}
  }
}
EOF
  )

  curl -u "${USERNAME}:${PASSWORD}" -X POST "${NEXUS_URL}/service/rest/v1/repositories/yum/group" \
    -H "Content-Type: application/json" \
    -d "${repo_config}"
}

# 更新组仓库成员的函数
update_group_repo_members() {
  local repo_name=$1
  shift
  local new_members=("$@")
  local existing_members=()

  if check_repo_exists "${repo_name}"; then
    existing_members=($(get_group_members "${repo_name}"))
  fi

  local all_members=("${existing_members[@]}" "${new_members[@]}")
  local unique_members=($(echo "${all_members[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

  local members_json=$(printf '"%s",' "${unique_members[@]}")
  members_json="[${members_json%,}]"

  local repo_config

  repo_config=$(
    cat <<EOF
{
  "name": "${repo_name}",
  "online": true,
  "storage": {
    "blobStoreName": "default",
    "strictContentTypeValidation": true
  },
  "group": {
    "memberNames": ${members_json}
  }
}
EOF
  )

  curl -u "${USERNAME}:${PASSWORD}" -X PUT "${NEXUS_URL}/service/rest/v1/repositories/yum/group/${repo_name}" \
    -H "Content-Type: application/json" \
    -d "${repo_config}"
}

# 创建代理仓库
for repo in "${REPOS[@]}"; do
  IFS="|" read -r repo_name remote_url <<<"${repo}"
  if check_repo_exists "${repo_name}"; then
    echo "仓库 ${repo_name} 已存在。"
  else
    echo "正在创建代理仓库 ${repo_name}..."
    create_proxy_repo "${repo_name}" "${remote_url}"
  fi
done

# 创建或更新组仓库
GROUP_REPO="yum-public"
GROUP_MEMBERS=("yum-huawei" "yum-aliyun-epel" "yum-aliyun" "yum-aliyun-mariadb")

if check_repo_exists "${GROUP_REPO}"; then
  echo "组仓库 ${GROUP_REPO} 已存在，正在更新成员..."
  update_group_repo_members "${GROUP_REPO}" "${GROUP_MEMBERS[@]}"
else
  echo "组仓库 ${GROUP_REPO} 不存在，正在创建..."
  create_group_repo "${GROUP_REPO}" "${GROUP_MEMBERS[@]}"
fi

echo "仓库创建成功。"
echo "############## SETUP CONFIGURE_YUM_REPO end #############"
