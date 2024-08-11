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

echo "############## BUILD AMBARI-METRICS start #############"

#########################
####      PATCH       ###
#########################

# 定义一个包含所有补丁文件路径的数组
patch_files=(
  "/scripts/build/ambari-metrics/patch/patch0-TAR-DOWNLOAD.diff"
  #  "/scripts/build/ambari-infra/patch/patch1-MIRRO-REPLACE.diff"
)
PROJECT_PATH="/opt/modules/ambari-metrics"

# 定义一个函数来应用补丁
apply_patch() {
  local patch_file=$1
  if patch -p1 --dry-run -R -d "$PROJECT_PATH" <"$patch_file" >/dev/null 2>&1; then
    echo "补丁：$patch_file 已经应用，跳过"
  else
    if patch -p1 --fuzz=0 --verbose -d "$PROJECT_PATH" <"$patch_file"; then
      echo "补丁：$patch_file 已经成功执行"
    else
      echo "补丁：$patch_file 执行失败"
      exit 1
    fi
  fi
}

# 遍历数组并应用每个补丁文件
for patch_file in "${patch_files[@]}"; do
  apply_patch "$patch_file"
done

#########################
####     DOWNLOAD     ###
#########################

# 定义下载链接数组
download_urls=(
  "https://repo.huaweicloud.com/artifactory/apache-local/hbase/2.4.13/hbase-2.4.13-bin.tar.gz"
  "https://repo.huaweicloud.com/artifactory/apache-local/hadoop/common/hadoop-3.3.4/hadoop-3.3.4.tar.gz"
  "https://mirrors.huaweicloud.com/grafana/9.3.2/grafana-enterprise-9.3.2.linux-amd64.tar.gz"
  "https://mirrors.huaweicloud.com/artifactory/apache-local/phoenix/phoenix-5.1.2/phoenix-hbase-2.4-5.1.2-bin.tar.gz"
)

# 定义下载目录
DOWNLOAD_DIR="$PROJECT_PATH/ambari-download-tar"
RPM_PACKAGE="/data/rpm-package/ambari-metrics"

# 创建下载目录（如果不存在）
mkdir -p "$DOWNLOAD_DIR"
mkdir -p "$RPM_PACKAGE"

# 下载文件的函数
download_file() {
  local url=$1
  local file_name=$(basename "$url")
  local file_path="$DOWNLOAD_DIR/$file_name"

  # 检查文件是否已经存在
  if [ -f "$file_path" ]; then
    echo "文件 $file_name 已经存在，跳过下载。"
  else
    echo "正在下载 $file_name ..."
    curl -o "$file_path" "$url"
    if [ $? -eq 0 ]; then
      echo "文件 $file_name 下载成功。"
    else
      echo "文件 $file_name 下载失败。"
      exit 1
    fi
  fi
}

# 遍历下载链接并下载每个文件
for url in "${download_urls[@]}"; do
  download_file "$url"
done

#########################
####      BUILD       ###
#########################

cd "$PROJECT_PATH"
mvn -T 4C clean install -DskipTests -Drat.skip=true -Dbuild-rpm -X

find "$PROJECT_PATH" -iname '*.rpm' -exec cp -rv {} "$RPM_PACKAGE" \;

echo "############## BUILD AMBARI-METRICS end #############"
