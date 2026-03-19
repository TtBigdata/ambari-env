#!/bin/bash
# Kylin V10 ARM 环境依赖安装脚本

set -ex

PKG_INSTALL="dnf -y install"
command -v dnf >/dev/null 2>&1 || PKG_INSTALL="yum -y install"

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
  sharutils