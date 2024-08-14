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

echo "############## BUILD BIGTOP_1_0_1 start #############"

export NEXUS_URL=$(cat /scripts/system/before/nexus/.lock)
export NEXUS_USERNAME="admin"
export NEXUS_PASSWORD="admin123"
echo $NEXUS_URL

PROJECT_PATH="/opt/modules/bigtop"

#########################
####        CI        ###
#########################

# 定义一个包含源文件和目标路径的数组
extract_files=(
  "/scripts/build/bigtop/patch1_0_1/source/package-sqoop.tar.gz:$PROJECT_PATH"
  "/scripts/build/bigtop/patch1_0_1/source/package-ranger.tar.gz:$PROJECT_PATH"
)
#清理原来的文件内容
rm -rf "${PROJECT_PATH}/bigtop-packages/src/common/ranger"
# 清理bigtop-select 因为融合了新组件
rm -rf "${PROJECT_PATH}/build/bigtop-select"  "${PROJECT_PATH}/output/bigtop-select"

# 定义一个函数来解压 .tar.gz 文件
extract_file() {
  local source_file=$1
  local destination_path=$2
  if [ -f "$source_file" ]; then
    mkdir -p "$destination_path"
    tar -xvzf "$source_file" -C "$destination_path"
    echo "文件：$source_file 已成功解压到 $destination_path"
  else
    echo "文件：$source_file 不存在"
    exit 1
  fi
}

# 遍历数组并解压每个文件
for file_pair in "${extract_files[@]}"; do
  IFS=":" read -r source_file destination_path <<<"$file_pair"
  extract_file "$source_file" "$destination_path"
done

#########################
####      PATCH       ###
#########################

# 定义一个包含所有补丁文件路径的数组
patch_files=(
  "/scripts/build/bigtop/patch1_0_1/patch0-BOM-COMPONENT-ADD.diff"
  "/scripts/build/bigtop/patch1_0_1/patch1-INTEGRATION-FOR-COMPONENT.diff"
)
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
  "/scripts/build/bigtop/patch1_0_1/child_patch/patch3-SQOOP-COMPILE-FAST.diff:$CHILD_PATH/sqoop"
  "/scripts/build/bigtop/patch1_0_1/child_patch/patch5-RANGER-FIXED-BUGS.diff:$CHILD_PATH/ranger"
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
  sqoop-rpm \
  ranger-rpm \
  -PparentDir=/usr/bigtop \
  -Dbuildwithdeps=true \
  -PpkgSuffix

# 定义要处理的目录
directories=("ranger" "sqoop" "bigtop-select")

# 遍历每个指定的目录
for dir in "${directories[@]}"; do
    # 创建目标目录
    mkdir -p "$RPM_PACKAGE/$dir"

    # 查找并复制文件
    find "$PROJECT_PATH/output/$dir" -iname '*.rpm' -not -iname '*.src.rpm' -exec cp -rv {} "$RPM_PACKAGE/$dir" \;
done

echo "############## BUILD BIGTOP_1_0_1 end #############" -d
