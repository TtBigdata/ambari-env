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

echo "############## BUILD BIGTOP start #############"

export NEXUS_URL=$(cat /scripts/system/before/nexus/.lock)
export NEXUS_USERNAME="admin"
export NEXUS_PASSWORD="admin123"
echo $NEXUS_URL
#########################
####      PATCH       ###
#########################

# 定义一个包含所有补丁文件路径的数组
patch_files=(
  "/scripts/build/bigtop/patch/patch0-BOM-MIRROR-FIXED.diff"
  "/scripts/build/bigtop/patch/patch1-HADOOP-FIXED.diff"
  "/scripts/build/bigtop/patch/patch2-FLINK-FIXED.diff"
  "/scripts/build/bigtop/patch/patch3-KAFKA-FIXED.diff"
  "/scripts/build/bigtop/patch/patch4-SOLR-FIXED.diff"
  "/scripts/build/bigtop/patch/patch5-TEZ-FIXED.diff"
  "/scripts/build/bigtop/patch/patch6-ZEPPELIN-FIXED.diff"
)
PROJECT_PATH="/opt/modules/bigtop"
RPM_PACKAGE="/data/rpm-package/bigtop"

mkdir -p "$RPM_PACKAGE"

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
####   CHILD_PATCH    ###
#########################

CHILD_PATH="$PROJECT_PATH/bigtop-packages/src/common"

# 定义一个包含源文件和目标路径的数组
copy_files=(
  "/scripts/build/bigtop/patch/child_patch/patch10-HADOOP-COMPILE-FAST.diff:$CHILD_PATH/hadoop"
  "/scripts/build/bigtop/patch/child_patch/patch0-FLINK-COMPILE-FAST.diff:$CHILD_PATH/flink"
  "/scripts/build/bigtop/patch/child_patch/patch2-KAFKA-COMPILE-FAST.diff:$CHILD_PATH/kafka"
  "/scripts/build/bigtop/patch/source/hadoop/yarn-ui-bower.tar.gz:$CHILD_PATH/hadoop"
  "/scripts/build/bigtop/patch/child_patch/patch0-SOLR-COMPILE-FAST.diff:$CHILD_PATH/solr"
  "/scripts/build/bigtop/patch/child_patch/patch6-TEZ-COMPILE-FAST.diff:$CHILD_PATH/tez"
  "/scripts/build/bigtop/patch/child_patch/patch3-ZEPPELIN-COMPILE-FAST.diff:$CHILD_PATH/zeppelin"
  "/scripts/build/bigtop/patch/child_patch/patch2-LIVY-COMPILE-FAST.diff:$CHILD_PATH/livy"
)

# 定义一个函数来复制文件
copy_file() {
  local source_file=$1
  local destination_path=$2
  if [ -f "$source_file" ]; then
    cp -v "$source_file" "$destination_path"
    echo "文件：$source_file 已成功复制到 $destination_path"
  else
    echo "文件：$source_file 不存在"
    exit 1
  fi
}

# 遍历数组并复制每个文件
for file_pair in "${copy_files[@]}"; do
  IFS=":" read -r source_file destination_path <<<"$file_pair"
  copy_file "$source_file" "$destination_path"
done

#########################
####      BUILD       ###
#########################

# 开启 gcc 高版本
source /opt/rh/devtoolset-7/enable

cd "$PROJECT_PATH"
gradle \
  bigtop-groovy-rpm \
  bigtop-jsvc-rpm \
  bigtop-select-rpm \
  bigtop-utils-rpm \
  zookeeper-rpm \
  hadoop-rpm \
  flink-rpm \
  hbase-rpm \
  hive-rpm \
  kafka-rpm \
  spark-rpm \
  solr-rpm \
  tez-rpm \
  zeppelin-rpm \
  livy-rpm \
  -PparentDir=/usr/bigtop \
  -Dbuildwithdeps=true \
  -PpkgSuffix

find "$PROJECT_PATH"/output/*/ -iname '*.rpm' -not -iname '*.src.rpm' -exec cp -rv {} "$RPM_PACKAGE" \;
echo "############## BUILD BIGTOP end #############"
