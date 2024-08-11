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

# init env
source /scripts/system/init/init_env.sh

# setup git
yum install -y git

# setup jdk
source /scripts/system/init/setup_jdk.sh

# setup mvn
source /scripts/system/init/setup_mvn.sh && source /scripts/system/before/maven/load_settings.sh

# setup gradle
source /scripts/system/init/setup_gradle.sh && source /scripts/system/before/gradle/load_settings.sh

# setup ivy ant
source /scripts/system/init/setup_ivy_ant.sh

#下载ambari 代码
source /scripts/system/init/setup_github_code.sh

#处理编译环境
source /scripts/system/init/setup_build_env.sh

#处理虚拟环境
source /scripts/system/init/setup_virtual_env.sh

#处理r环境
source /scripts/system/init/setup_r_env.sh

# 将本机ip写入到
source /scripts/util/write_ip.sh

# start sshd server
/usr/sbin/sshd -D
#nohup /usr/sbin/sshd -D >>/dev/null 2>&1 &
echo "sshd start over!!!!"
