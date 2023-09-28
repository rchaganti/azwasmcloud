#!/bin/sh

# update an upgrade package list and install curl
apt-get update
apt-get -y upgrade
apt-get install -y apt-transport-https ca-certificates curl

curl -s https://packagecloud.io/install/repositories/wasmcloud/core/script.deb.sh | bash
apt-get update
apt install wash