#!/bin/sh
set -e

curl https://iojs.org/dist/latest/iojs-v3.3.0-linux-x64.tar.gz > iojs.tar.gz
tar -zxvf iojs.tar.gz -C ~
export PATH=$PATH:~/iojs-v3.3.0-linux-x64/bin
chmod +x ~/iojs-v3.3.0-linux-x64/bin/iojs
chmod +x ~/iojs-v3.3.0-linux-x64/bin/node
iojs -v
node -v
