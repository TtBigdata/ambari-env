#!/bin/bash
set -euo pipefail

# =========================================================
# Kylin V10 ARM64 - R / TeX / pandoc / SparkR build env
# Final stable version
# =========================================================

DOWNLOAD_DIR="/opt/modules"

R_VER="${R_VER:-4.4.2}"
R_TARBALL="R-${R_VER}.tar.gz"
R_URL="https://mirrors.tuna.tsinghua.edu.cn/CRAN/src/base/R-4/${R_TARBALL}"
R_SRC_DIR="${DOWNLOAD_DIR}/R-${R_VER}"
R_PREFIX="/usr/local/R-${R_VER}"

PANDOC_VER="${PANDOC_VER:-3.1.13}"
PANDOC_TGZ="pandoc-${PANDOC_VER}-linux-arm64.tar.gz"
PANDOC_URL="https://github.com/jgm/pandoc/releases/download/${PANDOC_VER}/${PANDOC_TGZ}"
PANDOC_PREFIX="/usr/local/pandoc-${PANDOC_VER}"

BAD_TL_BIN="/opt/texlive/2024/bin/aarch64-linux"
SYSTEM_PDFLATEX="/usr/bin/pdflatex"

CRAN_MIRRORS="c('https://mirrors.tuna.tsinghua.edu.cn/CRAN/','https://mirrors.ustc.edu.cn/CRAN/','https://mirrors.aliyun.com/CRAN/')"

log() {
  echo
  echo ">>> $*"
}

warn() {
  echo "WARN: $*" >&2
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

install_if_available() {
  local pkg
  local to_install=()
  for pkg in "$@"; do
    if dnf -q list installed "$pkg" >/dev/null 2>&1; then
      echo "已安装: $pkg"
    elif dnf -q list --available "$pkg" >/dev/null 2>&1; then
      to_install+=("$pkg")
    else
      echo "仓库中未发现包: $pkg"
    fi
  done
  if [[ ${#to_install[@]} -gt 0 ]]; then
    echo "批量安装 ${#to_install[@]} 个包: ${to_install[*]}"
    sudo dnf -y install "${to_install[@]}" || true
  fi
}

remove_bad_texlive_from_path() {
  if echo "${PATH}" | tr ':' '\n' | grep -qx "${BAD_TL_BIN}"; then
    export PATH="$(echo "${PATH}" | tr ':' '\n' | grep -vx "${BAD_TL_BIN}" | paste -sd: -)"
  fi
  export PATH="/usr/bin:/usr/sbin:${PATH}"
  hash -r || true
}

clean_bad_texlive_from_profile() {
  if [[ -f /etc/profile ]] && grep -q "${BAD_TL_BIN}" /etc/profile 2>/dev/null; then
    log "从 /etc/profile 中移除 TeX Live 2024 PATH（GLIBC 2.29 不兼容）"
    sudo sed -i "\|${BAD_TL_BIN}|d" /etc/profile
    sudo sed -i '/^export PATH=.*texlive.*2024/d' /etc/profile
    sudo sed -i '/^export MANPATH=.*texlive.*2024/d' /etc/profile
    sudo sed -i '/^export INFOPATH=.*texlive.*2024/d' /etc/profile
  fi
}

# =====[1] 前置检查 =====
ARCH="$(uname -m)"
[[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]] || die "当前架构不是 ARM64/aarch64: $ARCH"
have_cmd dnf || die "未发现 dnf"

sudo mkdir -p "$DOWNLOAD_DIR"
sudo chown "$(id -u)":"$(id -g)" "$DOWNLOAD_DIR"

log "当前架构: $ARCH"
log "R_VERSION: $R_VER"
log "DOWNLOAD_DIR: $DOWNLOAD_DIR"

# =====[2] 基础依赖 =====
log "安装基础依赖"

BASE_DEPS=(
  gcc
  gcc-c++
  gcc-gfortran
  make
  which
  tar
  curl
  wget
  perl
  gzip
  bzip2
  xz
  unzip
  patch
  pkgconf-pkg-config
  cmake
  ca-certificates
  openssl
  openssl-devel
  readline-devel
  zlib-devel
  bzip2-devel
  xz-devel
  pcre2-devel
  libicu-devel
  libcurl-devel
  libX11-devel
  libXt-devel
  cairo-devel
  pango-devel
  libpng-devel
  libjpeg-turbo-devel
  libtiff-devel
  freetype-devel
  fontconfig-devel
  libwebp-devel
  harfbuzz-devel
  fribidi-devel
  libgit2-devel
  qpdf
  tidy
  texinfo
  java-1.8.0-openjdk
  java-1.8.0-openjdk-devel
)

MATH_DEPS=(
  openblas-devel
  lapack-devel
)

TEX_DEPS=(
  texlive
  texlive-latex
  texlive-texlive.infra
  texlive-collection-basic
  texlive-collection-latex
  texlive-collection-latexrecommended
  texlive-collection-latexextra
  texlive-collection-fontsrecommended
  texlive-hyperref
  texlive-inconsolata
  texlive-fancyvrb
  texlive-framed
  texlive-upquote
  texlive-xcolor
  texlive-geometry
  texlive-tools
  texlive-graphics
  texlive-psnfss
  texlive-cm-super
  texlive-latexmk
  texlive-iftex
  texlive-etoolbox
  texlive-kvoptions
  texlive-varwidth
  texlive-url
  texlive-titlesec
  texlive-oberdiek
  texlive-tex-gyre
  texlive-collection-langenglish
)

ALL_DEPS=("${BASE_DEPS[@]}" "${MATH_DEPS[@]}" "${TEX_DEPS[@]}")
install_if_available "${ALL_DEPS[@]}"

sudo update-ca-trust || true

# =====[3] Java 环境 =====
log "检查 Java"

have_cmd java || die "java 不存在"
have_cmd javac || die "javac 不存在"

JAVA_BIN="$(readlink -f "$(command -v java)")"
JAVA_HOME_CAND="$(dirname "$(dirname "$JAVA_BIN")")"
if [[ -d "${JAVA_HOME_CAND}/include" ]]; then
  export JAVA_HOME="${JAVA_HOME_CAND}"
else
  export JAVA_HOME="$(dirname "$(dirname "$(dirname "$JAVA_BIN")")")"
fi

echo "JAVA_HOME=${JAVA_HOME}"
java -version
javac -version

# =====[4] pandoc =====
ensure_pandoc_sys() {
  if dnf -q list --available pandoc >/dev/null 2>&1 || dnf -q list installed pandoc >/dev/null 2>&1; then
    sudo dnf -y install pandoc && return 0
  fi
  return 1
}

ensure_pandoc_bin() {
  have_cmd pandoc && return 0

  log "安装 pandoc 官方 arm64 二进制"
  cd "$DOWNLOAD_DIR"
  rm -f "$PANDOC_TGZ"
  curl -L --retry 5 --retry-delay 2 --tlsv1.2 -o "$PANDOC_TGZ" "$PANDOC_URL"
  [[ -s "$PANDOC_TGZ" ]] || die "pandoc 下载失败"

  sudo rm -rf "$PANDOC_PREFIX"
  sudo tar -xzf "$PANDOC_TGZ" -C /usr/local

  export PATH="${PANDOC_PREFIX}/bin:${PATH}"

  if ! grep -q "PANDOC_HOME=${PANDOC_PREFIX}" /etc/profile 2>/dev/null; then
    echo "export PANDOC_HOME=${PANDOC_PREFIX}" | sudo tee -a /etc/profile >/dev/null
    echo 'export PATH=$PANDOC_HOME/bin:$PATH' | sudo tee -a /etc/profile >/dev/null
  fi
}

log "安装 pandoc"
if ! have_cmd pandoc; then
  ensure_pandoc_sys || ensure_pandoc_bin
fi
have_cmd pandoc || die "pandoc 不可用"
echo "pandoc: $(pandoc -v | head -n1)"

# =====[5] 清理 TeX Live 2024 并验证系统 pdflatex =====
log "清理 TeX Live 2024 并处理 pdflatex"

clean_bad_texlive_from_profile
remove_bad_texlive_from_path

PDFLATEX_OK=false
if [[ -x "${SYSTEM_PDFLATEX}" ]] && "${SYSTEM_PDFLATEX}" --version >/dev/null 2>&1; then
  if [[ "$(command -v pdflatex)" == "${SYSTEM_PDFLATEX}" ]]; then
    if kpsewhich article.cls >/dev/null 2>&1; then
      cat >/tmp/pdflatex_test.tex <<'EOF'
\documentclass{article}
\begin{document}
test
\end{document}
EOF
      if "${SYSTEM_PDFLATEX}" -interaction=nonstopmode -halt-on-error -output-directory=/tmp /tmp/pdflatex_test.tex >/tmp/pdflatex_test.out 2>&1; then
        PDFLATEX_OK=true
        echo "pdflatex 验证通过"
      else
        warn "pdflatex 最小文档测试失败（不影响 R CMD build，仅影响 R CMD check --as-cran）"
      fi
      rm -f /tmp/pdflatex_test.{aux,log,out,pdf,tex} /tmp/pdflatex_test.out || true
    else
      warn "article.cls 不可用，pdflatex 功能受限"
    fi
  else
    warn "当前 pdflatex 不是系统版: $(command -v pdflatex)"
  fi
else
  warn "系统 pdflatex 不可用（不影响 SparkR 的 R CMD build）"
fi

echo "pdflatex: $(command -v pdflatex || echo 'not found')"
echo "PDFLATEX_OK=${PDFLATEX_OK}"

# =====[6] 下载并编译 R =====
log "下载并编译 R-${R_VER}"

cd "$DOWNLOAD_DIR"
if [[ ! -f "$R_TARBALL" ]]; then
  curl -L --retry 5 --retry-delay 2 --tlsv1.2 -o "$R_TARBALL" "$R_URL"
fi

rm -rf "$R_SRC_DIR"
tar -xzf "$R_TARBALL" -C "$DOWNLOAD_DIR"

cd "$R_SRC_DIR"

CFG=( "--prefix=$R_PREFIX" "--enable-R-shlib" )
if rpm -q openblas-devel >/dev/null 2>&1 || ls /usr/lib*/libopenblas.* >/dev/null 2>&1; then
  CFG+=( --with-blas --with-lapack )
fi

export JAVA_HOME
unset R_HOME || true
export TEXINPUTS="${R_SRC_DIR}/share/texmf//:"
export R_PAPERSIZE=letter

./configure "${CFG[@]}"
make -j"$(nproc)"
sudo make install

# =====[7] 安装后校验 R =====
log "校验安装后的 R"

R_BIN="${R_PREFIX}/bin/R"
R_SCRIPT_BIN="${R_PREFIX}/bin/Rscript"

[[ -x "${R_BIN}" ]] || die "R 安装失败: ${R_BIN}"
[[ -x "${R_SCRIPT_BIN}" ]] || die "Rscript 安装失败: ${R_SCRIPT_BIN}"

unset R_HOME || true
INSTALLED_R_HOME="$("${R_BIN}" RHOME | tail -n 1)"
export R_HOME="${INSTALLED_R_HOME}"
export TEXINPUTS="${INSTALLED_R_HOME}/share/texmf//:"

echo "R_PREFIX=${R_PREFIX}"
echo "R_HOME=${R_HOME}"
echo "R 版本: $("${R_BIN}" --version | head -n1)"

[[ -f "${R_HOME}/share/texmf/tex/latex/Rd.sty" ]] || die "缺少 Rd.sty"
[[ -f "${R_HOME}/share/texmf/tex/latex/Sweave.sty" ]] || die "缺少 Sweave.sty"

echo "Rd.sty: ${R_HOME}/share/texmf/tex/latex/Rd.sty"
echo "Sweave.sty: ${R_HOME}/share/texmf/tex/latex/Sweave.sty"

# =====[8] 校验 Rd2pdf（仅在 pdflatex 可用时）=====
if [[ "${PDFLATEX_OK}" == "true" ]]; then
  log "验证 Rd2pdf"

  rm -f /tmp/stats-manual.pdf /tmp/rd2pdf_check.log
  "${R_BIN}" CMD Rd2pdf "${R_HOME}/library/stats" --output=/tmp/stats-manual.pdf >/tmp/rd2pdf_check.log 2>&1 \
    || { cat /tmp/rd2pdf_check.log; die "R CMD Rd2pdf 验证失败"; }

  [[ -s /tmp/stats-manual.pdf ]] || die "Rd2pdf 未生成有效 PDF"
  echo "Rd2pdf 验证通过: /tmp/stats-manual.pdf"
else
  log "跳过 Rd2pdf 验证（pdflatex 不可用，不影响 SparkR R CMD build）"
fi

# =====[9] 写 profile =====
if ! grep -q "R_PREFIX=${R_PREFIX}" /etc/profile 2>/dev/null; then
  echo "export R_PREFIX=${R_PREFIX}" | sudo tee -a /etc/profile >/dev/null
  echo 'export PATH=$R_PREFIX/bin:$PATH' | sudo tee -a /etc/profile >/dev/null
fi

export PATH="${R_PREFIX}/bin:${PANDOC_PREFIX}/bin:/usr/bin:/usr/sbin:${PATH}"

# =====[10] 将 R 包安装到系统库（确保 rpmbuild 等场景也能找到）=====
log "安装 R 包到系统库"

R_SYS_LIB="$("${R_SCRIPT_BIN}" -e "cat(.Library)")"
echo "R 系统库路径: ${R_SYS_LIB}"

sudo "${R_SCRIPT_BIN}" -e "
options(repos=$CRAN_MIRRORS, Ncpus=parallel::detectCores());
Sys.setenv(R_REMOTES_NO_ERRORS_FROM_WARNINGS='true');

pkgs <- c(
  'ragg',
  'knitr',
  'rmarkdown',
  'e1071',
  'survival',
  'htmlwidgets',
  'profvis',
  'roxygen2',
  'testthat'
);

need <- pkgs[!suppressWarnings(sapply(pkgs, function(p) requireNamespace(p, quietly=TRUE)))];
if (length(need)) {
  message('Need install: ', paste(need, collapse=', '));
  install.packages(need, lib='${R_SYS_LIB}');
} else {
  message('All required packages already installed.');
}
"

# =====[11] 验收 R 包 =====
log "验收 R 包"

"${R_SCRIPT_BIN}" -e "
pkgs <- c(
  'ragg','knitr','rmarkdown','e1071','survival',
  'htmlwidgets','profvis','roxygen2','testthat'
);
status <- sapply(pkgs, function(p) requireNamespace(p, quietly=TRUE));
print(status);
if (!all(status)) quit(status=1);
"

# =====[12] 输出结果 =====
log "完成"
echo "R_PREFIX=${R_PREFIX}"
echo "R_HOME=${R_HOME}"
echo "JAVA_HOME=${JAVA_HOME}"
echo "PANDOC=$(command -v pandoc)"
echo "PDFLATEX=$(command -v pdflatex)"
echo "R_SYS_LIB=${R_SYS_LIB}"
echo "已跳过的包: gert usethis devtools curl httr2 gh pkgdown"
echo "===== DONE（Kylin V10 ARM64 一次性稳定版）====="