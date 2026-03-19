#!/bin/bash
# Kylin V10 ARM64 裸机环境 Gradle 安装脚本
# Author: JaneTTR

set -e

echo "############## SETUP GRADLE start #############"

# ------- 架构校验 -------
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ]; then
    echo "WARNING: 当前架构为 $ARCH，本脚本针对 aarch64 优化"
fi

GRADLE_VERSION="5.6.4"
GRADLE_FILE_PATH="/opt/modules/gradle-${GRADLE_VERSION}-bin.zip"
GRADLE_HOME_PATH="/opt/modules/gradle-${GRADLE_VERSION}"
# 华为云镜像，aarch64 网络更友好
GRADLE_DOWNLOAD_URL="https://mirrors.huaweicloud.com/gradle/gradle-${GRADLE_VERSION}-bin.zip"

mkdir -p /opt/modules

# ------- 下载 -------
if [ -f "$GRADLE_FILE_PATH" ] && [ -s "$GRADLE_FILE_PATH" ]; then
    echo "Gradle 包已存在，跳过下载: $GRADLE_FILE_PATH"
else
    echo "下载 Gradle ${GRADLE_VERSION}..."
    curl -L --retry 3 --retry-delay 2 --connect-timeout 30 --max-time 600 \
        -o "$GRADLE_FILE_PATH" "$GRADLE_DOWNLOAD_URL"
    [ -s "$GRADLE_FILE_PATH" ] || { echo "ERROR: Gradle 下载失败"; exit 1; }
fi

# ------- 解压 -------
if [ -d "$GRADLE_HOME_PATH" ]; then
    echo "Gradle 目录已存在，跳过解压: $GRADLE_HOME_PATH"
else
    echo "解压 Gradle..."
    unzip -q "$GRADLE_FILE_PATH" -d /opt/modules
fi

# ------- 配置 GRADLE_HOME -------
echo "配置 GRADLE_HOME..."
if grep -q "^export GRADLE_HOME=" /etc/profile; then
    sed -i "s#^export GRADLE_HOME=.*#export GRADLE_HOME=${GRADLE_HOME_PATH}#" /etc/profile
else
    echo "export GRADLE_HOME=${GRADLE_HOME_PATH}" >> /etc/profile
fi

if ! grep -q 'GRADLE_HOME/bin' /etc/profile; then
    echo 'export PATH=$GRADLE_HOME/bin:$PATH' >> /etc/profile
fi

export GRADLE_HOME="${GRADLE_HOME_PATH}"
export PATH="$GRADLE_HOME/bin:$PATH"

# ------- 生成 Gradle 全局 init 脚本（配置多仓库） -------
GRADLE_INIT_DIR="/root/.gradle/init.d"
GRADLE_INIT_FILE="${GRADLE_INIT_DIR}/repos.gradle"
mkdir -p "$GRADLE_INIT_DIR"

echo "生成 Gradle 全局仓库配置 -> ${GRADLE_INIT_FILE}..."

cat > "${GRADLE_INIT_FILE}" <<'GRADLE_EOF'
// Gradle 全局仓库配置（aarch64 Kylin V10 裸机环境）
// 覆盖所有项目的 repositories，优先使用国内镜像

allprojects {
    buildscript {
        repositories {
            maven { url "https://maven.aliyun.com/repository/public" }
            maven { url "https://maven.aliyun.com/repository/central" }
            maven { url "https://maven.aliyun.com/repository/spring" }
            maven { url "https://maven.aliyun.com/repository/spring-plugin" }
            maven { url "https://repo.huaweicloud.com/repository/maven" }
            maven { url "https://repo.huaweicloud.com/repository/maven/huaweicloudsdk" }
            maven { url "https://repository.cloudera.com/repository/cloudera-mirror" }
            maven { url "https://repository.cloudera.com/content/repositories/releases/" }
            maven { url "https://repository.cloudera.com/content/repositories/staging/" }
            maven { url "https://repository.cloudera.com/repository/libs-release-local/" }
            maven { url "https://repository.cloudera.com/artifactory/cdh-releases-rcs" }
            maven { url "https://repository.cloudera.com/content/repositories/snapshots" }
            maven { url "https://packages.confluent.io/maven" }
            maven { url "https://conjars.wensel.net/repo/" }
            maven { url "https://www.datanucleus.org/downloads/maven2/" }
            maven { url "https://repository.apache.org/content/repositories/snapshots/" }
            maven { url "https://repository.apache.org/service/local/repositories/snapshots/content/" }
            maven { url "https://native-toolchain.s3.amazonaws.com/build/cdp_components/45689292/maven" }
            maven { url "https://jindodata-binary.oss-cn-shanghai.aliyuncs.com/mvn-repo/" }
            maven { url "https://build.shibboleth.net/maven/releases/" }
            mavenCentral()
            mavenLocal()
        }
    }

    repositories {
        // 国内镜像优先
        maven {
            name = "aliyun"
            url = uri("https://maven.aliyun.com/repository/public")
        }
        maven {
            name = "aliyun-central"
            url = uri("https://maven.aliyun.com/repository/central")
        }
        maven {
            name = "aliyun-spring"
            url = uri("https://maven.aliyun.com/repository/spring")
        }
        maven {
            name = "aliyun-spring-plugin"
            url = uri("https://maven.aliyun.com/repository/spring-plugin")
        }
        maven {
            name = "huawei"
            url = uri("https://repo.huaweicloud.com/repository/maven")
        }
        maven {
            name = "huaweicloudsdk"
            url = uri("https://repo.huaweicloud.com/repository/maven/huaweicloudsdk")
        }
        // Cloudera 系列
        maven {
            name = "cloudera-mirror"
            url = uri("https://repository.cloudera.com/repository/cloudera-mirror")
        }
        maven {
            name = "cloudera-release"
            url = uri("https://repository.cloudera.com/content/repositories/releases/")
        }
        maven {
            name = "cloudera-staging"
            url = uri("https://repository.cloudera.com/content/repositories/staging/")
        }
        maven {
            name = "cloudera-libs"
            url = uri("https://repository.cloudera.com/repository/libs-release-local/")
        }
        maven {
            name = "cdh-releases"
            url = uri("https://repository.cloudera.com/artifactory/cdh-releases-rcs")
        }
        maven {
            name = "cdh-snapshots"
            url = uri("https://repository.cloudera.com/content/repositories/snapshots")
        }
        // 其他第三方仓库
        maven {
            name = "confluent"
            url = uri("https://packages.confluent.io/maven")
        }
        maven {
            name = "conjars"
            url = uri("https://conjars.wensel.net/repo/")
        }
        maven {
            name = "datanucleus"
            url = uri("https://www.datanucleus.org/downloads/maven2/")
        }
        // Apache snapshots
        maven {
            name = "apache-snapshot1"
            url = uri("https://repository.apache.org/content/repositories/snapshots/")
        }
        maven {
            name = "apache-snapshot2"
            url = uri("https://repository.apache.org/service/local/repositories/snapshots/content/")
        }
        // Impala / CDP toolchain
        maven {
            name = "impala-toolchain"
            url = uri("https://native-toolchain.s3.amazonaws.com/build/cdp_components/45689292/maven")
        }
        // JindoData
        maven {
            name = "aliyun-jindodata"
            url = uri("https://jindodata-binary.oss-cn-shanghai.aliyuncs.com/mvn-repo/")
        }
        // Shibboleth
        maven {
            name = "shibboleth-releases"
            url = uri("https://build.shibboleth.net/maven/releases/")
        }
        mavenCentral()
        mavenLocal()
    }
}
GRADLE_EOF

echo "repos.gradle 已生成"

# ------- 配置 gradle.properties（全局 JVM 参数，适配 aarch64） -------
GRADLE_PROPS_FILE="/root/.gradle/gradle.properties"
echo "配置 ${GRADLE_PROPS_FILE}..."

if [ ! -f "$GRADLE_PROPS_FILE" ]; then
    cat > "$GRADLE_PROPS_FILE" <<'PROPS_EOF'
# Gradle 全局属性（aarch64 Kylin V10）
org.gradle.daemon=false
org.gradle.parallel=false
org.gradle.jvmargs=-Xmx2g -XX:MaxMetaspaceSize=512m
PROPS_EOF
    echo "gradle.properties 已生成"
else
    echo "gradle.properties 已存在，跳过生成"
fi

# ------- 验证 -------
echo "GRADLE_HOME=${GRADLE_HOME}"
gradle --version

echo "############## SETUP GRADLE end #############"
