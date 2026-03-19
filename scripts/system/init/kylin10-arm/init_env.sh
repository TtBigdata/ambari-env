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
# Author: JaneTTR (Kylin V10 ARM only)

set -ex
echo "############## INIT KYLIN V10 ARM start #############"
FLAG_FILE="/var/lib/init/.lock"
mkdir -p /var/lib/init

# ========== Kylin V10 repo 模板（通过 Nexus 组仓库） ==========
# 假设 Nexus 已创建组仓库：yum-public-kylinv10
# 组仓库成员至少包含：kylin-v10-sp3 -> https://update.cs2c.com.cn/NS/V10/V10SP3/
write_repo_kylin_v10() {
  local host="$1"
  if [ -z "$host" ]; then
    echo "Usage: write_repo_kylin_v10 <NEXUS_HOST_OR_IP>" >&2
    return 2
  fi

  cat >/etc/yum.repos.d/kylin-v10.repo <<EOF
[kylin-base]
name=Kylin V10 SP3 - Base (via Nexus group)
baseurl=http://$host:8081/repository/yum-public-kylinv10/os/adv/lic/base/\$basearch/
enabled=1
gpgcheck=0
metadata_expire=6h

[kylin-updates]
name=Kylin V10 SP3 - Updates (via Nexus group)
baseurl=http://$host:8081/repository/yum-public-kylinv10/os/adv/lic/updates/\$basearch/
enabled=1
gpgcheck=0
metadata_expire=6h

[epol]
name=openEuler EPOL main (via Nexus group)
baseurl=http://$host:8081/repository/yum-public-kylinv10/EPOL/main/\$basearch
enabled=1
gpgcheck=0
countme=1
metadata_expire=6h
EOF

  yum clean all >/dev/null 2>&1 || true
}


# ========== 修补 /etc/profile ==========

fixed_hostname() {
  local profile="/etc/profile"

  # 1. 删除旧的 hostnamectl 版本
  sed -i '/^HOSTNAME=`\/usr\/bin\/hostnamectl/d' "$profile"

  # 2. 删除我们定义的标记块
  sed -i '/^# >>> HOSTNAME-BEGIN$/,/^# <<< HOSTNAME-END$/d' "$profile"

  # 3. 在 export PATH… 的前一行插入新块
  sed -i '/^export PATH USER LOGNAME MAIL HOSTNAME HISTSIZE HISTCONTROL$/i \
# >>> HOSTNAME-BEGIN\
\nHOSTNAME=$(/usr/bin/hostname 2>/dev/null)\
\nexport HOSTNAME\
\n# <<< HOSTNAME-END' "$profile"
}


# ========== Kylin V10 ARM 初始化 ==========
init_kylin_v10() {
  rm -rf /etc/yum.repos.d/*.repo.rpmnew /etc/yum.repos.d/ambari-bigtop* || true
  (dnf clean all || true) && (dnf clean packages || true)
  (yum clean all || true)

  echo "执行 Kylin V10 ARM 初始化脚本"

  # 优先 dnf，找不到回退 yum
  PKG_INSTALL="dnf -y install"
  command -v dnf >/dev/null 2>&1 || PKG_INSTALL="yum -y install"

  # 常用工具 & 运行时（ARM 版本去掉 x86 专属包：isa-l、libpmem）
  ${PKG_INSTALL} \
  curl wget vim tar unzip which sudo less lsof git patch rsync \
  net-tools iproute hostname passwd \
  openssh-server openssh-clients \
  procps-ng iputils \
  gcc gcc-c++ make cmake autoconf automake libtool m4 autoconf-archive pkgconf \
  rpm-build \
  asciidoc docbook2X xmlto \
  python3 python3-pip python2-devel \
  zlib-devel libzstd-devel \
  bzip2-devel snappy-devel libzip-devel \
  libtirpc-devel krb5-devel openssl-devel libxml2-devel \
  protobuf protobuf-devel protobuf-compiler \
  lzo-devel \
  fuse fuse-devel fuse-libs \
  cppunit-devel \
  cyrus-sasl cyrus-sasl-devel cyrus-sasl-gssapi \
  libgsasl-devel \
  libtirpc libtirpc-devel pkgconf-pkg-config \
  kylin-lsb \
  sharutils || true
}


# ========== 主流程（仅 Kylin V10） ==========
rm_init_repos() {
  NEXUS_IP=$(cat /scripts/system/before/nexus/.lock)
  echo "读取 nexus 服务器地址：$NEXUS_IP"

  # 统一小写，避免大小写导致匹配失败
  OS_ID=$(grep -oP '^ID="?([^"]+)"?' /etc/os-release | cut -d= -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]')
  OS_VERSION_ID_RAW=$(grep -oP '^VERSION_ID="?([^"]+)"?' /etc/os-release | cut -d= -f2 | tr -d '"')
  OS_VERSION_ID=$(echo "${OS_VERSION_ID_RAW}" | tr '[:upper:]' '[:lower:]')
  PRETTY=$(grep -oP '^PRETTY_NAME="?([^"]+)"?' /etc/os-release | cut -d= -f2- | tr -d '"')
  PRETTY_LC=$(echo "$PRETTY" | tr '[:upper:]' '[:lower:]')

  echo "调试: OS_ID=${OS_ID}, VERSION_ID=${OS_VERSION_ID_RAW}, PRETTY_NAME=${PRETTY}"

  # 判断是否为 Kylin V10：ID 必须为 kylin，且版本包含 v10/10
  IS_KYLIN_V10=0
  if [[ "$OS_ID" == "kylin" ]]; then
    if [[ "$OS_VERSION_ID" =~ ^v?10($|[^0-9]) ]] || echo "$PRETTY_LC" | grep -q 'v10'; then
      IS_KYLIN_V10=1
    fi
  fi

  if [[ $IS_KYLIN_V10 -eq 1 ]]; then
    write_repo_kylin_v10 "$NEXUS_IP"
    echo "repo 文件已写入，正在初始化 Kylin V10 ARM ..."
    init_kylin_v10
    fixed_hostname
  else
    echo "当前系统不是 Kylin V10 (检测到: OS_ID=${OS_ID}, VERSION_ID=${OS_VERSION_ID_RAW}). 脚本仅支持 Kylin V10。" >&2
    exit 1
  fi
}

rm_init_repos

# ========== 首次初始化的一次性操作 ==========
if [ ! -f "$FLAG_FILE" ]; then
  echo 'root:root' | chpasswd || true
  ssh-keygen -A || true

  # 确保 sshd_config 允许 root 登录
  if [ ! -f "/etc/ssh/sshd_config" ]; then
    touch /etc/ssh/sshd_config
  fi
  grep -q '^PermitRootLogin' /etc/ssh/sshd_config \
    && sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    || echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config

  # 全局 alias 配置（带 color）
  grep -qxF "alias ll='ls -alF --color=auto'" /etc/profile || echo "alias ll='ls -alF --color=auto'" >> /etc/profile
  grep -qxF "alias ls='ls --color=auto'" /etc/profile   || echo "alias ls='ls --color=auto'"   >> /etc/profile

  touch "$FLAG_FILE"
else
  echo "Kylin V10 ARM 已经完成初始化"
fi

echo "############## INIT KYLIN V10 ARM end #############"
