#!/bin/bash
# Kylin V10 ARM64 裸机环境 JDK 安装脚本
# 安装 JDK 8（毕昇JDK，华为国内 CDN）+ JDK 17（华为镜像）
# 默认 JAVA_HOME 指向 JDK 8
# Author: JaneTTR

set -e

echo "############## SETUP JDK start #############"

# ------- 架构检查 -------
ARCH="$(uname -m)"
[[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]] || { echo "ERROR: 当前架构不是 aarch64: $ARCH"; exit 1; }

mkdir -p /opt/modules

# ------- JDK 8：毕昇JDK aarch64（华为 Kunpeng 专项优化，国内 CDN） -------
JDK8_FILENAME="bisheng-jdk-8u472-b11-linux-aarch64.tar.gz"
JDK8_FILE_PATH="/opt/modules/${JDK8_FILENAME}"
JDK8_HOME="/opt/modules/bisheng-jdk-8u472-b11"
JDK8_URLS=(
    "https://mirrors.huaweicloud.com/kunpeng/archive/compiler/bisheng_jdk/${JDK8_FILENAME}"
    "https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u472-b11/OpenJDK8U-jdk_aarch64_linux_hotspot_8u472b11.tar.gz"
)
JDK8_ADOPTIUM_HOME="/opt/modules/jdk8u472-b11"

# ------- JDK 17：毕昇JDK 17 aarch64（同镜像，备用 OpenJDK 官方） -------
JDK17_FILENAME="bisheng-jdk-17.0.17-b11-linux-aarch64.tar.gz"
JDK17_FILE_PATH="/opt/modules/${JDK17_FILENAME}"
JDK17_HOME="/opt/modules/bisheng-jdk-17.0.17-b11"
JDK17_URLS=(
    "https://mirrors.huaweicloud.com/kunpeng/archive/compiler/bisheng_jdk/${JDK17_FILENAME}"
    "https://mirrors.huaweicloud.com/openjdk/17.0.2/openjdk-17.0.2_linux-aarch64_bin.tar.gz"
)

# ------- 下载函数（多源依次重试） -------
download_file() {
    local dest="$1"
    shift
    local urls=("$@")

    if [ -f "$dest" ] && [ -s "$dest" ]; then
        echo "已存在，跳过下载: $dest"
        return 0
    fi

    for url in "${urls[@]}"; do
        echo "尝试下载: $url"
        if curl -L --retry 3 --retry-delay 2 --connect-timeout 30 --max-time 600 \
                -o "$dest" "$url" && [ -s "$dest" ]; then
            echo "下载成功: $dest"
            return 0
        else
            echo "下载失败，切换下一个源..."
            rm -f "$dest"
        fi
    done

    echo "ERROR: 所有源均下载失败: $dest"
    exit 1
}

# ------- 安装 JDK 8 -------
echo ">>> 安装 JDK 8（毕昇JDK 8u472）..."
download_file "$JDK8_FILE_PATH" "${JDK8_URLS[@]}"

if [ ! -d "$JDK8_HOME" ] && [ ! -d "$JDK8_ADOPTIUM_HOME" ]; then
    echo "解压 JDK 8..."
    tar -zxf "$JDK8_FILE_PATH" -C /opt/modules
fi

# 自动识别实际解压目录（毕昇 or Adoptium 兜底）
if [ -d "$JDK8_HOME" ]; then
    JDK8_FINAL_HOME="$JDK8_HOME"
elif [ -d "$JDK8_ADOPTIUM_HOME" ]; then
    JDK8_FINAL_HOME="$JDK8_ADOPTIUM_HOME"
else
    JDK8_FINAL_HOME="$(ls -d /opt/modules/*jdk*8* /opt/modules/*jdk8* 2>/dev/null | head -n1)"
    [ -d "$JDK8_FINAL_HOME" ] || { echo "ERROR: 找不到 JDK 8 解压目录"; exit 1; }
fi
echo "JDK 8 目录: $JDK8_FINAL_HOME"

# ------- 安装 JDK 17 -------
echo ">>> 安装 JDK 17（毕昇JDK 17.0.17）..."
download_file "$JDK17_FILE_PATH" "${JDK17_URLS[@]}"

if [ ! -d "$JDK17_HOME" ]; then
    echo "解压 JDK 17..."
    tar -zxf "$JDK17_FILE_PATH" -C /opt/modules
    # 兜底：可能落盘的是 OpenJDK 官方包（目录名不同）
    [ -d "$JDK17_HOME" ] || JDK17_HOME="$(ls -d /opt/modules/*jdk*17* /opt/modules/jdk-17* 2>/dev/null | head -n1)"
fi
[ -d "$JDK17_HOME" ] || { echo "ERROR: 找不到 JDK 17 解压目录"; exit 1; }
echo "JDK 17 目录: $JDK17_HOME"

# ------- 配置 JAVA_HOME（默认 JDK 8） -------
echo ">>> 配置 JAVA_HOME -> JDK 8..."
sed -i '/^export JAVA_HOME=/d' /etc/profile
sed -i '/JAVA_HOME\/bin/d' /etc/profile
echo "export JAVA_HOME=${JDK8_FINAL_HOME}" >> /etc/profile
echo 'export PATH=$PATH:$JAVA_HOME/bin' >> /etc/profile

export JAVA_HOME="${JDK8_FINAL_HOME}"
export PATH="$PATH:$JAVA_HOME/bin"

echo "JAVA_HOME=${JAVA_HOME}"
java -version

echo ""
echo "JDK 8  路径: ${JDK8_FINAL_HOME}"
echo "JDK 17 路径: ${JDK17_HOME:-未安装}"
echo "当前默认 JAVA_HOME 为 JDK 8。切换 JDK 17 时修改 /etc/profile 中的 JAVA_HOME 并重新 source。"
echo "############## SETUP JDK end #############"
