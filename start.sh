#!/bin/bash

apt install -y git
git clone https://github.com/warlice/openfde-dailybuild
./openfde-dailybuild/make.sh
