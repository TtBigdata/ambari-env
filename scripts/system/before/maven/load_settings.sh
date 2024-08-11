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
echo "############## LOAD MAVEN_SETTINGS start #############"

NEXUS_IP=$(cat /scripts/system/before/nexus/.lock)
echo "读取nexus 服务器地址：$NEXUS_IP"
cp -rv /opt/modules/conf/mvn/settings.xml $MAVEN_HOME/conf
# 刷写地址数据
sed -i "s/localhost/$NEXUS_IP/g" $MAVEN_HOME/conf/settings.xml

echo "############## LOAD MAVEN_SETTINGS end #############"