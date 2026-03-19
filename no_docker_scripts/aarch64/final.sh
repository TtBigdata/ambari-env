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
# ARM64 对应版本：适配 Kylin V10 aarch64（glibc 2.28）
# 与 x86 版本的关键差异：
#   1. pandoc 使用 linux-arm64 二进制
#   2. TeX Live 使用系统包（glibc 2.28 < 2.29，官方 TeX Live 2024 二进制不兼容）
#   3. TeX Live bin 路径为 aarch64-linux
#   4. libgit2 需从源码编译（系统 0.27.8 过旧，gert 要求 ≥1.0）
#   5. R_LIBS_USER 使用 aarch64 路径

set -euo pipefail

# =====[0] 变量 =====
DOWNLOAD_DIR="/opt/modules"

# R
R_VER="4.4.2"
R_TARBALL="R-${R_VER}.tar.gz"
R_URL="https://mirrors.tuna.tsinghua.edu.cn/CRAN/src/base/R-4/${R_TARBALL}"
R_SRC_DIR="${DOWNLOAD_DIR}/R-${R_VER}"
R_PREFIX="/usr/local/R-${R_VER}"

# pandoc（ARM64 二进制）
PANDOC_VER="${PANDOC_VER:-3.1.13}"
PANDOC_TGZ="pandoc-${PANDOC_VER}-linux-arm64.tar.gz"
PANDOC_URL="https://github.com/jgm/pandoc/releases/download/${PANDOC_VER}/${PANDOC_TGZ}"
PANDOC_PREFIX="/usr/local/pandoc-${PANDOC_VER}"

# libgit2（源码编译，系统版本 0.27.8 过旧）
LIBGIT2_VER="1.7.2"
LIBGIT2_TGZ="libgit2-${LIBGIT2_VER}.tar.gz"
LIBGIT2_URL="https://github.com/libgit2/libgit2/archive/refs/tags/v${LIBGIT2_VER}.tar.gz"
LIBGIT2_SRC="${DOWNLOAD_DIR}/libgit2-${LIBGIT2_VER}"

# cmake（来自 /opt/modules/cmake3，用于编译 libgit2）
CMAKE_BIN="/opt/modules/cmake3/bin/cmake"

# TeX Live：glibc 2.28 不支持官方 TeX Live 2024 二进制，使用系统包
# 系统已有 TeX Live 2018 via dnf，pdflatex 在 /usr/bin/pdflatex

# CRAN 镜像
CRAN_MIRRORS="c('https://mirrors.tuna.tsinghua.edu.cn/CRAN/','https://mirrors.ustc.edu.cn/CRAN/','https://mirrors.aliyun.com/CRAN/')"

# =====[1] 前置检查与目录 =====
if ! command -v dnf >/dev/null 2>&1; then
  echo "未发现 dnf（Kylin V10 应有），退出"; exit 1
fi
if [ "$(uname -m)" != "aarch64" ]; then
  echo "警告：当前架构为 $(uname -m)，本脚本专为 aarch64 设计"
fi
sudo mkdir -p "$DOWNLOAD_DIR"
sudo chown "$(id -u)":"$(id -g)" "$DOWNLOAD_DIR"

# =====[2] 基础依赖 =====
echo ">>> 安装基础开发依赖..."
BASE_DEPS=(
  gcc gcc-c++ gcc-gfortran
  make which tar curl
  pkgconf-pkg-config
  readline-devel zlib-devel bzip2-devel xz-devel
  pcre2-devel libicu-devel libcurl-devel
  libX11-devel libXt-devel
  cairo-devel pango-devel
  libpng-devel libjpeg-turbo-devel libtiff-devel
  freetype-devel fontconfig-devel
  libwebp-devel
  harfbuzz-devel fribidi-devel
  openssl-devel libgit2-devel
  qpdf tidy
)
MATH_DEPS=( openblas-devel lapack-devel )

sudo dnf -y install "${BASE_DEPS[@]}" || true
sudo dnf -y install "${MATH_DEPS[@]}" || true
sudo dnf -y install ca-certificates openssl || true
sudo update-ca-trust || true

# =====[3] pandoc（系统包优先，失败则 ARM64 官方二进制）=====
ensure_pandoc_sys() {
  if dnf -q list pandoc >/dev/null 2>&1; then
    sudo dnf -y install pandoc && return 0
  fi
  return 1
}
ensure_pandoc_bin() {
  if command -v pandoc >/dev/null 2>&1; then return 0; fi
  echo ">>> 使用 ARM64 官方二进制安装 pandoc ${PANDOC_VER}"
  cd "$DOWNLOAD_DIR"
  rm -f "$PANDOC_TGZ"
  curl -L --retry 5 --retry-delay 2 --tlsv1.2 -o "$PANDOC_TGZ" "$PANDOC_URL"
  [ -s "$PANDOC_TGZ" ] || { echo "pandoc 包下载失败"; exit 1; }
  sudo rm -rf "$PANDOC_PREFIX"
  sudo tar -xzf "$PANDOC_TGZ" -C /usr/local
  if ! grep -q "PANDOC_HOME=${PANDOC_PREFIX}" /etc/profile 2>/dev/null; then
    echo "export PANDOC_HOME=${PANDOC_PREFIX}" | sudo tee -a /etc/profile >/dev/null
    echo 'export PATH=$PANDOC_HOME/bin:$PATH' | sudo tee -a /etc/profile >/dev/null
  fi
  export PATH="$PANDOC_PREFIX/bin:$PATH"
  pandoc -v | head -n1
}
echo ">>> 安装 pandoc..."
if ! command -v pandoc >/dev/null 2>&1; then
  ensure_pandoc_sys || ensure_pandoc_bin
else
  echo "pandoc 已存在：$(pandoc -v | head -n1)"
fi

# =====[4] TeX Live（使用系统包，不使用官方 install-tl）=====
# 原因：glibc 2.28 < 2.29，TeX Live 2024 官方二进制（aarch64-linux）不兼容
# 系统 TeX Live 2018 的 pdflatex 可正常使用
echo ">>> 安装 TeX Live（系统包）..."
TL_PKGS=(
  texlive texlive-latex texlive-latex-bin
  texlive-amsmath texlive-collection-basic
  texlive-collection-latex texlive-collection-latexrecommended
  texlive-collection-fontsrecommended texlive-collection-langenglish
  texlive-scheme-basic
)
for p in "${TL_PKGS[@]}"; do
  sudo dnf -y install "$p" 2>/dev/null || true
done

# 禁用 TeX Live 2024 aarch64 二进制（需要 glibc 2.29，系统只有 2.28）
# 防止其被加入 PATH 后覆盖系统 /usr/bin/pdflatex，导致 R CMD check 报 GLIBC 错误
TL2024_BIN="/opt/texlive/2024/bin/aarch64-linux"
if [ -d "$TL2024_BIN" ]; then
  echo ">>> 禁用不兼容的 TeX Live 2024 aarch64 二进制..."
  for bin in pdflatex pdftex latex luatex xetex bibtex; do
    [ -f "${TL2024_BIN}/${bin}" ] && \
      sudo mv "${TL2024_BIN}/${bin}" "${TL2024_BIN}/${bin}.glibc229.disabled" && \
      echo "  已禁用：${bin}" || true
  done
fi

if command -v pdflatex >/dev/null 2>&1; then
  echo "pdflatex 可用：$(pdflatex --version | head -1)"
else
  echo "警告：pdflatex 未找到，R 包 PDF 手册构建可能受影响"
fi

# =====[5] libgit2（从源码编译 1.7.2，系统 0.27.8 过旧）=====
# gert/usethis/devtools 依赖 libgit2 >= 1.0
ensure_libgit2() {
  local cur_ver
  cur_ver=$(PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig:${PKG_CONFIG_PATH:-} pkg-config --modversion libgit2 2>/dev/null || echo "0")
  # 如果已经是 1.x+ 则跳过
  if [[ "$cur_ver" == 1.* ]] || [[ "$cur_ver" == 2.* ]]; then
    echo "libgit2 ${cur_ver} 已满足要求，跳过编译"
    return 0
  fi

  echo ">>> 编译安装 libgit2 ${LIBGIT2_VER}（系统版本 ${cur_ver} 过旧）..."
  cd "$DOWNLOAD_DIR"
  if [ ! -f "$LIBGIT2_TGZ" ]; then
    curl -L --retry 5 --retry-delay 2 --tlsv1.2 -o "$LIBGIT2_TGZ" "$LIBGIT2_URL"
  fi
  [ -s "$LIBGIT2_TGZ" ] || { echo "libgit2 下载失败"; exit 1; }
  rm -rf "$LIBGIT2_SRC"
  tar -xzf "$LIBGIT2_TGZ" -C "$DOWNLOAD_DIR"
  mkdir -p "${LIBGIT2_SRC}/build"
  cd "${LIBGIT2_SRC}/build"
  "$CMAKE_BIN" .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DBUILD_TESTS=OFF \
    -DBUILD_CLI=OFF
  make -j"$(nproc)"
  sudo make install

  # 更新链接器缓存
  echo "/usr/local/lib64" | sudo tee /etc/ld.so.conf.d/local-lib64.conf >/dev/null
  sudo ldconfig

  local new_ver
  new_ver=$(PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig:${PKG_CONFIG_PATH:-} pkg-config --modversion libgit2 2>/dev/null || echo "unknown")
  echo "libgit2 安装完成：${new_ver}"
}
ensure_libgit2

# =====[6] 编译安装 R =====
echo ">>> 下载并编译 R-${R_VER}..."
cd "$DOWNLOAD_DIR"
if [ ! -f "$R_TARBALL" ]; then
  curl -L --retry 5 --retry-delay 2 --tlsv1.2 -o "$R_TARBALL" "$R_URL"
fi
rm -rf "$R_SRC_DIR"; tar -xzf "$R_TARBALL" -C "$DOWNLOAD_DIR"

cd "$R_SRC_DIR"
CFG=( "--prefix=$R_PREFIX" )
if rpm -q openblas-devel >/dev/null 2>&1 || ls /usr/lib*/libopenblas.* >/dev/null 2>&1; then
  CFG+=( --with-blas --with-lapack )
fi
./configure "${CFG[@]}"
make -j"$(nproc)"
sudo make install

if ! grep -q "R_HOME=$R_PREFIX" /etc/profile 2>/dev/null; then
  echo "export R_HOME=$R_PREFIX" | sudo tee -a /etc/profile >/dev/null
  echo 'export PATH=$R_HOME/bin:$PATH' | sudo tee -a /etc/profile >/dev/null
fi

# =====[7] 安装常用 R 包 =====
echo ">>> 安装常用 R 包（ragg/pkgdown/devtools 等）..."
export PATH="$R_PREFIX/bin:${PANDOC_PREFIX}/bin:$PATH"
export PKG_CONFIG_PATH="/usr/local/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"

Rscript -e "
Sys.setenv(PKG_CONFIG_PATH=paste0('/usr/local/lib64/pkgconfig:', Sys.getenv('PKG_CONFIG_PATH')))
options(repos=$CRAN_MIRRORS, Ncpus=parallel::detectCores())
Sys.setenv(R_REMOTES_NO_ERRORS_FROM_WARNINGS='true')
pkgs <- c('ragg','pkgdown','devtools','knitr','rmarkdown','e1071','survival','httr2','gh','htmlwidgets','usethis','profvis','roxygen2','testthat')
need <- pkgs[!suppressWarnings(sapply(pkgs, function(p) requireNamespace(p, quietly=TRUE)))]
if (length(need)) install.packages(need) else message('All required packages already installed.')
"

# =====[8] 最终验证 =====
echo ">>> 验证版本："
echo "- R 版本：$(R --version | head -n1)"
echo "- pandoc 版本：$(pandoc -v | head -n1 2>/dev/null || echo '未检测到')"
echo "- pdflatex 可用：$(command -v pdflatex >/dev/null 2>&1 && pdflatex --version | head -1 || echo '未检测到')"
echo "- libgit2 版本：$(PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig:${PKG_CONFIG_PATH:-} pkg-config --modversion libgit2 2>/dev/null || echo '未检测到')"

Rscript -e "
pkgs <- c('ragg','pkgdown','devtools','knitr','rmarkdown','e1071','survival','httr2','gh','htmlwidgets','usethis','profvis','roxygen2','testthat')
installed <- rownames(installed.packages())
have <- pkgs[pkgs %in% installed]; need <- pkgs[!pkgs %in% installed]
cat('已安装 R 包 (', length(have), '):', paste(have, collapse=', '), '\n')
if (length(need)) cat('仍缺少:', paste(need, collapse=', '), '\n') else cat('全部就绪!\n')
"

echo "===== DONE（Kylin V10 ARM64：pandoc + TeX(系统) + R + libgit2 + 依赖包就绪）====="
