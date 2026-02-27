#!/bin/bash

git clone https://gitee.com/openfde/quick_start_to_compile_linux_programs
cd quick_start_to_compile_linux_programs
./build_linux_for_fde.sh

cd /root/
tar -xf img.tgz -C /
git clone https://gitee.com/openfde/make_deb
cd make_deb
./mkdeb.sh version aospver 
deb_num=` ls debian/*.deb |wc -l`
if [ $deb_num -ne 1 ];then
	echo "deb file not found"
	exit 1
fi
debname=`ls debian/*.deb`
mkdir /root/debdir
cp -a $debname /root/debdir/

