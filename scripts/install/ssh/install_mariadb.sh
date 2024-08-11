#!/bin/bash

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

set -e

echo "############## INSTALL MARIADB 10.11 START #############"

# 定义MariaDB root用户密码
ROOT_PASSWORD="root"

# 读取文件内容并分别存储主机名和IP地址
FILE_PATH="/scripts/.init_done"  # 请确保文件路径正确
HOSTNAMES=()
IPS=()

if [[ -f "$FILE_PATH" ]]; then
    while IFS= read -r line; do
        # 拆分主机名和IP地址
        HOSTNAME=$(echo "$line" | cut -d'@' -f1)
        IP=$(echo "$line" | cut -d'@' -f2)
        HOSTNAMES+=("$HOSTNAME")
        IPS+=("$IP")
    done < "$FILE_PATH"
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

# 创建必要的目录
create_directories() {
  mkdir -p /var/run/mysqld
  chown mysql:mysql /var/run/mysqld
}

# 写入优化后的MariaDB配置文件
write_my_cnf() {
  cat <<EOL > /etc/my.cnf
[client]
# 设置客户端默认字符集为utf8mb4
default-character-set=utf8mb4

[mysqld]
# 基本设置
user=mysql
port=3306
basedir=/usr
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
pid-file=/var/run/mysqld/mysqld.pid

# 设置字符集为utf8mb4
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci

# 使用InnoDB存储引擎
default-storage-engine=InnoDB

# InnoDB引擎优化
# 设置InnoDB缓冲池大小，建议设置为物理内存的70-80%
innodb_buffer_pool_size=1G

# 设置InnoDB日志文件大小，建议设置为缓冲池大小的25%
innodb_log_file_size=256M

# 设置InnoDB日志缓冲区大小
innodb_log_buffer_size=64M

# 启用InnoDB文件每表存储
innodb_file_per_table=1

# 设置InnoDB锁等待超时时间
innodb_lock_wait_timeout=50

# 启用InnoDB缓冲池实例
innodb_buffer_pool_instances=4

# 启用InnoDB双写缓冲区
innodb_doublewrite=1

# 启用InnoDB自适应哈希索引
innodb_adaptive_hash_index=1

# 启用InnoDB文件格式
innodb_file_format=Barracuda

# 启用InnoDB压缩表
innodb_compression_level=6

# 启用InnoDB快速启动
innodb_fast_shutdown=1

# 启用InnoDB严格模式
innodb_strict_mode=1

# 启用InnoDB状态监控
innodb_status_file=1

# 启用InnoDB表空间监控
innodb_stats_on_metadata=0

# 启用InnoDB线程并发
innodb_thread_concurrency=8

# 网络设置
# 允许所有IP地址连接
bind-address=0.0.0.0

# 最大连接数
max_connections=500

# 日志设置
# 启用慢查询日志
slow_query_log=1
slow_query_log_file=/var/log/mysql/slow-query.log
long_query_time=2

[mysqldump]
# 设置mysqldump默认字符集为utf8mb4
default-character-set=utf8mb4
EOL
}

# 检查并安装Expect
install_expect() {
  if ! command -v expect &> /dev/null; then
    echo "未安装Expect。正在安装..."
    yum install -y expect
  else
    echo "Expect已安装。"
  fi
}

# 检查并安装MariaDB服务器
install_mariadb_server() {
  if ! command -v /usr/bin/mysql &> /dev/null; then
    echo "未安装MariaDB。正在安装..."
    yum install -y MariaDB-server MariaDB-client
  else
    # 检查MariaDB版本
    MARIADB_VERSION=$(/usr/bin/mysql -V | awk '{ print $5 }' | awk -F. '{ print $1 }')
    if [[ "$MARIADB_VERSION" -ne 10 ]]; then
      echo "当前安装的MariaDB版本不是10.x。正在卸载..."
      yum remove -y MariaDB-server MariaDB-client
      echo "重新安装MariaDB 10.11..."
      yum install -y MariaDB-server MariaDB-client
    else
      echo "MariaDB 10.x 已安装。"
    fi
  fi
}

# 检查并安装MariaDB客户端
install_mariadb_client() {
  if ! command -v /usr/bin/mysql &> /dev/null; then
    echo "未安装MariaDB客户端。正在安装..."
    yum install -y MariaDB-client
  else
    echo "MariaDB客户端已安装。"
  fi
}

# 检查并停止占用3306端口的进程
stop_port_3306() {
  if lsof -i:3306 &> /dev/null; then
    echo "检测到3306端口被占用。正在停止相关进程..."
    lsof -i:3306 | awk 'NR>1 {print $2}' | xargs kill -9
  else
    echo "3306端口未被占用。"
  fi
}

# 启动MariaDB守护进程
start_mariadb() {
  /usr/sbin/mysqld --user=mysql --datadir=/var/lib/mysql --pid-file=/var/run/mysqld/mysqld.pid &
  sleep 5  # 等待MariaDB启动
}

# 安全安装MariaDB
secure_mariadb() {
  # 自动化 mariadb-secure-installation 的交互部分
  expect -c "
  set timeout 10
  spawn mariadb-secure-installation
  expect \"Enter current password for root (enter for none):\"
  send \"\r\"
  expect \"Switch to unix_socket authentication\"
  send \"n\r\"
  expect \"Change the root password?\"
  send \"y\r\"
  expect \"New password:\"
  send \"$ROOT_PASSWORD\r\"
  expect \"Re-enter new password:\"
  send \"$ROOT_PASSWORD\r\"
  expect \"Remove anonymous users?\"
  send \"y\r\"
  expect \"Disallow root login remotely?\"
  send \"n\r\"
  expect \"Remove test database and access to it?\"
  send \"y\r\"
  expect \"Reload privilege tables now?\"
  send \"y\r\"
  expect eof
  "
}

# 配置MariaDB以允许远程连接
configure_remote_access() {
  mysql -uroot -p"$ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$ROOT_PASSWORD' WITH GRANT OPTION; FLUSH PRIVILEGES;"
}

# 在服务器上安装并配置MariaDB
configure_server() {
  echo "在服务器 $SERVER_IP 上安装并配置MariaDB..."
  if [[ "$CURRENT_IP" == "$SERVER_IP" ]]; then
    create_directories
    write_my_cnf
    install_expect
    install_mariadb_server
    stop_port_3306
    start_mariadb
    secure_mariadb
    configure_remote_access
  else
    ssh $SERVER_IP "$(declare -f create_directories); create_directories"
    ssh $SERVER_IP "$(declare -f write_my_cnf); write_my_cnf"
    ssh $SERVER_IP "$(declare -f install_expect); install_expect"
    ssh $SERVER_IP "$(declare -f install_mariadb_server); install_mariadb_server"
    ssh $SERVER_IP "$(declare -f stop_port_3306); stop_port_3306"
    ssh $SERVER_IP "$(declare -f start_mariadb); start_mariadb"
    ssh $SERVER_IP "$(declare -f secure_mariadb); secure_mariadb"
    ssh $SERVER_IP "$(declare -f configure_remote_access); configure_remote_access"
  fi
  echo "MariaDB服务器配置完成并已启动。"
}

# 在客户端上安装MariaDB客户端
configure_client() {
  for CLIENT_IP in "${CLIENT_IPS[@]}"; do
    echo "在客户端 $CLIENT_IP 上安装并配置MariaDB客户端..."
    if [[ "$CURRENT_IP" == "$CLIENT_IP" ]]; then
      install_mariadb_client
    else
      ssh $CLIENT_IP "$(declare -f install_mariadb_client); install_mariadb_client"
    fi
    echo "MariaDB客户端 $CLIENT_IP 配置完成。"
  done
}

# 主函数
main() {
  configure_server
  configure_client
  echo "MariaDB设置完成。"
}

# 执行主函数
main

echo "############## INSTALL MARIADB 10.11 END #############"
