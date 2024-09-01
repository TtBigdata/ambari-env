#!/bin/bash
# Licensed to the Apache Software Foundation (ASF) under one或more
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

set -e

echo "############## INSTALL AMBARI SERVER AND AGENT START #############"

# 读取文件内容并分别存储主机名和IP地址
FILE_PATH="/scripts/.init_done" # 请确保文件路径正确
HOSTNAMES=()
IPS=()

if [[ -f "$FILE_PATH" ]]; then
  while IFS= read -r line; do
    # 拆分主机名和IP地址
    HOSTNAME=$(echo "$line" | cut -d'@' -f1)
    IP=$(echo "$line" | cut -d'@' -f2)
    HOSTNAMES+=("$HOSTNAME")
    IPS+=("$IP")
  done <"$FILE_PATH"
else
  echo "文件 $FILE_PATH 不存在"
  exit 1
fi

# 从IP列表中选取最小的IP作为服务端
IFS=$'\n' sorted_ips=($(sort <<<"${IPS[*]}"))
unset IFS
SERVER_IP="${sorted_ips[0]}"
CLIENT_IPS=("${sorted_ips[@]:1}")

# 获取当前机器的IP地址
CURRENT_IP=$(hostname -I | awk '{print $1}')

# 自动获取 JAVA_HOME 路径
get_java_home() {
  JAVA_BIN=$(readlink -f $(which java))
  JAVA_HOME=$(dirname $(dirname $JAVA_BIN))
  echo $JAVA_HOME
}

JAVA_HOME=$(get_java_home)
echo "Detected JAVA_HOME: $JAVA_HOME"

# 下载并解压 MySQL Connector/J
download_mysql_connector() {
  CONNECTOR_DIR="/opt/modules"
  CONNECTOR_FILE="mysql-connector-java-5.1.48.tar.gz"
  CONNECTOR_URL="https://mirrors.aliyun.com/mysql/Connector-J/mysql-connector-java-5.1.48.tar.gz"
  CONNECTOR_JAR="mysql-connector-java-5.1.48-bin.jar"
  TARGET_JAR="/usr/share/java/mysql-connector-java.jar"

  # 创建目录
  mkdir -p $CONNECTOR_DIR

  if [[ ! -f "$CONNECTOR_DIR/$CONNECTOR_FILE" ]]; then
    echo "下载 MySQL Connector/J 5.1.48..."
    wget -q $CONNECTOR_URL -O "$CONNECTOR_DIR/$CONNECTOR_FILE"
  else
    echo "MySQL Connector/J 已存在，不需要下载。"
  fi

  if [[ ! -f "$CONNECTOR_DIR/$CONNECTOR_JAR" ]]; then
    echo "解压 MySQL Connector/J..."
    tar -xzf "$CONNECTOR_DIR/$CONNECTOR_FILE" -C $CONNECTOR_DIR
  else
    echo "MySQL Connector/J 已解压，不需要再次解压。"
  fi

  echo "移动 MySQL Connector/J 到 /usr/share/java/"
  mv "$CONNECTOR_DIR/mysql-connector-java-5.1.48/$CONNECTOR_JAR" $TARGET_JAR
}

# 创建 Ambari 用户
create_ambari_user() {
  if ! id "ambari" &>/dev/null; then
    echo "创建 Ambari 用户..."
    useradd -r -m -U -d /var/lib/ambari-server -s /bin/bash ambari
  else
    echo "Ambari 用户已存在。"
  fi
}

# 初始化数据库
initialize_database() {
  echo "初始化数据库..."

  # 检查并创建数据库和用户
  mysql -uroot -proot <<EOF
CREATE DATABASE IF NOT EXISTS ambari;
CREATE DATABASE IF NOT EXISTS hive;

CREATE USER IF NOT EXISTS 'ambari'@'%' IDENTIFIED BY 'ambari';
CREATE USER IF NOT EXISTS 'hive'@'%' IDENTIFIED BY 'hive';

GRANT ALL PRIVILEGES ON *.* TO 'ambari'@'%' IDENTIFIED BY 'ambari' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'ambari'@'localhost' IDENTIFIED BY 'ambari' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'ambari'@'$SERVER_IP' IDENTIFIED BY 'ambari' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'ambari'@'centos1' IDENTIFIED BY 'ambari' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'ambari'@'centos2' IDENTIFIED BY 'ambari' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'ambari'@'centos3' IDENTIFIED BY 'ambari' WITH GRANT OPTION;

GRANT ALL PRIVILEGES ON *.* TO 'hive'@'%' IDENTIFIED BY 'hive' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'hive'@'localhost' IDENTIFIED BY 'hive' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'hive'@'$SERVER_IP' IDENTIFIED BY 'hive' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'hive'@'centos1' IDENTIFIED BY 'hive' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'hive'@'centos2' IDENTIFIED BY 'hive' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'hive'@'centos3' IDENTIFIED BY 'hive' WITH GRANT OPTION;

FLUSH PRIVILEGES;
EOF

  # 检查并执行 Ambari DDL 脚本
  if ! mysql -u ambari -pambari -e "USE ambari; SHOW TABLES LIKE 'metainfo';" | grep -q 'metainfo'; then
    echo "执行 Ambari DDL 脚本..."
    mysql -u ambari -pambari ambari </var/lib/ambari-server/resources/Ambari-DDL-MySQL-CREATE.sql
  else
    echo "Ambari DDL 脚本已执行，不需要再次执行。"
  fi
}

# 安装 Ambari Server
install_ambari_server() {
  echo "安装 Ambari Server..."
  yum install -y ambari-server
}

# 使用 expect 自动化 ambari-server setup
setup_ambari_server() {
  echo "配置 Ambari Server..."
  ambari-server setup --jdbc-db=mysql --jdbc-driver=$TARGET_JAR
  expect -c "
  set timeout -1
  spawn ambari-server setup
  expect \"Customize user account for ambari-server daemon\"
  send \"n\r\"

  # 检查 JDK 状态并进行相应操作
  expect {
    \"Enter choice (1):\" {
      send \"2\r\"
      expect \"Path to JAVA_HOME:\"
      send \"$::env(JAVA_HOME)\r\"
    }
    \"Do you want to change\" {
      send \"n\r\"
    }
  }

  expect {
    \"Completing setup...\" {
      # Do nothing, just continue
    }
    \"Enable Ambari Server to download and install GPL\" {
      send \"y\r\"
    }
  }

  expect \"Enter advanced database configuration\" {
    send \"y\r\"
  }
  expect \"Choose one of the following options:\" {
    send \"3\r\"
  }
  expect \"Hostname\"
  send \"$SERVER_IP\r\"
  expect \"Port\"
  send \"3306\r\"
  expect \"Database name\"
  send \"ambari\r\"
  expect \"Username\"
  send \"ambari\r\"
  expect \"Enter Database Password\"
  send \"ambari\r\"

  expect {
    \"Configuring ambari database...\" {
      # Do nothing, just continue
    }
    \"Re-enter password: \" {
      send \"ambari\r\"
    }
  }

  expect {
    \"Configuring remote database connection properties...\" {
      # Do nothing, just continue
    }
    \"Should ambari use existing default jdbc\" {
      send \"y\r\"
    }
  }

  expect \"Proceed with configuring remote database connection properties\"
  send \"y\r\"
  expect eof
  "
}

# 启动 Ambari Server
start_ambari_server() {
  echo "启动 Ambari Server..."
  ambari-server restart
}

# 安装 Ambari Agent
install_ambari_agent() {
  echo "安装 Ambari Agent..."
  yum install -y ambari-agent
  ambari-agent restart
}

# 在服务器上安装并配置 Ambari Server 和 Agent
configure_server() {
  echo "在服务器 $SERVER_IP 上安装并配置 Ambari Server 和 Agent..."
  if [[ "$CURRENT_IP" == "$SERVER_IP" ]]; then
    create_ambari_user
    download_mysql_connector
    install_ambari_server
    initialize_database
    setup_ambari_server
    start_ambari_server
    install_ambari_agent
  else
    ssh $SERVER_IP "$(declare -f create_ambari_user); create_ambari_user"
    ssh $SERVER_IP "$(declare -f download_mysql_connector); download_mysql_connector"
    ssh $SERVER_IP "$(declare -f install_ambari_server); install_ambari_server"
    ssh $SERVER_IP "$(declare -f initialize_database); initialize_database"
    ssh $SERVER_IP "$(declare -f setup_ambari_server); setup_ambari_server"
    ssh $SERVER_IP "$(declare -f start_ambari_server); start_ambari_server"
    ssh $SERVER_IP "$(declare -f install_ambari_agent); install_ambari_agent"
  fi
  echo "Ambari Server 和 Agent 配置完成并已启动。"
}

# 在客户端上安装 Ambari Agent
configure_client() {
  for CLIENT_IP in "${CLIENT_IPS[@]}"; do
    echo "在客户端 $CLIENT_IP 上安装并配置 Ambari Agent..."
    if [[ "$CURRENT_IP" == "$CLIENT_IP" ]]; then
      install_ambari_agent
    else
      ssh $CLIENT_IP "$(declare -f install_ambari_agent); install_ambari_agent"
    fi
    echo "Ambari Agent $CLIENT_IP 安装完成。"
  done
}

# 主函数
main() {
  configure_server
  configure_client
  echo "Ambari Server 和 Agent 设置完成。"
}

# 执行主函数
main

echo "############## INSTALL AMBARI SERVER AND AGENT END #############"
