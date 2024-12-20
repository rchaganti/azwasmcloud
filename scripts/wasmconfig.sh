#!/bin/sh

# update an upgrade package list and install curl
apt update
apt -y upgrade
apt -y install apt-transport-https ca-certificates curl
apt -y install gcc make build-essential

# install wash
curl -s https://packagecloud.io/install/repositories/wasmcloud/core/script.deb.sh | bash
apt-get update
apt install wash

# install cosmo
bash -c "$(curl -fsSL https://cosmonic.sh/install.sh)"

# install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
