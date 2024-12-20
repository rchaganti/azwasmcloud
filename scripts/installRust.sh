#!/bin/sh

# update an upgrade package list and install curl and other essentials
apt-get update
apt-get -y upgrade
apt install -y curl gcc make build-essential
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
