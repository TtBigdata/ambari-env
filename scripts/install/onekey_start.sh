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

echo "############## INSTALL start #############"

source /scripts/install/ssh/install_no_pass.sh

source /scripts/install/ssh/install_ntp_sync.sh

source /scripts/install/ssh/install_yum_repo.sh

source /scripts/install/ssh/install_mariadb.sh

source /scripts/install/ambari/install_ambari.sh

echo "############## INSTALL end #############"
