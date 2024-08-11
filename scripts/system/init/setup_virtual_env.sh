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

echo "############## SETUP PYTHON_VIRTUAL_ENV start #############"

# 设置变量
BASE_DIR="/opt/modules/virtual_env"
PYTHON_VERSION=3.7.12
PYTHON_TAR=Python-$PYTHON_VERSION.tgz
PYTHON_SRC_DIR=Python-$PYTHON_VERSION
DOWNLOAD_URL=https://repo.huaweicloud.com/python/$PYTHON_VERSION/$PYTHON_TAR
PIP_URL="https://mirrors.aliyun.com/pypi/get-pip.py"
PIP_PATH="$BASE_DIR/get-pip.py"
VIRTUAL_ENV_PATH="$BASE_DIR/python3.7/bin/python3.7"
VIRTUALENV_DIR="$BASE_DIR/hadoop_py37"

# 创建基础目录
mkdir -p $BASE_DIR


# 安装必要的依赖
yum groupinstall -y "Development Tools"
yum install -y \
    zlib-devel \
    bzip2-devel \
    openssl-devel \
    ncurses-devel \
    sqlite-devel \
    readline-devel \
    tk-devel \
    gdbm-devel \
    db4-devel \
    libpcap-devel \
    xz-devel \
    curl \
    libffi-devel

# 下载 Python 3.7 源码
if [ ! -f $BASE_DIR/$PYTHON_TAR ]; then
    echo "Downloading Python $PYTHON_VERSION..."
    curl -o $BASE_DIR/$PYTHON_TAR $DOWNLOAD_URL
else
    echo "Python $PYTHON_TAR already downloaded."
fi

# 解压源码包
if [ ! -d $BASE_DIR/$PYTHON_SRC_DIR ]; then
    echo "Extracting Python $PYTHON_TAR..."
    tar -xf $BASE_DIR/$PYTHON_TAR -C $BASE_DIR
else
    echo "Python source directory already exists."
fi

# 进入源码目录并安装 Python 3.7
cd $BASE_DIR/$PYTHON_SRC_DIR

if ! command -v python3.7 &> /dev/null; then
    echo "Installing Python $PYTHON_VERSION..."
    ./configure --enable-optimizations
    make -j$(nproc)
    sudo make altinstall
else
    echo "Python 3.7 already installed."
fi

# 下载并安装 pip
if [ ! -f "$PIP_PATH" ]; then
    echo "Downloading get-pip.py..."
    curl -o "$PIP_PATH" "$PIP_URL"
else
    echo "get-pip file exists: $PIP_PATH"
fi

if ! command -v pip3.7 &> /dev/null; then
    echo "Installing pip..."
    sudo python3.7 "$PIP_PATH"
    pip3.7 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
    sudo python3.7 -m pip install --upgrade pip
    echo "pip 安装完毕"
else
    echo "pip already installed."
fi

# 安装 virtualenv
pip3.7 install virtualenv

# 创建虚拟环境
if [ ! -d $VIRTUALENV_DIR ]; then
    echo "Creating virtual environment..."
    python3.7 -m venv $VIRTUALENV_DIR
else
    echo "Virtual environment already exists."
fi

# 激活虚拟环境
source $VIRTUALENV_DIR/bin/activate

# 验证虚拟环境中的 Python 版本
PYTHON_VERSION_ACTUAL=$(python --version)
echo "虚拟环境中的 Python 版本是: $PYTHON_VERSION_ACTUAL"

# 提示用户虚拟环境已激活
#echo "虚拟环境已激活。要退出虚拟环境，请运行 'deactivate' 命令。"

# 保持虚拟环境激活状态
#$SHELL

echo "############## SETUP PYTHON_VIRTUAL_ENV end #############"