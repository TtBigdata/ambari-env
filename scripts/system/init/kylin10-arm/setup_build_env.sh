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

echo "############## SETUP BUILD_ENV (ARM) start #############"

CMAKE_URL="https://ghfast.top/https://github.com/Kitware/CMake/releases/download/v3.30.0/cmake-3.30.0-linux-aarch64.sh"
CMAKE="/opt/modules/cmake3.sh"
CMAKE_HOME_PATH="/opt/modules/cmake3"
mkdir -p "/opt/modules/cmake3"


dnf install -y abseil-cpp abseil-cpp-devel ninja-build

# 卸载旧的cmake
dnf -y remove cmake cmake3

configure_cmake_home() {
  # Update or add CMAKE_HOME variable using sed
  if grep -q "^export CMAKE_HOME=" /etc/profile; then
    sudo sed -i "s#^export CMAKE_HOME=.*#export CMAKE_HOME=${CMAKE_HOME_PATH}#" /etc/profile
  else
    echo "export CMAKE_HOME=${CMAKE_HOME_PATH}" | sudo tee -a /etc/profile
  fi

  # Update PATH variable to include CMAKE_HOME/bin
  if ! grep -q "^export PATH=.*\$CMAKE_HOME/bin" /etc/profile; then
    echo "export PATH=\$PATH:\$CMAKE_HOME/bin" | sudo tee -a /etc/profile
  fi

  # Reload /etc/profile to apply changes
  source /etc/profile

  # Verify CMAKE_HOME setting
  echo "CMAKE_HOME is set to: $CMAKE_HOME_PATH"
}

if [ -f "$CMAKE" ]; then
  echo "cmake3 file exists: $CMAKE"
else
  curl -o "$CMAKE" "$CMAKE_URL"
  bash "$CMAKE" --skip-license --prefix="$CMAKE_HOME_PATH"
  configure_cmake_home
  echo "cmake3 安装完毕#"
fi

echo "############## SETUP BUILD_ENV (ARM) end #############"
