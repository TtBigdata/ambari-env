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

echo "############## SETUP BUILD_ENV start #############"

CMAKE_URL="https://ghp.ci/https://github.com/Kitware/CMake/releases/download/v3.30.0/cmake-3.30.0-linux-x86_64.sh"
CMAKE="/opt/modules/cmake3.sh"
CMAKE_HOME_PATH="/opt/modules/cmake3"
mkdir -p "/opt/modules/cmake3"
# 使用数组来管理要安装的包
packages=(
  apr-devel
  bison
  bzip2-devel
  cppunit-devel
  cyrus-*
  devtoolset-7-gcc
  devtoolset-7-gcc-c++.x86_64
  flex
  freetype-devel
  fribidi-devel
  fuse
  fuse-devel
  gcc-c++
  gzip
  harfbuzz-devel
  knitr
  libcurl-devel
  libevent-devel
  libgit2-devel
  libjpeg-turbo-devel
  libpng-devel
  libtiff-devel
  libtool
  libxml2-devel
  lzo-devel
  ncurses-devel
  openssl-devel
  openblas-devel
  pandoc*
  protobuf*
  python-devel
  R*
  readline-devel
  rpm-build
  zstd*
  asciidoc
  xmlto
)

# 使用单个 yum 命令安装所有包
yum -y install "${packages[@]}"
# 卸载旧的cmake
yum -y remove cmake cmake3
# 启动gcc 高版本
source /opt/rh/devtoolset-7/enable

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

echo "############## SETUP BULID_ENV end #############"
