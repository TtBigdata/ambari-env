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

###########MAVEN_INIT start
echo "############## SETUP MAVEN_INIT start #############"
# Maven path and URL
MAVEN_VERSION="3.8.4"
MAVEN_FILE_PATH="/opt/modules/apache-maven-${MAVEN_VERSION}-bin.tar.gz"
MAVEN_HOME_PATH="/opt/modules/apache-maven-${MAVEN_VERSION}"
MAVEN_DOWNLOAD_URL="https://repo.huaweicloud.com/apache/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz"
MAVEN_FILE_PATH_LOCK="/scripts/.setup_maven.lock"
TAR_LOCK="/scripts/.setup_maven_tar.lock"

# 解压缩函数
extract_tar_gz() {
  local file_path=$1
  local dest_dir=$2

  if [ -f "$TAR_LOCK" ]; then
    return
  else
    touch $TAR_LOCK
  fi

  echo "Extracting file $file_path to directory $dest_dir..."
  tar -zxvf "$file_path" -C "$dest_dir"

  if [ $? -eq 0 ]; then
    echo "File extracted successfully: $dest_dir"
  else
    echo "File extraction failed"
    exit 1
  fi
  rm -f $TAR_LOCK
}

# 配置 MAVEN_HOME 函数
configure_maven_home() {
  # 使用 sed 命令更新或添加 MAVEN_HOME 变量
  if grep -q "^export MAVEN_HOME=" /etc/profile; then
    sudo sed -i "s#^export MAVEN_HOME=.*#export MAVEN_HOME=${MAVEN_HOME_PATH}#" /etc/profile
  else
    echo "export MAVEN_HOME=${MAVEN_HOME_PATH}" | sudo tee -a /etc/profile
  fi

  # 更新 PATH 变量，将 MAVEN_HOME/bin 放在前面
  if ! grep -q "^export PATH=.*\$MAVEN_HOME/bin" /etc/profile; then
    echo "export PATH=\$MAVEN_HOME/bin:\$PATH" | sudo tee -a /etc/profile
  fi

  # 重新加载 /etc/profile 文件以应用更改
  source /etc/profile

  # 验证 MAVEN_HOME 设置
  echo "MAVEN_HOME is set to: $MAVEN_HOME"
}


# 检查并下载 Maven 文件
check_and_download_maven() {
  if [ -f "$MAVEN_FILE_PATH" ]; then
    echo "Maven file exists: $MAVEN_FILE_PATH"
  elif [ -f "$MAVEN_FILE_PATH_LOCK" ]; then
    echo "Other instance downloading..."
  else
    touch $MAVEN_FILE_PATH_LOCK
    echo "Maven file does not exist, downloading..."
    mkdir -p "$(dirname "$MAVEN_FILE_PATH")"
    curl -o "$MAVEN_FILE_PATH" "$MAVEN_DOWNLOAD_URL"

    if [ $? -eq 0 ]; then
      echo "Maven download success: $MAVEN_FILE_PATH"
      extract_tar_gz "$MAVEN_FILE_PATH" "/opt/modules"
    else
      echo "Maven download failed!!"
      rm -f $MAVEN_FILE_PATH_LOCK
      exit 1
    fi
    rm -f $MAVEN_FILE_PATH_LOCK
  fi

  while [ -f "$MAVEN_FILE_PATH_LOCK" ]; do
    echo "Waiting for the lock to be released..."
    sleep 1
  done

  echo "Lock released. Continuing..."
}

main() {
  check_and_download_maven

  if [ -d "$MAVEN_HOME_PATH" ]; then
    echo "Maven home exists: $MAVEN_HOME_PATH"
  else
    extract_tar_gz "$MAVEN_FILE_PATH" "/opt/modules"
  fi

  configure_maven_home
}

main

###########MAVEN_INIT end
echo "############## SETUP MAVEN_INIT end #############"
