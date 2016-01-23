#!/bin/bash
# Copyright 2015 Niall Frederick Weedon
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# # You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
set -e

cd /tmp

curl https://iojs.org/dist/v3.3.0/iojs-v3.3.0-linux-x64.tar.gz > iojs.tar.gz
tar -zxvf iojs.tar.gz -C /tmp

ls -l /tmp
ls -l /tmp/iojs-v3.3.0-linux-x64/bin

export PATH=$PATH:/tmp/iojs-v3.3.0-linux-x64/bin
chmod +x /tmp/iojs-v3.3.0-linux-x64/bin/iojs
chmod +x /tmp/iojs-v3.3.0-linux-x64/bin/node
iojs -v
node -v
