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

###########GRADLE_INIT start
echo "############## SETUP GRADLE_INIT start #############"

# Gradle version and paths
GRADLE_VERSION="5.6.4"
GRADLE_FILE_PATH="/opt/modules/gradle-${GRADLE_VERSION}-bin.zip"
GRADLE_HOME_PATH="/opt/modules/gradle-${GRADLE_VERSION}"
GRADLE_DOWNLOAD_URL="https://mirrors.huaweicloud.com/gradle/gradle-${GRADLE_VERSION}-bin.zip"
GRADLE_FILE_PATH_LOCK="/scripts/.setup_gradle.lock"
ZIP_LOCK="/scripts/.setup_gradle_zip.lock"

# Function to extract zip files
extract_zip() {
  local file_path=$1
  local dest_dir=$2

  if [ -f "$ZIP_LOCK" ]; then
    return
  else
    touch $ZIP_LOCK
  fi

  echo "Extracting file $file_path to directory $dest_dir..."
  unzip "$file_path" -d "$dest_dir"

  if [ $? -eq 0 ]; then
    echo "File extracted successfully: $dest_dir"
  else
    echo "File extraction failed"
    exit 1
  fi

  rm -f $ZIP_LOCK
}

# Function to configure GRADLE_HOME
configure_gradle_home() {
  # Update or add GRADLE_HOME variable using sed
  if grep -q "^export GRADLE_HOME=" /etc/profile; then
    sudo sed -i "s#^export GRADLE_HOME=.*#export GRADLE_HOME=${GRADLE_HOME_PATH}#" /etc/profile
  else
    echo "export GRADLE_HOME=${GRADLE_HOME_PATH}" | sudo tee -a /etc/profile
  fi

  # Update PATH variable to include GRADLE_HOME/bin
  if ! grep -q "^export PATH=.*\$GRADLE_HOME/bin" /etc/profile; then
    echo "export PATH=\$PATH:\$GRADLE_HOME/bin" | sudo tee -a /etc/profile
  fi

  # Reload /etc/profile to apply changes
  source /etc/profile

  # Verify GRADLE_HOME setting
  echo "GRADLE_HOME is set to: $GRADLE_HOME"
}

# Function to check and download Gradle file
check_and_download_gradle() {
  if [ -f "$GRADLE_FILE_PATH" ]; then
    echo "Gradle file exists: $GRADLE_FILE_PATH"
  elif [ -f "$GRADLE_FILE_PATH_LOCK" ]; then
    echo "Other instance downloading..."
  else
    touch $GRADLE_FILE_PATH_LOCK
    echo "Gradle file does not exist, downloading..."
    mkdir -p "$(dirname "$GRADLE_FILE_PATH")"
    curl -o "$GRADLE_FILE_PATH" "$GRADLE_DOWNLOAD_URL"
    if [ $? -eq 0 ]; then
      echo "Gradle download success: $GRADLE_FILE_PATH"
      extract_zip "$GRADLE_FILE_PATH" "/opt/modules"
    else
      echo "Gradle download failed!!"
      rm -f $GRADLE_FILE_PATH_LOCK
      exit 1
    fi
    rm -f $GRADLE_FILE_PATH_LOCK
  fi

  while [ -f "$GRADLE_FILE_PATH_LOCK" ]; do
    echo "Waiting for the lock to be released..."
    sleep 1
  done

  echo "Lock released. Continuing..."
}

main() {
  check_and_download_gradle

  if [ -d "$GRADLE_HOME_PATH" ]; then
    echo "Gradle home exists: $GRADLE_HOME_PATH"
  else
    extract_zip "$GRADLE_FILE_PATH" "/opt/modules"
  fi

  configure_gradle_home
}

main

###########GRADLE_INIT end
echo "############## SETUP GRADLE_INIT end #############"
