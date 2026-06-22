#!/usr/bin/env bash
#
# Ubuntu 22.04 bare-metal initializer for the Ambari build environment.
#
# This script is intentionally standalone. The Docker entrypoint scripts under
# scripts/system/init assume container mounts and container-local services, so
# this version uses public mirrors and idempotent local state instead.
#
# Usage:
#   sudo bash scripts/system/init-no-docker/init_ubuntu22_no_docker.sh
#
# Useful overrides:
#   CONFIGURE_APT_MIRROR=0       keep only the server's existing apt sources
#   UBUNTU_MIRROR=https://...    public mirror used when CONFIGURE_APT_MIRROR=1
#   ENABLE_ROOT_SSH=1            allow root password login in sshd_config
#   ROOT_PASSWORD='change-me'    optional root password when ENABLE_ROOT_SSH=1
#   CLONE_REPOS=0                skip Apache source checkout
#   GIT_PROXY_PREFIX=            clone directly from github.com

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

AMBARI_ENV_HOME="${AMBARI_ENV_HOME:-/opt/modules}"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-${AMBARI_ENV_HOME}/downloads}"
PROFILE_FILE="${PROFILE_FILE:-/etc/profile.d/ambari-env.sh}"
LOG_DIR="${LOG_DIR:-/var/log/ambari-env-init}"
TIMEZONE="${TIMEZONE:-Asia/Shanghai}"

CONFIGURE_APT_MIRROR="${CONFIGURE_APT_MIRROR:-1}"
UBUNTU_MIRROR="${UBUNTU_MIRROR:-https://mirrors.tuna.tsinghua.edu.cn/ubuntu}"

ENABLE_ROOT_SSH="${ENABLE_ROOT_SSH:-0}"
ROOT_PASSWORD="${ROOT_PASSWORD:-}"

CLONE_REPOS="${CLONE_REPOS:-1}"
GIT_PROXY_PREFIX="${GIT_PROXY_PREFIX:-https://ghfast.top/}"

JDK8_VERSION="${JDK8_VERSION:-8u202}"
JDK8_HOME="${JDK8_HOME:-${AMBARI_ENV_HOME}/jdk1.8.0_202}"
JDK8_TAR="${JDK8_TAR:-jdk-8u202-linux-x64.tar.gz}"
JDK8_URL="${JDK8_URL:-https://repo.huaweicloud.com/java/jdk/8u202-b08/${JDK8_TAR}}"

JDK17_VERSION="${JDK17_VERSION:-17.0.2}"
JDK17_HOME="${JDK17_HOME:-${AMBARI_ENV_HOME}/jdk-${JDK17_VERSION}}"
JDK17_TAR="${JDK17_TAR:-openjdk-${JDK17_VERSION}_linux-x64_bin.tar.gz}"
JDK17_URL="${JDK17_URL:-https://mirrors.huaweicloud.com/openjdk/${JDK17_VERSION}/${JDK17_TAR}}"

MAVEN_VERSION="${MAVEN_VERSION:-3.8.4}"
MAVEN_HOME="${MAVEN_HOME:-${AMBARI_ENV_HOME}/apache-maven-${MAVEN_VERSION}}"
MAVEN_TAR="${MAVEN_TAR:-apache-maven-${MAVEN_VERSION}-bin.tar.gz}"
MAVEN_URL="${MAVEN_URL:-https://repo.huaweicloud.com/apache/maven/maven-3/${MAVEN_VERSION}/binaries/${MAVEN_TAR}}"
MAVEN39_VERSION="${MAVEN39_VERSION:-3.9.6}"
MAVEN39_HOME="${MAVEN39_HOME:-${AMBARI_ENV_HOME}/apache-maven-${MAVEN39_VERSION}}"
MAVEN39_TAR="${MAVEN39_TAR:-apache-maven-${MAVEN39_VERSION}-bin.tar.gz}"
MAVEN39_URL="${MAVEN39_URL:-https://repo.huaweicloud.com/apache/maven/maven-3/${MAVEN39_VERSION}/binaries/${MAVEN39_TAR}}"
MAVEN_ACTIVE_HOME="${MAVEN_ACTIVE_HOME:-${MAVEN39_HOME}}"

GRADLE_VERSION="${GRADLE_VERSION:-5.6.4}"
GRADLE_HOME="${GRADLE_HOME:-${AMBARI_ENV_HOME}/gradle-${GRADLE_VERSION}}"
GRADLE_ZIP="${GRADLE_ZIP:-gradle-${GRADLE_VERSION}-bin.zip}"
GRADLE_URL="${GRADLE_URL:-https://mirrors.huaweicloud.com/gradle/${GRADLE_ZIP}}"

ANT_VERSION="${ANT_VERSION:-1.10.12}"
ANT_HOME="${ANT_HOME:-${AMBARI_ENV_HOME}/apache-ant-${ANT_VERSION}}"
ANT_TAR="${ANT_TAR:-apache-ant-${ANT_VERSION}-bin.tar.gz}"
ANT_URL="${ANT_URL:-https://mirrors.huaweicloud.com/apache/ant/binaries/${ANT_TAR}}"

IVY_VERSION="${IVY_VERSION:-2.5.0}"
IVY_HOME="${IVY_HOME:-${AMBARI_ENV_HOME}/apache-ivy-${IVY_VERSION}}"
IVY_TAR="${IVY_TAR:-apache-ivy-${IVY_VERSION}-bin.tar.gz}"
IVY_URL="${IVY_URL:-https://mirrors.huaweicloud.com/apache/ant/ivy/${IVY_VERSION}/${IVY_TAR}}"

R_VERSION="${R_VERSION:-4.4.2}"
R_HOME="${R_HOME:-/usr/local/R-${R_VERSION}}"
R_TAR="${R_TAR:-R-${R_VERSION}.tar.gz}"
R_URL="${R_URL:-https://mirrors.ustc.edu.cn/CRAN/src/base/R-4/${R_TAR}}"
R_URLS=(
  "$R_URL"
  "https://mirrors.aliyun.com/CRAN/src/base/R-4/${R_TAR}"
  "https://cloud.r-project.org/src/base/R-4/${R_TAR}"
  "https://cran.r-project.org/src/base/R-4/${R_TAR}"
  "https://mirrors.tuna.tsinghua.edu.cn/CRAN/src/base/R-4/${R_TAR}"
)

PYTHON_VERSION="${PYTHON_VERSION:-3.7.12}"
PYTHON_HOME="${PYTHON_HOME:-${AMBARI_ENV_HOME}/python-${PYTHON_VERSION}}"
PYTHON_TAR="${PYTHON_TAR:-Python-${PYTHON_VERSION}.tgz}"
PYTHON_URL="${PYTHON_URL:-https://repo.huaweicloud.com/python/${PYTHON_VERSION}/${PYTHON_TAR}}"
PY37_VENV="${PY37_VENV:-${AMBARI_ENV_HOME}/virtual_env/hadoop_py37}"
DEFAULT_PIP_INDEX_URL="${DEFAULT_PIP_INDEX_URL:-https://mirrors.aliyun.com/pypi/simple}"
PIP_INDEX_URL="${PIP_INDEX_URL:-$DEFAULT_PIP_INDEX_URL}"
PIP_INDEX_URLS=(
  "$DEFAULT_PIP_INDEX_URL"
  "$PIP_INDEX_URL"
  "https://pypi.org/simple"
  "https://mirrors.ustc.edu.cn/pypi/simple"
  "https://pypi.tuna.tsinghua.edu.cn/simple"
)
GET_PIP_URL="${GET_PIP_URL:-https://bootstrap.pypa.io/pip/3.7/get-pip.py}"

MAVEN_LOCAL_REPO="${MAVEN_LOCAL_REPO:-/root/.m2/repository}"
MAVEN_HTTP_OPTS="${MAVEN_HTTP_OPTS:--Dmaven.wagon.http.retryHandler.count=5 -Dmaven.wagon.rto=120000 -Dmaven.wagon.httpconnectionManager.ttlSeconds=120 -Dmaven.wagon.http.pool=false}"
GRADLE_USER_HOME="${GRADLE_USER_HOME:-/root/.gradle}"
MINICONDA_HOME="${MINICONDA_HOME:-${AMBARI_ENV_HOME}/miniconda3}"
DORIS_BUILD_CACHE_HOME="${DORIS_BUILD_CACHE_HOME:-${AMBARI_ENV_HOME}/doris-build-cache}"
DORIS_NPM_CACHE="${DORIS_NPM_CACHE:-${DORIS_BUILD_CACHE_HOME}/npm}"
DORIS_CCACHE_DIR="${DORIS_CCACHE_DIR:-${DORIS_BUILD_CACHE_HOME}/ccache}"
DORIS_CCACHE_MAXSIZE="${DORIS_CCACHE_MAXSIZE:-50G}"
DORIS_SOURCE_CACHE_DIR="${DORIS_SOURCE_CACHE_DIR:-${DORIS_BUILD_CACHE_HOME}/sources}"
DORIS_APACHE_ORC_SOURCE_URL="${DORIS_APACHE_ORC_SOURCE_URL:-${GIT_PROXY_PREFIX}https://github.com/apache/doris-thirdparty/archive/refs/heads/orc.tar.gz}"
DORIS_CLUCENE_SOURCE_URL="${DORIS_CLUCENE_SOURCE_URL:-${GIT_PROXY_PREFIX}https://github.com/apache/doris-thirdparty/archive/refs/heads/clucene.tar.gz}"
DORIS_NPM_REGISTRY="${DORIS_NPM_REGISTRY:-https://registry.npmmirror.com}"
DORIS_THIRDPARTY_RELEASE="${DORIS_THIRDPARTY_RELEASE:-automation-2.1}"
DORIS_THIRDPARTY_REPO_URL="${DORIS_THIRDPARTY_REPO_URL:-https://github.com/apache/doris-thirdparty/releases/download/${DORIS_THIRDPARTY_RELEASE}}"
DORIS_THIRDPARTY_MIRROR_URL="${DORIS_THIRDPARTY_MIRROR_URL:-https://ghfast.top/${DORIS_THIRDPARTY_REPO_URL}}"

TRINO_MAVEN_VERSION="${TRINO_MAVEN_VERSION:-3.9.11}"
TRINO_MAVEN_HOME="${TRINO_MAVEN_HOME:-${AMBARI_ENV_HOME}/apache-maven-${TRINO_MAVEN_VERSION}}"
TRINO_MAVEN_TAR="${TRINO_MAVEN_TAR:-apache-maven-${TRINO_MAVEN_VERSION}-bin.tar.gz}"
TRINO_MAVEN_URL="${TRINO_MAVEN_URL:-https://repo.huaweicloud.com/apache/maven/maven-3/${TRINO_MAVEN_VERSION}/binaries/${TRINO_MAVEN_TAR}}"
TRINO_MAVEN_ARCHIVE_URL="${TRINO_MAVEN_ARCHIVE_URL:-https://archive.apache.org/dist/maven/maven-3/${TRINO_MAVEN_VERSION}/binaries/${TRINO_MAVEN_TAR}}"
TRINO_JDK_VERSION="${TRINO_JDK_VERSION:-23.0.2_7}"
TRINO_JDK_DIR_VERSION="${TRINO_JDK_DIR_VERSION:-23.0.2+7}"
TRINO_JDK_HOME="${TRINO_JDK_HOME:-${AMBARI_ENV_HOME}/jdk-${TRINO_JDK_DIR_VERSION}}"
TRINO_JDK_TAR="${TRINO_JDK_TAR:-OpenJDK23U-jdk_x64_linux_hotspot_${TRINO_JDK_VERSION}.tar.gz}"
TRINO_JDK_URL="${TRINO_JDK_URL:-https://github.com/JaneTTR-Bigdata/trino/releases/download/474/${TRINO_JDK_TAR}}"
TRINO_JDK_MIRROR_URL="${TRINO_JDK_MIRROR_URL:-https://ghfast.top/${TRINO_JDK_URL}}"
TRINO_NODE_VERSION="${TRINO_NODE_VERSION:-22.14.0}"
TRINO_NODE_CACHE_DIR="${TRINO_NODE_CACHE_DIR:-${MAVEN_LOCAL_REPO}/com/github/eirslett/node/${TRINO_NODE_VERSION}}"
TRINO_NODE_RAW_TAR="${TRINO_NODE_RAW_TAR:-node-v${TRINO_NODE_VERSION}-linux-x64-glibc-217.tar.gz}"
TRINO_NODE_RAW_URL="${TRINO_NODE_RAW_URL:-https://unofficial-builds.nodejs.org/download/release/v${TRINO_NODE_VERSION}/${TRINO_NODE_RAW_TAR}}"
TRINO_NODE_MAVEN_TAR="${TRINO_NODE_MAVEN_TAR:-node-${TRINO_NODE_VERSION}-linux-x64.tar.gz}"

PHANTOMJS_VERSION="${PHANTOMJS_VERSION:-2.1.1}"
PHANTOMJS_HOME="${PHANTOMJS_HOME:-${AMBARI_ENV_HOME}/phantomjs}"
PHANTOMJS_TAR="${PHANTOMJS_TAR:-phantomjs-${PHANTOMJS_VERSION}-linux-x86_64.tar.bz2}"
PHANTOMJS_URL="${PHANTOMJS_URL:-https://cdn.npmmirror.com/binaries/phantomjs/${PHANTOMJS_TAR}}"
PHANTOMJS_MIRROR_URL="${PHANTOMJS_MIRROR_URL:-https://ghfast.top/https://github.com/Medium/phantomjs/releases/download/v${PHANTOMJS_VERSION}/${PHANTOMJS_TAR}}"
PHANTOMJS_CDNURL="${PHANTOMJS_CDNURL:-https://cdn.npmmirror.com/binaries/phantomjs}"
PHANTOMJS_OPENSSL_CONF="${PHANTOMJS_OPENSSL_CONF:-/dev/null}"

SUPERSET_BUILD_CACHE_HOME="${SUPERSET_BUILD_CACHE_HOME:-${AMBARI_ENV_HOME}/superset-build-cache}"
SUPERSET_CONDA_PKGS_DIR="${SUPERSET_CONDA_PKGS_DIR:-${SUPERSET_BUILD_CACHE_HOME}/conda-pkgs}"
SUPERSET_PIP_CACHE_DIR="${SUPERSET_PIP_CACHE_DIR:-${SUPERSET_BUILD_CACHE_HOME}/pip}"
SUPERSET_NPM_CACHE="${SUPERSET_NPM_CACHE:-${SUPERSET_BUILD_CACHE_HOME}/npm}"
SUPERSET_NPM_REGISTRY="${SUPERSET_NPM_REGISTRY:-https://registry.npmmirror.com/}"
SUPERSET_SEED_ENV="${SUPERSET_SEED_ENV:-${SUPERSET_BUILD_CACHE_HOME}/seed-env-py39-node18}"

IMPALA_BUILD_ENV_HOME="${IMPALA_BUILD_ENV_HOME:-${AMBARI_ENV_HOME}/impala-build-env}"
IMPALA_INFRA_TARBALL="${IMPALA_INFRA_TARBALL:-${IMPALA_BUILD_ENV_HOME}/impala-build-env-infra.tar.gz}"
IMPALA_TOOLCHAIN_TARBALL="${IMPALA_TOOLCHAIN_TARBALL:-${IMPALA_BUILD_ENV_HOME}/impala-build-env-toolchain.tar.gz}"
IMPALA_TOOLCHAIN_DIR="${IMPALA_TOOLCHAIN_DIR:-${IMPALA_BUILD_ENV_HOME}/toolchain}"
IMPALA_INFRA_URL="${IMPALA_INFRA_URL:-}"
IMPALA_TOOLCHAIN_URL="${IMPALA_TOOLCHAIN_URL:-}"
REQUIRE_IMPALA_ENV="${REQUIRE_IMPALA_ENV:-0}"

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    die "run this script as root, for example: sudo bash $0"
  fi
}

require_ubuntu22() {
  if [ ! -r /etc/os-release ]; then
    die "/etc/os-release not found"
  fi
  # shellcheck disable=SC1091
  . /etc/os-release
  if [ "${ID:-}" != "ubuntu" ] || [ "${VERSION_ID:-}" != "22.04" ]; then
    die "this script supports Ubuntu 22.04 only, current system is ${ID:-unknown} ${VERSION_ID:-unknown}"
  fi
}

prepare_dirs() {
  mkdir -p "$AMBARI_ENV_HOME" "$DOWNLOAD_DIR" "$LOG_DIR" /data
}

configure_apt_mirror() {
  if [ "$CONFIGURE_APT_MIRROR" != "1" ]; then
    log "APT mirror rewrite skipped; using existing server sources."
    return
  fi

  local source_file="/etc/apt/sources.list.d/ambari-env-jammy.list"
  local mirror="${UBUNTU_MIRROR%/}"

  log "Writing public Ubuntu mirror source: ${source_file}"
  cat >"$source_file" <<EOF
deb ${mirror}/ jammy main restricted universe multiverse
deb ${mirror}/ jammy-updates main restricted universe multiverse
deb ${mirror}/ jammy-security main restricted universe multiverse
deb ${mirror}/ jammy-backports main restricted universe multiverse
EOF
}

install_packages() {
  log "Installing Ubuntu build dependencies"
  apt-get clean
  apt-get update

  local packages=(
    ca-certificates
    openssh-client
    openssh-server
    sudo
    net-tools
    unzip
    wget
    git
    patch
    ccache
    nodejs
    npm
    build-essential
    binutils-dev
    libiberty-dev
    flex
    bison
    cmake
    autoconf
    automake
    libtool
    vim
    lsof
    iproute2
    less
    curl
    bzip2
    xz-utils
    zlib1g-dev
    libssl-dev
    libsnappy-dev
    libbz2-dev
    libtirpc-dev
    libkrb5-dev
    libxml2-dev
    libxslt1-dev
    libmariadb-dev
    libmariadb-dev-compat
    libpq-dev
    libldap2-dev
    protobuf-compiler
    python3
    python3-pip
    python3-distutils
    tar
    dpkg-dev
    libdpkg-perl
    debhelper
    devscripts
    dh-make
    lintian
    fakeroot
    quilt
    locales
    libcppunit-dev
    pkg-config
    m4
    autoconf-archive
    liblzo2-dev
    libzip-dev
    sharutils
    libfuse-dev
    libsasl2-dev
    libgsasl-dev
    asciidoc
    rsync
    libarchive13
    libzstd-dev
    libprotobuf-dev
    libprotoc-dev
    libisal-dev
    libpmem-dev
    tzdata
    libncurses5-dev
    libsqlite3-dev
    libreadline-dev
    tk-dev
    libgdbm-dev
    libgdbm-compat-dev
    libpcap-dev
    liblzma-dev
    libffi-dev
    uuid-dev
    gfortran
    r-base
    r-base-dev
    r-cran-knitr
    r-cran-rmarkdown
    r-cran-devtools
    r-cran-e1071
    r-cran-gh
    r-cran-htmlwidgets
    r-cran-usethis
    r-cran-roxygen2
    r-cran-testthat
    libicu-dev
    libxt-dev
    libx11-dev
    libpng-dev
    libjpeg-dev
    libtiff-dev
    libcairo2-dev
    libpango1.0-dev
    libharfbuzz-dev
    libfribidi-dev
    libcurl4-openssl-dev
    libgit2-dev
    libssh2-1-dev
    libuv1-dev
    libfreetype6-dev
    libfontconfig1-dev
    libwebp-dev
    qpdf
    texlive
    texlive-latex-base
    texlive-xetex
    texlive-latex-recommended
    texlive-latex-extra
    texlive-fonts-extra
    tidy
    pandoc
    postgresql
    postgresql-contrib
  )

  apt-get install -y "${packages[@]}"
}

configure_system_basics() {
  log "Configuring timezone, locales and sshd baseline"
  ln -snf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
  dpkg-reconfigure -f noninteractive tzdata >/dev/null 2>&1 || true

  locale-gen en_US.UTF-8 zh_CN.UTF-8 >/dev/null 2>&1 || true
  update-locale LANG=en_US.UTF-8 >/dev/null 2>&1 || true

  mkdir -p /var/run/sshd
  ssh-keygen -A >/dev/null 2>&1 || true

  if [ "$ENABLE_ROOT_SSH" = "1" ]; then
    set_sshd_option PermitRootLogin yes
    set_sshd_option PasswordAuthentication yes
    if [ -n "$ROOT_PASSWORD" ]; then
      printf 'root:%s\n' "$ROOT_PASSWORD" | chpasswd
    else
      log "ENABLE_ROOT_SSH=1 but ROOT_PASSWORD is empty; sshd_config is changed, root password is not."
    fi
  fi

  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable --now ssh >/dev/null 2>&1 || systemctl enable --now sshd >/dev/null 2>&1 || true
  else
    service ssh start >/dev/null 2>&1 || true
  fi
}

set_sshd_option() {
  local key="$1"
  local value="$2"
  local file="/etc/ssh/sshd_config"

  touch "$file"
  if grep -Eq "^[#[:space:]]*${key}[[:space:]]+" "$file"; then
    sed -i -E "s|^[#[:space:]]*${key}[[:space:]]+.*|${key} ${value}|" "$file"
  else
    printf '%s %s\n' "$key" "$value" >>"$file"
  fi
}

download_file() {
  local url="$1"
  local target="$2"
  local tmp="${target}.tmp.$$"

  if [ -s "$target" ]; then
    log "Download exists: $target"
    return
  fi

  mkdir -p "$(dirname "$target")"
  log "Downloading $url"
  rm -f "$tmp"
  curl -fL --retry 5 --retry-delay 2 --connect-timeout 30 -o "$tmp" "$url"
  [ -s "$tmp" ] || die "download produced an empty file: $url"
  mv -f "$tmp" "$target"
}

download_file_from_urls() {
  local target="$1"
  shift

  if [ -s "$target" ]; then
    log "Download exists: $target"
    return
  fi

  mkdir -p "$(dirname "$target")"

  local url tmp
  for url in "$@"; do
    tmp="${target}.tmp.$$"
    rm -f "$tmp"
    log "Downloading $url"
    if curl -fL --retry 3 --retry-delay 2 --connect-timeout 30 -o "$tmp" "$url"; then
      if [ -s "$tmp" ]; then
        mv -f "$tmp" "$target"
        return
      fi
      log "Downloaded empty file, trying next URL: $url"
    else
      log "Download failed, trying next URL: $url"
    fi
    rm -f "$tmp"
  done

  die "all download URLs failed for $target"
}

ensure_doris_thirdparty() {
  log "Installing Doris thirdparty prebuilt package"
  local arch asset target sha tmp url
  arch="$(uname -m)"

  case "$arch" in
    x86_64 | amd64)
      asset="doris-thirdparty-prebuilt-linux-x86_64.tar.xz"
      target="${AMBARI_ENV_HOME}/doris-thirdparty-prebuilt-linux-x86_64.tar.xz"
      sha="fdba8c94684a652764f9e192a9a8f523816d89948442f91d6e168b0230bbd888"
      ;;
    aarch64 | arm64)
      asset="doris-thirdparty-2.1-prebuild-arm64.tar.xz"
      target="${AMBARI_ENV_HOME}/doris-thirdparty-prebuild-arm64.tar.xz"
      sha="3865a3192549a16878f29982b856493ea2444431c535760bb0605add44666d55"
      ;;
    *) die "unsupported Doris thirdparty architecture: $arch" ;;
  esac

  if [ -s "$target" ]; then
    if printf '%s  %s\n' "$sha" "$target" | sha256sum -c - >/dev/null 2>&1; then
      log "Doris thirdparty exists: $target"
      return
    fi
    log "Doris thirdparty checksum mismatch, redownloading: $target"
    rm -f "$target"
  fi

  mkdir -p "$(dirname "$target")"
  tmp="${target}.tmp.$$"
  for url in "${DORIS_THIRDPARTY_MIRROR_URL}/${asset}" "${DORIS_THIRDPARTY_REPO_URL}/${asset}"; do
    rm -f "$tmp"
    log "Downloading $url"
    if curl -fL --retry 5 --retry-delay 5 --connect-timeout 30 -o "$tmp" "$url"; then
      if printf '%s  %s\n' "$sha" "$tmp" | sha256sum -c - >/dev/null 2>&1; then
        mv -f "$tmp" "$target"
        chmod 0644 "$target"
        return
      fi
      log "Checksum failed, trying next URL: $url"
    else
      log "Download failed, trying next URL: $url"
    fi
    rm -f "$tmp"
  done

  die "all Doris thirdparty download URLs failed"
}

prepare_doris_build_cache() {
  log "Preparing persistent Doris build caches"
  mkdir -p "$DORIS_BUILD_CACHE_HOME" "$DORIS_NPM_CACHE" "$DORIS_CCACHE_DIR" "$DORIS_SOURCE_CACHE_DIR" "$MAVEN_LOCAL_REPO" "$GRADLE_USER_HOME"

  download_file "$DORIS_APACHE_ORC_SOURCE_URL" "${DORIS_SOURCE_CACHE_DIR}/apache-orc.tar.gz"
  download_file "$DORIS_CLUCENE_SOURCE_URL" "${DORIS_SOURCE_CACHE_DIR}/clucene.tar.gz"

  if command -v npm >/dev/null 2>&1; then
    npm config set cache "$DORIS_NPM_CACHE" --global >/dev/null 2>&1 || true
    npm config set registry "$DORIS_NPM_REGISTRY" --global >/dev/null 2>&1 || true
    npm config set strict-ssl false --global >/dev/null 2>&1 || true
    npm config set prefer-offline true --global >/dev/null 2>&1 || true
    npm config set fetch-retries 5 --global >/dev/null 2>&1 || true
    npm config set fetch-retry-mintimeout 20000 --global >/dev/null 2>&1 || true
    npm config set fetch-retry-maxtimeout 120000 --global >/dev/null 2>&1 || true
  fi

  if command -v ccache >/dev/null 2>&1; then
    CCACHE_DIR="$DORIS_CCACHE_DIR" CCACHE_MAXSIZE="$DORIS_CCACHE_MAXSIZE" ccache --max-size="$DORIS_CCACHE_MAXSIZE" >/dev/null 2>&1 || true
  fi
}

install_phantomjs() {
  log "Installing PhantomJS for Tez UI builds"
  local arch archive tmp_dir extracted phantom_bin phantom_real
  arch="$(uname -m)"
  case "$arch" in
    x86_64 | amd64) ;;
    *) die "PhantomJS prebuilt defaults are for x86_64; override PHANTOMJS_* variables for ${arch}" ;;
  esac

  if [ -x "${PHANTOMJS_HOME}/bin/phantomjs" ]; then
    log "PhantomJS exists, skip download: ${PHANTOMJS_HOME}"
  else
    archive="${DOWNLOAD_DIR}/${PHANTOMJS_TAR}"
    download_file_from_urls "$archive" "$PHANTOMJS_URL" "$PHANTOMJS_MIRROR_URL"
    tmp_dir="$(mktemp -d)"
    tar -xjf "$archive" -C "$tmp_dir"
    extracted="$(tar -tjf "$archive" | sed -n '1s#/.*##p')"
    [ -n "$extracted" ] || die "failed to inspect PhantomJS archive: $archive"
    rm -rf "$PHANTOMJS_HOME"
    mv "$tmp_dir/$extracted" "$PHANTOMJS_HOME"
    rm -rf "$tmp_dir"
  fi

  phantom_bin="${PHANTOMJS_HOME}/bin/phantomjs"
  phantom_real="${PHANTOMJS_HOME}/bin/phantomjs.real"
  if [ ! -x "$phantom_real" ]; then
    mv "$phantom_bin" "$phantom_real"
  fi
  cat >"$phantom_bin" <<'EOF'
#!/usr/bin/env bash
export OPENSSL_CONF="${PHANTOMJS_OPENSSL_CONF:-/dev/null}"
exec "$(dirname "$0")/phantomjs.real" "$@"
EOF
  chmod +x "$phantom_bin" "$phantom_real"
  ln -sf "${PHANTOMJS_HOME}/bin/phantomjs" /usr/local/bin/phantomjs
}

install_trino_toolchain() {
  log "Installing Trino build toolchain"
  local arch raw_node renamed_node tmp_node_dir extracted_node
  arch="$(uname -m)"
  case "$arch" in
    x86_64 | amd64) ;;
    *) die "Trino toolchain defaults are for x86_64; override TRINO_* variables for ${arch}" ;;
  esac

  if [ -d "$TRINO_MAVEN_HOME" ]; then
    log "Trino Maven exists, skip download: $TRINO_MAVEN_HOME"
  else
    download_file_from_urls "${DOWNLOAD_DIR}/${TRINO_MAVEN_TAR}" "$TRINO_MAVEN_URL" "$TRINO_MAVEN_ARCHIVE_URL"
    extract_tar_gz_once "${DOWNLOAD_DIR}/${TRINO_MAVEN_TAR}" "$AMBARI_ENV_HOME" "$TRINO_MAVEN_HOME"
  fi
  write_maven_settings "$TRINO_MAVEN_HOME"

  if [ -d "$TRINO_JDK_HOME" ]; then
    log "Trino JDK exists, skip download: $TRINO_JDK_HOME"
  else
    download_file_from_urls "${DOWNLOAD_DIR}/${TRINO_JDK_TAR}" "$TRINO_JDK_MIRROR_URL" "$TRINO_JDK_URL"
    extract_tar_gz_once "${DOWNLOAD_DIR}/${TRINO_JDK_TAR}" "$AMBARI_ENV_HOME" "$TRINO_JDK_HOME"
  fi

  mkdir -p "$TRINO_NODE_CACHE_DIR"
  raw_node="${TRINO_NODE_CACHE_DIR}/${TRINO_NODE_RAW_TAR}"
  renamed_node="${TRINO_NODE_CACHE_DIR}/${TRINO_NODE_MAVEN_TAR}"
  if [ ! -s "$renamed_node" ]; then
    download_file "$TRINO_NODE_RAW_URL" "$raw_node"
    tmp_node_dir="$(mktemp -d)"
    tar -xzf "$raw_node" -C "$tmp_node_dir"
    extracted_node="$(tar -tzf "$raw_node" | sed -n '1s#/.*##p')"
    [ -n "$extracted_node" ] || die "failed to inspect Node archive: $raw_node"
    mv "$tmp_node_dir/$extracted_node" "$tmp_node_dir/node-v${TRINO_NODE_VERSION}-linux-x64"
    tar -zcf "$renamed_node" -C "$tmp_node_dir" "node-v${TRINO_NODE_VERSION}-linux-x64"
    rm -rf "$tmp_node_dir"
  else
    log "Trino Node Maven artifact exists: $renamed_node"
  fi
}

prepare_superset_build_cache() {
  log "Preparing persistent Superset build caches"
  mkdir -p "$SUPERSET_BUILD_CACHE_HOME" "$SUPERSET_CONDA_PKGS_DIR" "$SUPERSET_PIP_CACHE_DIR" "$SUPERSET_NPM_CACHE"

  if command -v npm >/dev/null 2>&1; then
    npm config set cache "$SUPERSET_NPM_CACHE" --global >/dev/null 2>&1 || true
    npm config set registry "$SUPERSET_NPM_REGISTRY" --global >/dev/null 2>&1 || true
    npm config set prefer-offline true --global >/dev/null 2>&1 || true
    npm config set fund false --global >/dev/null 2>&1 || true
    npm config set audit false --global >/dev/null 2>&1 || true
  fi

  [ -x "${MINICONDA_HOME}/bin/conda" ] || die "conda not found: ${MINICONDA_HOME}/bin/conda"
  if [ -x "${MINICONDA_HOME}/bin/python" ]; then
    PIP_CACHE_DIR="$SUPERSET_PIP_CACHE_DIR" "${MINICONDA_HOME}/bin/python" -m pip install \
      --upgrade \
      conda-pack \
      -i "$PIP_INDEX_URL" || log "Base conda-pack could not be prepared; package build will use the active environment if available."
  fi

  CONDA_PKGS_DIRS="$SUPERSET_CONDA_PKGS_DIR" "${MINICONDA_HOME}/bin/conda" create \
    -p "$SUPERSET_SEED_ENV" \
    -c conda-forge \
    python=3.9.19 "nodejs>=18,<19" libffi openssl pip setuptools wheel conda-pack babel \
    -y || log "Superset seed conda env could not be fully prepared; package build will retry with the persistent cache."

  if [ -x "${SUPERSET_SEED_ENV}/bin/python" ]; then
    PIP_CACHE_DIR="$SUPERSET_PIP_CACHE_DIR" "${SUPERSET_SEED_ENV}/bin/python" -m pip install \
      --upgrade \
      gevent==24.2.1 pymysql psycopg2-binary conda-pack babel \
      -i "$PIP_INDEX_URL" || log "Superset seed pip packages could not be fully prepared; package build will retry."
  fi
}

repair_impala_python2_distutils() {
  command -v python2 >/dev/null 2>&1 || return 0

  if python2 - <<'PY' >/dev/null 2>&1; then
from distutils import archive_util
PY
    return 0
  fi

  local src="${IMPALA_TOOLCHAIN_DIR}/toolchain-packages-gcc10.4.0/python-2.7.16/lib/python2.7/distutils/archive_util.py"
  if [ ! -s "$src" ]; then
    log "Python2 distutils archive_util is missing, and fallback source was not found: $src"
    return 0
  fi

  local dst_dir
  dst_dir=$(python2 - <<'PY'
import distutils
import os
print(os.path.dirname(distutils.__file__))
PY
)
  mkdir -p "$dst_dir"
  cp -f "$src" "$dst_dir/archive_util.py"
  python2 -m py_compile "$dst_dir/archive_util.py" || true
  python2 - <<'PY'
from distutils import archive_util
print("repaired python2 distutils archive_util: %s" % archive_util.__file__)
PY
}

prepare_impala_bootstrap_maven_link() {
  local bootstrap_maven="/usr/local/apache-maven-3.9.2"
  if [ -x "${bootstrap_maven}/bin/mvn" ]; then
    return 0
  fi

  local candidate
  for candidate in \
    "${IMPALA_MAVEN_HOME:-}" \
    "${TRINO_MAVEN_HOME:-}" \
    /opt/modules/apache-maven-3.9.11 \
    /opt/modules/apache-maven-3.9.6 \
    /opt/modules/apache-maven-3.8.4; do
    if [ -n "$candidate" ] && [ -x "${candidate}/bin/mvn" ]; then
      mkdir -p /usr/local
      ln -sfn "$candidate" "$bootstrap_maven"
      log "Using existing Maven for Impala bootstrap: ${bootstrap_maven} -> ${candidate}"
      return 0
    fi
  done
}

prepare_impala_postgresql_tools() {
  local candidate_dir
  for candidate_dir in /usr/bin /usr/local/bin /usr/pgsql-*/bin /usr/lib/postgresql/*/bin; do
    if [ -x "${candidate_dir}/initdb" ]; then
      mkdir -p /usr/local/bin
      ln -sfn "${candidate_dir}/initdb" /usr/local/bin/initdb
      [ -x "${candidate_dir}/pg_ctl" ] && ln -sfn "${candidate_dir}/pg_ctl" /usr/local/bin/pg_ctl
      [ -x "${candidate_dir}/postgres" ] && ln -sfn "${candidate_dir}/postgres" /usr/local/bin/postgres
      export IMPALA_POSTGRES_INITDB=/usr/local/bin/initdb
      [ -x /usr/local/bin/pg_ctl ] && export IMPALA_POSTGRES_PG_CTL=/usr/local/bin/pg_ctl
      log "Using PostgreSQL tools for Impala: ${candidate_dir}"
      return 0
    fi
  done
  log "PostgreSQL initdb was not found yet; install postgresql-server if Impala bootstrap needs it."
}

prepare_impala_build_env() {
  log "Preparing Impala build environment cache"
  mkdir -p "$IMPALA_BUILD_ENV_HOME"

  if [ ! -s "$IMPALA_INFRA_TARBALL" ] && [ -n "$IMPALA_INFRA_URL" ]; then
    download_file "$IMPALA_INFRA_URL" "$IMPALA_INFRA_TARBALL"
  fi
  if [ ! -s "$IMPALA_TOOLCHAIN_TARBALL" ] && [ -n "$IMPALA_TOOLCHAIN_URL" ]; then
    download_file "$IMPALA_TOOLCHAIN_URL" "$IMPALA_TOOLCHAIN_TARBALL"
  fi

  if [ ! -d "$IMPALA_TOOLCHAIN_DIR" ] && [ -s "$IMPALA_TOOLCHAIN_TARBALL" ]; then
    mkdir -p "$IMPALA_TOOLCHAIN_DIR"
    tar -xzf "$IMPALA_TOOLCHAIN_TARBALL" --strip-components=1 -C "$IMPALA_TOOLCHAIN_DIR"
  fi

  mkdir -p /opt/enhance_env
  ln -sfn "$IMPALA_BUILD_ENV_HOME" /opt/enhance_env/impala_env
  repair_impala_python2_distutils
  prepare_impala_bootstrap_maven_link
  prepare_impala_postgresql_tools

  if [ "$REQUIRE_IMPALA_ENV" = "1" ]; then
    [ -s "$IMPALA_INFRA_TARBALL" ] || die "missing Impala infra tarball: $IMPALA_INFRA_TARBALL"
    [ -d "$IMPALA_TOOLCHAIN_DIR" ] || die "missing Impala toolchain directory: $IMPALA_TOOLCHAIN_DIR"
  elif [ ! -s "$IMPALA_INFRA_TARBALL" ] || [ ! -d "$IMPALA_TOOLCHAIN_DIR" ]; then
    log "Impala env cache is incomplete. Copy impala-build-env-infra.tar.gz and impala-build-env-toolchain.tar.gz to ${IMPALA_BUILD_ENV_HOME}, or rerun with IMPALA_INFRA_URL/IMPALA_TOOLCHAIN_URL."
  fi
}

extract_tar_gz_once() {
  local archive="$1"
  local dest="$2"
  local expected_dir="$3"

  if [ -d "$expected_dir" ]; then
    log "Directory exists, skip extract: $expected_dir"
    return
  fi

  log "Extracting $archive to $dest"
  mkdir -p "$dest"
  tar -xzf "$archive" -C "$dest"
  [ -d "$expected_dir" ] || die "expected directory not found after extract: $expected_dir"
}

extract_zip_once() {
  local archive="$1"
  local dest="$2"
  local expected_dir="$3"

  if [ -d "$expected_dir" ]; then
    log "Directory exists, skip extract: $expected_dir"
    return
  fi

  log "Extracting $archive to $dest"
  mkdir -p "$dest"
  unzip -q "$archive" -d "$dest"
  [ -d "$expected_dir" ] || die "expected directory not found after extract: $expected_dir"
}

miniconda_platform() {
  case "$(uname -m)" in
    x86_64 | amd64) echo "Linux-x86_64" ;;
    aarch64 | arm64) echo "Linux-aarch64" ;;
    *) die "unsupported Miniconda architecture: $(uname -m)" ;;
  esac
}

install_miniconda() {
  log "Installing Miniconda for Hue builds"
  local platform installer installer_path primary_url fallback_url
  platform="$(miniconda_platform)"
  installer="${MINICONDA_INSTALLER:-Miniconda3-latest-${platform}.sh}"
  installer_path="${DOWNLOAD_DIR}/${installer}"
  primary_url="${MINICONDA_URL:-https://mirrors.ustc.edu.cn/anaconda/miniconda/${installer}}"
  fallback_url="https://repo.anaconda.com/miniconda/${installer}"

  if [ -x "${MINICONDA_HOME}/bin/conda" ]; then
    log "Miniconda exists, skip install: ${MINICONDA_HOME}"
  else
    download_file_from_urls "$installer_path" "$primary_url" "$fallback_url"
    bash "$installer_path" -b -p "$MINICONDA_HOME"
  fi

  cat >"/root/.condarc" <<'EOF'
channels:
  - conda-forge
  - defaults
show_channel_urls: true
remote_connect_timeout_secs: 20
remote_read_timeout_secs: 120
remote_max_retries: 5
repodata_threads: 1
default_channels:
  - https://mirrors.ustc.edu.cn/anaconda/pkgs/main
  - https://mirrors.ustc.edu.cn/anaconda/pkgs/r
custom_channels:
  conda-forge: https://mirrors.ustc.edu.cn/anaconda/cloud
EOF
}

install_jdks() {
  local arch
  arch="$(uname -m)"
  if [ "$arch" != "x86_64" ] && [ "$arch" != "amd64" ]; then
    die "default JDK URLs are for x86_64; override JDK8_URL/JDK8_HOME/JDK17_URL/JDK17_HOME for ${arch}"
  fi

  log "Installing JDK 8 and JDK 17"
  download_file "$JDK8_URL" "${DOWNLOAD_DIR}/${JDK8_TAR}"
  extract_tar_gz_once "${DOWNLOAD_DIR}/${JDK8_TAR}" "$AMBARI_ENV_HOME" "$JDK8_HOME"

  download_file "$JDK17_URL" "${DOWNLOAD_DIR}/${JDK17_TAR}"
  extract_tar_gz_once "${DOWNLOAD_DIR}/${JDK17_TAR}" "$AMBARI_ENV_HOME" "$JDK17_HOME"
}

install_maven() {
  log "Installing Maven ${MAVEN_VERSION}"
  download_file "$MAVEN_URL" "${DOWNLOAD_DIR}/${MAVEN_TAR}"
  extract_tar_gz_once "${DOWNLOAD_DIR}/${MAVEN_TAR}" "$AMBARI_ENV_HOME" "$MAVEN_HOME"
  write_maven_settings "$MAVEN_HOME"

  if [ "$MAVEN39_HOME" != "$MAVEN_HOME" ]; then
    log "Installing Maven ${MAVEN39_VERSION} for Spark 3.5+ builds"
    download_file "$MAVEN39_URL" "${DOWNLOAD_DIR}/${MAVEN39_TAR}"
    extract_tar_gz_once "${DOWNLOAD_DIR}/${MAVEN39_TAR}" "$AMBARI_ENV_HOME" "$MAVEN39_HOME"
    write_maven_settings "$MAVEN39_HOME"
  fi
}

write_maven_settings() {
  local target_maven_home="${1:-$MAVEN_HOME}"
  local settings_file="${target_maven_home}/conf/settings.xml"
  mkdir -p "$(dirname "$settings_file")" /root/.m2 "$MAVEN_LOCAL_REPO"

  if [ -f "$settings_file" ] && [ ! -f "${settings_file}.orig" ]; then
    cp -a "$settings_file" "${settings_file}.orig"
  fi

  log "Writing Maven settings.xml with direct repository list"
  cat >"$settings_file" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.2.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.2.0 https://maven.apache.org/xsd/settings-1.2.0.xsd">
  <localRepository>${MAVEN_LOCAL_REPO}</localRepository>
  <profiles>
    <profile>
      <id>ambari-direct-repositories</id>
      <activation>
        <activeByDefault>true</activeByDefault>
      </activation>
      <repositories>
        <repository>
          <id>aliyun</id>
          <url>https://maven.aliyun.com/repository/public</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </repository>
        <repository>
          <id>aliyun-central</id>
          <url>https://maven.aliyun.com/repository/central</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </repository>
        <repository>
          <id>huawei</id>
          <url>https://repo.huaweicloud.com/repository/maven</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </repository>
        <repository>
          <id>huaweicloudsdk</id>
          <url>https://repo.huaweicloud.com/repository/maven/huaweicloudsdk</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </repository>
        <repository>
          <id>aliyun-jindodata</id>
          <url>https://jindodata-binary.oss-cn-shanghai.aliyuncs.com/mvn-repo/</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </repository>
        <repository>
          <id>cloudera-release</id>
          <url>https://repository.cloudera.com/content/repositories/releases/</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </repository>
        <repository>
          <id>cloudera-staging</id>
          <url>https://repository.cloudera.com/content/repositories/staging/</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </repository>
        <repository>
          <id>cloudera-libs</id>
          <url>https://repository.cloudera.com/repository/libs-release-local/</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </repository>
        <repository>
          <id>cdh-releases</id>
          <url>https://repository.cloudera.com/artifactory/cdh-releases-rcs</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </repository>
        <repository>
          <id>cdh-snapshots</id>
          <url>https://repository.cloudera.com/content/repositories/snapshots</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </repository>
        <repository>
          <id>confluent</id>
          <url>https://packages.confluent.io/maven</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </repository>
        <repository>
          <id>conjars</id>
          <url>https://conjars.wensel.net/repo/</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </repository>
        <repository>
          <id>datanucleus</id>
          <url>https://www.datanucleus.org/downloads/maven2/</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </repository>
        <repository>
          <id>shibboleth-releases</id>
          <url>https://build.shibboleth.net/maven/releases/</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </repository>
        <repository>
          <id>apache-snapshot1</id>
          <url>https://repository.apache.org/content/repositories/snapshots/</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </repository>
        <repository>
          <id>apache-snapshot2</id>
          <url>https://repository.apache.org/service/local/repositories/snapshots/content/</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </repository>
        <repository>
          <id>apache-snapshots</id>
          <url>https://repository.apache.org/content/repositories/snapshots/</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </repository>
      </repositories>
      <pluginRepositories>
        <pluginRepository>
          <id>aliyun</id>
          <url>https://maven.aliyun.com/repository/public</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </pluginRepository>
        <pluginRepository>
          <id>huawei</id>
          <url>https://repo.huaweicloud.com/repository/maven</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </pluginRepository>
        <pluginRepository>
          <id>confluent</id>
          <url>https://packages.confluent.io/maven</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </pluginRepository>
        <pluginRepository>
          <id>datanucleus</id>
          <url>https://www.datanucleus.org/downloads/maven2/</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </pluginRepository>
        <pluginRepository>
          <id>apache-snapshots</id>
          <url>https://repository.apache.org/content/repositories/snapshots/</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </pluginRepository>
      </pluginRepositories>
    </profile>
  </profiles>
  <activeProfiles>
    <activeProfile>ambari-direct-repositories</activeProfile>
  </activeProfiles>
</settings>
EOF

  cp -f "$settings_file" /root/.m2/settings.xml
}

install_gradle() {
  log "Installing Gradle ${GRADLE_VERSION}"
  download_file "$GRADLE_URL" "${DOWNLOAD_DIR}/${GRADLE_ZIP}"
  extract_zip_once "${DOWNLOAD_DIR}/${GRADLE_ZIP}" "$AMBARI_ENV_HOME" "$GRADLE_HOME"
  write_gradle_settings
}

write_gradle_settings() {
  local init_dir="${GRADLE_USER_HOME}/init.d"
  local init_file="${init_dir}/ambari-public-repositories.gradle"
  local props_file="${GRADLE_USER_HOME}/gradle.properties"

  mkdir -p "$init_dir"

  log "Writing Gradle public repository settings"
  cat >"$init_file" <<'EOF'
allprojects {
    buildscript {
        repositories {
            maven { url "https://plugins.gradle.org/m2/" }
            maven { url "https://maven.aliyun.com/repository/public" }
            maven { url "https://maven.aliyun.com/repository/central" }
            maven { url "https://repo.huaweicloud.com/repository/maven" }
            maven { url "https://repo.huaweicloud.com/repository/maven/huaweicloudsdk" }
            maven { url "https://jindodata-binary.oss-cn-shanghai.aliyuncs.com/mvn-repo/" }
            maven { url "https://repository.cloudera.com/content/repositories/releases/" }
            maven { url "https://repository.cloudera.com/content/repositories/staging/" }
            maven { url "https://repository.cloudera.com/repository/libs-release-local/" }
            maven { url "https://repository.cloudera.com/artifactory/cdh-releases-rcs" }
            maven { url "https://repository.cloudera.com/content/repositories/snapshots" }
            maven { url "https://packages.confluent.io/maven" }
            maven { url "https://conjars.wensel.net/repo/" }
            maven { url "https://www.datanucleus.org/downloads/maven2/" }
            maven { url "https://build.shibboleth.net/maven/releases/" }
            maven { url "https://repository.apache.org/content/repositories/snapshots/" }
            maven { url "https://repository.apache.org/service/local/repositories/snapshots/content/" }
            mavenCentral()
            mavenLocal()
        }
    }

    repositories {
        maven { url "https://plugins.gradle.org/m2/" }
        maven { url "https://maven.aliyun.com/repository/public" }
        maven { url "https://maven.aliyun.com/repository/central" }
        maven { url "https://repo.huaweicloud.com/repository/maven" }
        maven { url "https://repo.huaweicloud.com/repository/maven/huaweicloudsdk" }
        maven { url "https://jindodata-binary.oss-cn-shanghai.aliyuncs.com/mvn-repo/" }
        maven { url "https://repository.cloudera.com/content/repositories/releases/" }
        maven { url "https://repository.cloudera.com/content/repositories/staging/" }
        maven { url "https://repository.cloudera.com/repository/libs-release-local/" }
        maven { url "https://repository.cloudera.com/artifactory/cdh-releases-rcs" }
        maven { url "https://repository.cloudera.com/content/repositories/snapshots" }
        maven { url "https://packages.confluent.io/maven" }
        maven { url "https://conjars.wensel.net/repo/" }
        maven { url "https://www.datanucleus.org/downloads/maven2/" }
        maven { url "https://build.shibboleth.net/maven/releases/" }
        maven { url "https://repository.apache.org/content/repositories/snapshots/" }
        maven { url "https://repository.apache.org/service/local/repositories/snapshots/content/" }
        mavenCentral()
        mavenLocal()
    }
}
EOF

  if [ ! -f "$props_file" ]; then
    cat >"$props_file" <<'EOF'
org.gradle.daemon=false
org.gradle.parallel=false
org.gradle.jvmargs=-Xmx3g -XX:MaxMetaspaceSize=768m
EOF
  fi
}

install_ant_ivy() {
  log "Installing Ant ${ANT_VERSION} and Ivy ${IVY_VERSION}"
  download_file "$ANT_URL" "${DOWNLOAD_DIR}/${ANT_TAR}"
  extract_tar_gz_once "${DOWNLOAD_DIR}/${ANT_TAR}" "$AMBARI_ENV_HOME" "$ANT_HOME"

  download_file "$IVY_URL" "${DOWNLOAD_DIR}/${IVY_TAR}"
  extract_tar_gz_once "${DOWNLOAD_DIR}/${IVY_TAR}" "$AMBARI_ENV_HOME" "$IVY_HOME"

  local ivy_jar="${IVY_HOME}/ivy-${IVY_VERSION}.jar"
  if [ -f "$ivy_jar" ]; then
    mkdir -p "${ANT_HOME}/lib"
    cp -f "$ivy_jar" "${ANT_HOME}/lib/ivy.jar"
  fi
}

write_profile() {
  log "Writing environment profile: ${PROFILE_FILE}"
  cat >"$PROFILE_FILE" <<EOF
# Managed by ambari-env init_ubuntu22_no_docker.sh
export AMBARI_ENV_HOME="${AMBARI_ENV_HOME}"
export JAVA_HOME="${JDK8_HOME}"
export JDK8_HOME="${JDK8_HOME}"
export JDK17_HOME="${JDK17_HOME}"
export MAVEN_LEGACY_HOME="${MAVEN_HOME}"
export MAVEN39_HOME="${MAVEN39_HOME}"
export MAVEN_HOME="${MAVEN_ACTIVE_HOME}"
export MAVEN_LOCAL_REPO="${MAVEN_LOCAL_REPO}"
export MAVEN_HTTP_OPTS="${MAVEN_HTTP_OPTS}"
case " \${MAVEN_OPTS:-} " in
  *" -Dmaven.repo.local="*) ;;
  *) export MAVEN_OPTS="\${MAVEN_OPTS:-} -Dmaven.repo.local=\$MAVEN_LOCAL_REPO" ;;
esac
case " \${MAVEN_OPTS:-} " in
  *" -Dmaven.wagon.http.retryHandler.count="*) ;;
  *) export MAVEN_OPTS="\${MAVEN_OPTS:-} \$MAVEN_HTTP_OPTS" ;;
esac
export GRADLE_HOME="${GRADLE_HOME}"
export GRADLE_USER_HOME="${GRADLE_USER_HOME}"
export DORIS_BUILD_CACHE_HOME="${DORIS_BUILD_CACHE_HOME}"
export DORIS_NPM_CACHE="${DORIS_NPM_CACHE}"
export DORIS_CCACHE_DIR="${DORIS_CCACHE_DIR}"
export DORIS_CCACHE_MAXSIZE="${DORIS_CCACHE_MAXSIZE}"
export DORIS_SOURCE_CACHE_DIR="${DORIS_SOURCE_CACHE_DIR}"
export DORIS_NPM_REGISTRY="${DORIS_NPM_REGISTRY}"
export TRINO_JAVA_HOME="${TRINO_JDK_HOME}"
export TRINO_MAVEN_HOME="${TRINO_MAVEN_HOME}"
export TRINO_NODE_CACHE_DIR="${TRINO_NODE_CACHE_DIR}"
export PHANTOMJS_HOME="${PHANTOMJS_HOME}"
export PHANTOMJS_BIN="${PHANTOMJS_HOME}/bin/phantomjs"
export PHANTOMJS_CDNURL="${PHANTOMJS_CDNURL}"
export PHANTOMJS_OPENSSL_CONF="${PHANTOMJS_OPENSSL_CONF}"
export SUPERSET_BUILD_CACHE_HOME="${SUPERSET_BUILD_CACHE_HOME}"
export SUPERSET_CONDA_PKGS_DIR="${SUPERSET_CONDA_PKGS_DIR}"
export SUPERSET_PIP_CACHE_DIR="${SUPERSET_PIP_CACHE_DIR}"
export SUPERSET_NPM_CACHE="${SUPERSET_NPM_CACHE}"
export SUPERSET_NPM_REGISTRY="${SUPERSET_NPM_REGISTRY}"
export PUPPETEER_SKIP_DOWNLOAD=true
export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
export CYPRESS_INSTALL_BINARY=0
export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
export IMPALA_BUILD_ENV_HOME="${IMPALA_BUILD_ENV_HOME}"
export IMPALA_TOOLCHAIN_DIR="${IMPALA_TOOLCHAIN_DIR}"
export IMPALA_INFRA_TARBALL="${IMPALA_INFRA_TARBALL}"
if [ -x /usr/local/bin/initdb ]; then
  export IMPALA_POSTGRES_INITDB=/usr/local/bin/initdb
fi
if [ -x /usr/local/bin/pg_ctl ]; then
  export IMPALA_POSTGRES_PG_CTL=/usr/local/bin/pg_ctl
fi
export CUSTOM_NPM_REGISTRY="\$DORIS_NPM_REGISTRY"
export npm_config_cache="\$DORIS_NPM_CACHE"
export NPM_CONFIG_CACHE="\$DORIS_NPM_CACHE"
export npm_config_registry="\$DORIS_NPM_REGISTRY"
export NPM_CONFIG_REGISTRY="\$DORIS_NPM_REGISTRY"
export npm_config_prefer_offline=true
export npm_config_audit=false
export npm_config_fund=false
export npm_config_strict_ssl=false
export NPM_CONFIG_STRICT_SSL=false
export npm_config_fetch_retries=5
export npm_config_fetch_retry_mintimeout=20000
export npm_config_fetch_retry_maxtimeout=120000
export npm_config_phantomjs_cdnurl="\$PHANTOMJS_CDNURL"
export NPM_CONFIG_PHANTOMJS_CDNURL="\$PHANTOMJS_CDNURL"
export CCACHE_DIR="\$DORIS_CCACHE_DIR"
export CCACHE_MAXSIZE="\$DORIS_CCACHE_MAXSIZE"
export CCACHE_COMPILERCHECK=content
export ANT_HOME="${ANT_HOME}"
export IVY_HOME="${IVY_HOME}"
export R_PREFIX="${R_HOME}"
export PYTHON37_HOME="${PYTHON_HOME}"
export HADOOP_PY37_VENV="${PY37_VENV}"
export PIP_INDEX_URL="${PIP_INDEX_URL}"
export CONDA_HOME="${MINICONDA_HOME}"
export HUE_LD_LIBRARY_PATH="${MINICONDA_HOME}/lib"
[ -f "\$CONDA_HOME/etc/profile.d/conda.sh" ] && . "\$CONDA_HOME/etc/profile.d/conda.sh"
export PATH="\$JAVA_HOME/bin:\$MAVEN_HOME/bin:\$GRADLE_HOME/bin:\$ANT_HOME/bin:\$PHANTOMJS_HOME/bin:\$R_PREFIX/bin:\$PYTHON37_HOME/bin:\$HADOOP_PY37_VENV/bin:\$CONDA_HOME/bin:\$PATH"
alias ll='ls -alF --color=auto'
alias ls='ls --color=auto'
EOF

  # shellcheck disable=SC1090
  source "$PROFILE_FILE"
}

clone_repositories() {
  if [ "$CLONE_REPOS" != "1" ]; then
    log "Source checkout skipped because CLONE_REPOS=${CLONE_REPOS}"
    return
  fi

  log "Checking out Apache source repositories"
  mkdir -p "$AMBARI_ENV_HOME"

  local repos=(
    "${AMBARI_ENV_HOME}/ambari|branch-2.8.0|https://github.com/apache/ambari.git"
    "${AMBARI_ENV_HOME}/ambari3|branch-3.0.0|https://github.com/apache/ambari.git"
    "${AMBARI_ENV_HOME}/ambari-metrics|dependabot/maven/ambari-metrics-common/com.google.guava-guava-32.0.0-jre|https://github.com/apache/ambari-metrics.git"
    "${AMBARI_ENV_HOME}/bigtop|release-3.2.0|https://github.com/apache/bigtop.git"
    "${AMBARI_ENV_HOME}/ambari-infra|master|https://github.com/apache/ambari-infra.git"
  )

  local item target branch url clone_url
  for item in "${repos[@]}"; do
    IFS='|' read -r target branch url <<<"$item"
    clone_url="${GIT_PROXY_PREFIX}${url}"
    if [ -d "${target}/.git" ]; then
      log "Git repository exists, skip clone: ${target}"
    elif [ -e "$target" ]; then
      die "target exists but is not a git repository: ${target}"
    else
      log "Cloning ${url} (${branch}) to ${target}"
      git clone --branch "$branch" "$clone_url" "$target"
    fi
  done
}

configure_git_proxy() {
  if [ -n "$GIT_PROXY_PREFIX" ]; then
    log "Configuring git GitHub proxy prefix: ${GIT_PROXY_PREFIX}"
    git config --global url."${GIT_PROXY_PREFIX}https://github.com/".insteadOf "https://github.com/"
  fi
}

install_r() {
  log "Installing R ${R_VERSION}"
  local r_archive="${DOWNLOAD_DIR}/${R_TAR}"
  local r_src="${DOWNLOAD_DIR}/R-${R_VERSION}"
  local rscript_bin="${R_HOME}/bin/Rscript"

  if [ ! -x "${R_HOME}/bin/R" ]; then
    if command -v R >/dev/null 2>&1 && command -v Rscript >/dev/null 2>&1; then
      log "Using system R: $(command -v R)"
      rscript_bin="$(command -v Rscript)"
    else
      download_file_from_urls "$r_archive" "${R_URLS[@]}"
      rm -rf "$r_src"
      tar -xzf "$r_archive" -C "$DOWNLOAD_DIR"

      pushd "$r_src" >/dev/null
      ./configure --prefix="$R_HOME" --enable-R-shlib
      make -j"$(nproc)"
      make install
      popd >/dev/null
    fi
  else
    log "R exists, skip compile: ${R_HOME}"
  fi

  export -n R_HOME 2>/dev/null || true
  if [ -x "${R_HOME}/bin/R" ]; then
    export PATH="${R_HOME}/bin:${PATH}"
  fi

  install_r_packages "$rscript_bin"
}

install_r_packages() {
  log "Installing required R packages when missing"
  local rscript_bin="${1:-${R_HOME}/bin/Rscript}"
  env -u R_HOME "$rscript_bin" - <<'EOF'
repos <- c(
  USTC = "https://mirrors.ustc.edu.cn/CRAN/",
  Aliyun = "https://mirrors.aliyun.com/CRAN/",
  Cloud = "https://cloud.r-project.org/",
  CRAN = "https://cran.r-project.org/",
  TUNA = "https://mirrors.tuna.tsinghua.edu.cn/CRAN/"
)
options(timeout = max(600, getOption("timeout")), Ncpus = max(1, parallel::detectCores() - 1))
pkgs <- c(
  "knitr", "rmarkdown", "devtools", "e1071", "survival", "httr2", "gh",
  "htmlwidgets", "usethis", "pkgdown", "profvis", "roxygen2", "testthat"
)

missing_pkgs <- function() {
  pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
}

for (repo_name in names(repos)) {
  need <- missing_pkgs()
  if (!length(need)) {
    break
  }

  message("Installing missing R packages from ", repo_name, ": ", paste(need, collapse = ", "))
  options(repos = c(CRAN = repos[[repo_name]]))
  tryCatch(
    install.packages(need, dependencies = c("Depends", "Imports", "LinkingTo")),
    error = function(e) {
      message("R package install attempt failed for ", repo_name, ": ", conditionMessage(e))
    }
  )
}

missing <- missing_pkgs()
if (length(missing)) {
  stop("R packages are still missing after install: ", paste(missing, collapse = ", "))
} else {
  message("All required R packages are installed.")
}
EOF
}

pip_install_with_fallback() {
  local python_cmd="$1"
  shift
  local index_url

  for index_url in "${PIP_INDEX_URLS[@]}"; do
    log "Installing Python packages from ${index_url}: $*"
    "$python_cmd" -m pip config set global.index-url "$index_url" >/dev/null || true
    if "$python_cmd" -m pip install --upgrade --index-url "$index_url" "$@"; then
      PIP_INDEX_URL="$index_url"
      return 0
    fi
    log "Python package install failed from ${index_url}, trying next index."
  done

  return 1
}

install_python37() {
  log "Installing Python ${PYTHON_VERSION} and virtualenv"
  local py_archive="${DOWNLOAD_DIR}/${PYTHON_TAR}"
  local py_src="${DOWNLOAD_DIR}/Python-${PYTHON_VERSION}"
  local python_bin="${PYTHON_HOME}/bin/python3.7"
  local pip_bin="${PYTHON_HOME}/bin/pip3.7"

  if [ ! -x "$python_bin" ]; then
    download_file "$PYTHON_URL" "$py_archive"
    rm -rf "$py_src"
    tar -xzf "$py_archive" -C "$DOWNLOAD_DIR"

    pushd "$py_src" >/dev/null
    ./configure --prefix="$PYTHON_HOME" --with-ensurepip=install
    make -j"$(nproc)"
    make altinstall
    popd >/dev/null
  else
    log "Python exists, skip compile: ${PYTHON_HOME}"
  fi

  if [ ! -x "$pip_bin" ]; then
    local get_pip="${DOWNLOAD_DIR}/get-pip-${PYTHON_VERSION}.py"
    download_file "$GET_PIP_URL" "$get_pip"
    "$python_bin" "$get_pip"
  fi

  pip_install_with_fallback "$python_bin" 'pip<24.1' 'setuptools<69' wheel virtualenv

  if [ ! -x "${PY37_VENV}/bin/python" ]; then
    mkdir -p "$(dirname "$PY37_VENV")"
    "$python_bin" -m venv "$PY37_VENV"
  else
    log "Python virtualenv exists, skip create: ${PY37_VENV}"
  fi

  pip_install_with_fallback "${PY37_VENV}/bin/python" 'pip<24.1' 'setuptools<69' wheel virtualenv asciidoc

  ensure_symlink "$python_bin" /usr/local/bin/python3.7
  ensure_symlink "$pip_bin" /usr/local/bin/pip3.7
}

ensure_symlink() {
  local source_path="$1"
  local link_path="$2"

  if [ -e "$link_path" ] && [ ! -L "$link_path" ]; then
    log "Path exists and is not a symlink, keep it unchanged: ${link_path}"
    return
  fi

  ln -sfn "$source_path" "$link_path"
}

verify_installation() {
  log "Verifying installed toolchain"
  export JAVA_HOME="$JDK8_HOME"
  export MAVEN_HOME="$MAVEN_ACTIVE_HOME"
  export PATH="$JAVA_HOME/bin:$MAVEN_HOME/bin:$GRADLE_HOME/bin:$ANT_HOME/bin:$PHANTOMJS_HOME/bin:$R_HOME/bin:$PYTHON_HOME/bin:$PY37_VENV/bin:$PATH"

  java -version
  "$JDK17_HOME/bin/java" -version
  mvn -version
  gradle --version
  ant -version
  phantomjs --version
  conda --version
  if command -v ccache >/dev/null 2>&1; then
    ccache --version | sed -n '1p'
  fi
  local r_bin="${R_HOME}/bin/R"
  if [ ! -x "$r_bin" ]; then
    r_bin="$(command -v R)"
  fi
  env -u R_HOME "$r_bin" --version >"${LOG_DIR}/R.version" 2>&1
  sed -n '1p' "${LOG_DIR}/R.version"
  "$PY37_VENV/bin/python" --version
}

main() {
  require_root
  require_ubuntu22
  prepare_dirs

  configure_apt_mirror
  install_packages
  configure_system_basics

  install_jdks
  install_maven
  install_trino_toolchain
  install_gradle
  install_ant_ivy
  install_phantomjs
  install_miniconda
  prepare_superset_build_cache
  ensure_doris_thirdparty
  prepare_doris_build_cache
  prepare_impala_build_env
  configure_git_proxy
  write_profile

  clone_repositories
  install_r
  install_python37
  write_profile

  verify_installation
  log "Ambari Ubuntu 22.04 bare-metal initialization finished."
}

main "$@"
