#!/bin/bash

systemctl stop unattended-upgrades
set -e
apt update
NEEDRESTART_SUSPEND=1 apt install  -y vim git libssl-dev gcc-arm-linux-gnueabi build-essential libncurses5-dev bzip2 make gcc g++ grep bc curl bison flex openssl lzop ccache unzip zlib1g-dev file ca-certificates wget cmake texinfo xz-utils libelf-dev zip libgmp-dev libncurses-dev g++ gawk m4 cpio binutils-dev ninja-build u-boot-tools zstd clang libbz2-1.0 libsqlite3-dev libreadline-dev tk-dev libgdbm-dev libdb5.3 libpcap-dev libexpat1-dev liblzma-dev libffi-dev libc6-dev automake libtool libc++-dev libc++abi-dev libgtest-dev golang-go libgles2-mesa-dev libpulse-dev libxml2-dev llvm llvm-dev python3 lld crossbuild-essential-arm64

NEEDRESTART_SUSPEND=1 apt install curl repo wget git-lfs -y
ln -sf /usr/bin/python3 /usr/bin/python
git config --global user.name openfde && git config --global user.email openfde@openfde.com
mkdir aosp -p
cd aosp
git config --file /root/.gitconfig --includes --replace-all color.ui auto
repo init -u https://github.com/openfde/fde-manifests -b fde_14  
cp /root/aosp/.repo/repo/repo /usr/bin/repo
repo init -u https://github.com/openfde/fde-manifests -b fde_14  --git-lfs
repo sync -j20
