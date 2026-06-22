#!/bin/bash

# Docker Compose 下载脚本
# 使用 ghfast.top 代理加速下载

VERSION="v2.34.0"
PROXY="https://ghfast.top/"

# 检测系统架构
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH_SUFFIX="x86_64"
        ;;
    aarch64|arm64)
        ARCH_SUFFIX="aarch64"
        ;;
    *)
        echo "不支持的架构: $ARCH"
        exit 1
        ;;
esac

# 检测操作系统
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

FILENAME="docker-compose-${OS}-${ARCH_SUFFIX}"
DOWNLOAD_URL="${PROXY}https://github.com/docker/compose/releases/download/${VERSION}/${FILENAME}"

echo "系统: ${OS}"
echo "架构: ${ARCH_SUFFIX}"
echo "下载地址: ${DOWNLOAD_URL}"
echo ""

# 下载
curl -L -o docker-compose "${DOWNLOAD_URL}"

if [ $? -eq 0 ]; then
    chmod +x docker-compose
    echo ""
    echo "下载完成: $(pwd)/docker-compose"
    echo "版本: $(./docker-compose --version)"
    echo ""
    echo "安装到系统目录请执行:"
    echo "  sudo mv docker-compose /usr/local/bin/"
else
    echo "下载失败"
    exit 1
fi