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

echo "############## SETUP CONFIGURE_REPO start #############"

# Nexus server information
NEXUS_URL="http://localhost:8081"
USERNAME="admin"
PASSWORD="admin123"

# List of repositories to create
REPOS=(
  "aliyun|https://maven.aliyun.com/repository/public"
  "cloudera-mirror|https://repository.cloudera.com/repository/cloudera-mirror"
  "apache-snapshot1|https://repository.apache.org/content/repositories/snapshots/"
  "apache-snapshot2|https://repository.apache.org/service/local/repositories/snapshots/content/"
  "cloudera-release|https://repository.cloudera.com/content/repositories/releases/"
  "cloudera-staging|https://repository.cloudera.com/content/repositories/staging/"
  "confluent|https://packages.confluent.io/maven"
  "conjars|https://conjars.wensel.net/repo/"
  "cloudera-libs|https://repository.cloudera.com/repository/libs-release-local/"
  "datanucleus|https://www.datanucleus.org/downloads/maven2/"
  "aliyun-spring-plugin|https://maven.aliyun.com/repository/spring-plugin"
  "huawei|https://repo.huaweicloud.com/repository/maven"
)

# Function to check if a repository exists
check_repo_exists() {
  local repo_name=$1
  local response
  response=$(curl -s -u "${USERNAME}:${PASSWORD}" -X GET "${NEXUS_URL}/service/rest/v1/repositories/${repo_name}")
  [[ $response == *"\"name\" : \"${repo_name}\""* ]]
}

# Function to create a proxy repository
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
  },
  "maven": {
    "versionPolicy": "MIXED",
    "layoutPolicy": "STRICT"
  },
  "format": "maven2",
  "type": "proxy"
}
EOF
  )
  curl -u "${USERNAME}:${PASSWORD}" -X POST "${NEXUS_URL}/service/rest/v1/repositories/maven/proxy" \
    -H "Content-Type: application/json" \
    -d "${repo_config}"
}

# Function to get the current maven-public group configuration
get_group_config() {
  curl -s -u "${USERNAME}:${PASSWORD}" -X GET "${NEXUS_URL}/service/rest/v1/repositories/maven/group/maven-public"
}

# Function to update the maven-public group configuration
update_group_config() {
  local group_config=$1
  curl -u "${USERNAME}:${PASSWORD}" -X PUT "${NEXUS_URL}/service/rest/v1/repositories/maven/group/maven-public" \
    -H "Content-Type: application/json" \
    -d "${group_config}"
}

# Main program
for repo in "${REPOS[@]}"; do
  IFS='|' read -r repo_name remote_url <<<"$repo"
  if check_repo_exists "${repo_name}"; then
    echo "仓库 ${repo_name} 已存在，不需要创建。"
  else
    echo "创建仓库 ${repo_name}..."
    create_proxy_repo "${repo_name}" "${remote_url}"
    echo "仓库 ${repo_name} 创建成功。"
  fi
done

# Get the current maven-public group configuration
group_config=$(get_group_config)

# Check and add repositories to the maven-public group
for repo in "${REPOS[@]}"; do
  IFS='|' read -r repo_name remote_url <<<"$repo"
  if [[ ${group_config} != *"${repo_name}"* ]]; then
    echo "将仓库 ${repo_name} 添加到maven-public组中..."
    group_config=$(echo "${group_config}" | sed "s/\"memberNames\" : \[/\"memberNames\" : \[\"${repo_name}\",/")
  else
    echo "仓库 ${repo_name} 已经在maven-public组中。"
  fi
done

# Update the maven-public group configuration
update_group_config "${group_config}"
echo "所有仓库已添加到maven-public组中。"

echo "############## SETUP CONFIGURE_REPO end #############"
