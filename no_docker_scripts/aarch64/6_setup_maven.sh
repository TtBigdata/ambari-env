#!/bin/bash
# Kylin V10 ARM64 裸机环境 Maven 安装脚本
# Author: JaneTTR

set -e

echo "############## SETUP MAVEN start #############"

MAVEN_VERSION="3.8.4"
MAVEN_FILE_PATH="/opt/modules/apache-maven-${MAVEN_VERSION}-bin.tar.gz"
MAVEN_HOME_PATH="/opt/modules/apache-maven-${MAVEN_VERSION}"
MAVEN_DOWNLOAD_URL="https://repo.huaweicloud.com/apache/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz"

mkdir -p /opt/modules

# ------- 下载 -------
if [ -f "$MAVEN_FILE_PATH" ] && [ -s "$MAVEN_FILE_PATH" ]; then
    echo "Maven 包已存在，跳过下载: $MAVEN_FILE_PATH"
else
    echo "下载 Maven ${MAVEN_VERSION}..."
    curl -L --retry 3 --retry-delay 2 --connect-timeout 30 --max-time 300 \
        -o "$MAVEN_FILE_PATH" "$MAVEN_DOWNLOAD_URL"
    [ -s "$MAVEN_FILE_PATH" ] || { echo "ERROR: Maven 下载失败"; exit 1; }
fi

# ------- 解压 -------
if [ -d "$MAVEN_HOME_PATH" ]; then
    echo "Maven 目录已存在，跳过解压: $MAVEN_HOME_PATH"
else
    echo "解压 Maven..."
    tar -zxf "$MAVEN_FILE_PATH" -C /opt/modules
fi

# ------- 配置 MAVEN_HOME -------
echo "配置 MAVEN_HOME..."
if grep -q "^export MAVEN_HOME=" /etc/profile; then
    sed -i "s#^export MAVEN_HOME=.*#export MAVEN_HOME=${MAVEN_HOME_PATH}#" /etc/profile
else
    echo "export MAVEN_HOME=${MAVEN_HOME_PATH}" >> /etc/profile
fi

if ! grep -q 'MAVEN_HOME/bin' /etc/profile; then
    echo 'export PATH=$MAVEN_HOME/bin:$PATH' >> /etc/profile
fi

export MAVEN_HOME="${MAVEN_HOME_PATH}"
export PATH="$MAVEN_HOME/bin:$PATH"

# ------- 生成 settings.xml（直连国内镜像，替代 Nexus 代理） -------
SETTINGS_FILE="${MAVEN_HOME_PATH}/conf/settings.xml"
echo "生成 Maven settings.xml -> ${SETTINGS_FILE}..."

# 备份原始文件
cp -f "${SETTINGS_FILE}" "${SETTINGS_FILE}.orig" 2>/dev/null || true

cat > "${SETTINGS_FILE}" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.2.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.2.0
                              https://maven.apache.org/xsd/settings-1.2.0.xsd">

  <localRepository>/root/.m2/repository</localRepository>

  <!--
    镜像说明（对应原 Nexus 代理仓库，现直连）：
      aliyun-public     <- aliyun public（central + jcenter 聚合）
      aliyun-central    <- aliyun central
      aliyun-spring     <- aliyun spring
      huawei            <- 华为云 maven
      apache-snapshots  <- Apache snapshots
      cloudera 系列、confluent、conjars、datanucleus 等按需在 profiles 中启用
  -->
  <mirrors>
    <!-- 阿里云公共仓库（聚合 central + jcenter，优先命中） -->
    <mirror>
      <id>aliyun-public</id>
      <mirrorOf>central</mirrorOf>
      <name>Aliyun Public Repository</name>
      <url>https://maven.aliyun.com/repository/public</url>
    </mirror>
    <!-- 华为云 Maven（备用） -->
    <mirror>
      <id>huawei</id>
      <mirrorOf>central</mirrorOf>
      <name>Huawei Maven Repository</name>
      <url>https://repo.huaweicloud.com/repository/maven</url>
    </mirror>
  </mirrors>

  <profiles>
    <profile>
      <id>repos</id>
      <activation><activeByDefault>true</activeByDefault></activation>
      <repositories>

        <repository>
          <id>aliyun-central</id>
          <url>https://maven.aliyun.com/repository/central</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>false</enabled></snapshots>
        </repository>

        <repository>
          <id>aliyun-spring</id>
          <url>https://maven.aliyun.com/repository/spring</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>false</enabled></snapshots>
        </repository>

        <repository>
          <id>aliyun-spring-plugin</id>
          <url>https://maven.aliyun.com/repository/spring-plugin</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>false</enabled></snapshots>
        </repository>

        <repository>
          <id>huawei</id>
          <url>https://repo.huaweicloud.com/repository/maven</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>false</enabled></snapshots>
        </repository>

        <repository>
          <id>apache-snapshots</id>
          <url>https://repository.apache.org/content/repositories/snapshots/</url>
          <releases><enabled>false</enabled></releases>
          <snapshots><enabled>true</enabled><updatePolicy>daily</updatePolicy></snapshots>
        </repository>

        <repository>
          <id>cloudera-mirror</id>
          <url>https://repository.cloudera.com/repository/cloudera-mirror</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </repository>

        <repository>
          <id>cloudera-release</id>
          <url>https://repository.cloudera.com/content/repositories/releases/</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>false</enabled></snapshots>
        </repository>

        <repository>
          <id>cloudera-libs</id>
          <url>https://repository.cloudera.com/repository/libs-release-local/</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>false</enabled></snapshots>
        </repository>

        <repository>
          <id>confluent</id>
          <url>https://packages.confluent.io/maven</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>false</enabled></snapshots>
        </repository>

        <repository>
          <id>datanucleus</id>
          <url>https://www.datanucleus.org/downloads/maven2/</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>false</enabled></snapshots>
        </repository>

        <repository>
          <id>aliyun-jindodata</id>
          <url>https://jindodata-binary.oss-cn-shanghai.aliyuncs.com/mvn-repo/</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>false</enabled></snapshots>
        </repository>

      </repositories>

      <pluginRepositories>
        <pluginRepository>
          <id>aliyun-public</id>
          <url>https://maven.aliyun.com/repository/public</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>false</enabled></snapshots>
        </pluginRepository>
        <pluginRepository>
          <id>aliyun-spring-plugin</id>
          <url>https://maven.aliyun.com/repository/spring-plugin</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>false</enabled></snapshots>
        </pluginRepository>
      </pluginRepositories>
    </profile>
  </profiles>

</settings>
EOF

echo "settings.xml 已生成"

# ------- 验证 -------
echo "MAVEN_HOME=${MAVEN_HOME}"
mvn -version

echo "############## SETUP MAVEN end #############"
