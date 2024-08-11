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

set -ex
echo "############## INIT YUM start #############"
FLAG_FILE="/var/lib/init/.lock"
mkdir -p /var/lib/init

rm_init_repos() {
  NEXUS_IP=$(cat /scripts/system/before/nexus/.lock)
  echo "读取nexus 服务器地址：$NEXUS_IP"
  cat >/etc/yum.repos.d/yum-public.repo <<EOF
[yum-public-base]
name=YUM Public Repository
baseurl=http://$NEXUS_IP:8081/repository/yum-public/\$releasever/os/\$basearch/
enabled=1
gpgcheck=0
[yum-public-update]
name=YUM Public Repository
baseurl=http://$NEXUS_IP:8081/repository/yum-public/\$releasever/updates/\$basearch/
enabled=1
gpgcheck=0
[yum-public-extras]
name=YUM Public Repository
baseurl=http://$NEXUS_IP:8081/repository/yum-public/\$releasever/extras/\$basearch/
enabled=1
gpgcheck=0
[yum-public-centosplus]
name=YUM Public Repository
baseurl=http://$NEXUS_IP:8081/repository/yum-public/\$releasever/centosplus/\$basearch/
enabled=1
gpgcheck=0
[yum-public-scl]
name=YUM Public Repository
baseurl=http://$NEXUS_IP:8081/repository/yum-public/7.9.2009/sclo/\$basearch/sclo/
enabled=1
gpgcheck=0
[yum-public-scl-rh]
name=YUM Public Repository
baseurl=http://$NEXUS_IP:8081/repository/yum-public/7.9.2009/sclo/\$basearch/rh/
enabled=1
gpgcheck=0
[yum-public-epel]
name=YUM Public Repository
baseurl=http://$NEXUS_IP:8081/repository/yum-public/\$releasever/\$basearch/
enabled=1
gpgcheck=0
[yum-public-mariadb]
name=YUM Public Repository
baseurl=http://$NEXUS_IP:8081/repository/yum-public/yum/10.11/centos7-amd64/
enabled=1
gpgcheck=0
EOF

  echo "repo 文件已写入 正在初始repo ..."
  # exec logic
  rm -rf /etc/yum.repos.d/CentOS*
  rm -rf /etc/yum.repos.d/epel*
  rm -rf /etc/yum.repos.d/ambari-bigtop*
  yum clean all #&& yum makecache
  echo "执行初始化脚本"
  yum -y install centos-release-scl centos-release-scl-rh openssh-server passwd sudo net-tools unzip wget
  rm -rf /etc/yum.repos.d/CentOS*
}

rm_init_repos

if [ ! -f "$FLAG_FILE" ]; then
  echo 'root:root' | chpasswd
  ssh-keygen -A
  if [ ! -f "/etc/ssh/sshd_config" ]; then
    touch /etc/ssh/sshd_config
  fi
  sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config
  # 写入ll
  grep -qxF 'alias ll="ls -al"' /etc/profile || sed -i '$ a alias ll="ls -al"' /etc/profile
  source /etc/profile
  touch "$FLAG_FILE"
  echo "source /etc/profile" >>/root/.bashrc
else
  echo "yum 已经完成初始化"
fi
echo "############## INIT YUM end #############"
