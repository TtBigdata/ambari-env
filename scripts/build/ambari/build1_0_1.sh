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

echo "############## BUILD AMBARI1_0_1 start #############"

#########################
####      PATCH       ###
#########################

# 定义一个包含所有补丁文件路径的数组
patch_files=(
  "/scripts/build/ambari/patch1_0_1/patch0-ADD-SQOOP-COMPONENT.diff"
)
PROJECT_PATH="/opt/modules/ambari"
RPM_PACKAGE="/data/rpm-package/ambari"

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
####      BUILD       ###
#########################

cd "$PROJECT_PATH"

#mvn -T 16 -B clean install package rpm:rpm -Drat.skip=true -Dcheckstyle.skip=true -DskipTests -Dpython.ver="python >= 2.6" -Preplaceurl -X
mvn -T 16 -B  install package rpm:rpm -Drat.skip=true -Dcheckstyle.skip=true -DskipTests -Dpython.ver="python >= 2.6" -Preplaceurl

find "$PROJECT_PATH" -iname '*.rpm' -exec cp -rv {} "$RPM_PACKAGE" \;
echo "############## BUILD AMBARI1_0_1 end #############"
