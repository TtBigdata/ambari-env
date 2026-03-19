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

echo "############## PRE BUILD_AMBARI_ALL (ARM) start #############"

PROJECT_PATH="/opt/modules/ambari3"   # 你的目标项目路径
PATCH_SCRIPT="/scripts/util/apply_patch.sh"  # 工具脚本路径
RPM_PACKAGE="/data/rpm-package/ambari3" # 目标路径

mkdir -p $RPM_PACKAGE

cd "$PROJECT_PATH"
rm -rf "$PROJECT_PATH"/* && git checkout .

# ---------- 引用统一补丁清单 ----------
# 根据脚本层级调整路径，以下是你当前目录结构下的正确写法：
source "/scripts/build/ambari3/common/patches.sh"

for patch_file in "${patch_files[@]}"; do
  "$PATCH_SCRIPT" "$PROJECT_PATH" "$patch_file"
done


# 使用jdk 17
export JAVA_HOME=/opt/modules/jdk-17.0.2
export PATH=$JAVA_HOME/bin:$PATH

java -version

mvn package install \
rpm:rpm \
-Drat.skip=true \
-Dcheckstyle.skip=true \
-Dspotbugs.skip=true \
-Pkylin10-aarch64 \
-DskipTests



find "$PROJECT_PATH" -iname '*.rpm' -exec cp -rv {} "$RPM_PACKAGE" \;


echo "############## PRE BUILD_AMBARI_ALL (ARM) end #############"
