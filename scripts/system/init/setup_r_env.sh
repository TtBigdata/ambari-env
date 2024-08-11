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

echo "############## INSTALL R start #############"

# 定义变量
URL="https://mirrors.ustc.edu.cn/CRAN/src/base/R-4/R-4.4.1.tar.gz"
TAR_FILE="R-4.4.1.tar.gz"
DIR_NAME="R-4.4.1"
INSTALL_DIR="/usr/local/R-4.4.1"

# 检查R是否已经安装
if [ ! -d "$INSTALL_DIR" ]; then
  # 更新系统并安装必要的依赖
  sudo yum install -y gcc-gfortran readline-devel libXt-devel libX11-devel libpng-devel libjpeg-devel cairo-devel pango-devel bzip2-devel xz-devel curl-devel libicu-devel

  # 下载tar.gz文件，如果文件不存在
  if [ ! -f "$TAR_FILE" ]; then
    wget $URL -O $TAR_FILE
  else
    echo "$TAR_FILE 已存在，跳过下载。"
  fi

  # 解压文件，如果目录不存在
  if [ ! -d "$DIR_NAME" ]; then
    tar -zxvf $TAR_FILE
  else
    echo "$DIR_NAME 已存在，跳过解压缩。"
  fi

  # 进入解压后的目录并安装
  cd $DIR_NAME

  # 配置、编译和安装
  ./configure --prefix=$INSTALL_DIR
  make
  sudo make install

  # 清理下载的文件
  cd ..
  rm -rf $DIR_NAME
  rm $TAR_FILE
else
  echo "R 已安装在 $INSTALL_DIR，跳过编译。"
fi

# 检查系统路径是否已包含R安装路径，如果没有则添加到/etc/profile
if ! grep -q "R_HOME" /etc/profile; then
  echo "export R_HOME=$INSTALL_DIR" | sudo tee -a /etc/profile
  echo 'export PATH=$R_HOME/bin:$PATH' | sudo tee -a /etc/profile
else
  echo "系统路径已包含R安装路径，跳过添加。"
fi

source /etc/profile
# 验证安装
R --version

echo "############## INSTALL R end #############"

echo "############## SETUP R_ENV start #############"

source /opt/rh/devtoolset-7/enable

# 安装所需的 R 包，处理依赖包问题
REQUIRED_PACKAGES=("knitr" "rmarkdown" "devtools" "e1071" "survival" "httr2" "gh" "htmlwidgets" "usethis" "pkgdown" "profvis" "roxygen2" "testthat")
CRAN_MIRRORS="c('https://mirrors.tuna.tsinghua.edu.cn/CRAN/', 'https://mirrors.ustc.edu.cn/CRAN/', 'https://mirrors.aliyun.com/CRAN/')"

for package in "${REQUIRED_PACKAGES[@]}"; do
  Rscript -e "options(repos = $CRAN_MIRRORS); if (!requireNamespace('$package', quietly = TRUE)) tryCatch(install.packages('$package'), error = function(e) { cat('Error installing package:', '$package', '\n') })"
done

# 提示用户包安装完成
echo "所需的 R 包已安装完成。"

echo "############## SETUP R_ENV end #############"
