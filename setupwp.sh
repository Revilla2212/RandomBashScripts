#!/bin/bash

setxkbmap es
apt-get install netlink libnl-3-dev libnl-genl-3-dev libssl-dev
git clone https://github.com/wifiphisher/wifiphisher.git
cd wifiphisher/
sudo python3 setup.py install
