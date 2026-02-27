#!/bin/bash

git clone https://gitee.com/openfde/quick_start_to_compile_linux_programs
cd quick_start_to_compile_linux_programs
./build_linux_for_fde.sh

cd ../
mkdir /usr/share/waydroid-extra/images -p
tar -xv img.tgz -C /
git clone https://gitee.com/openfde/make_deb
cd make_deb
./mkdeb ver_dailybuild 14
deb_num=`ls debian/*.deb |wc -l `
if [ $deb_num -ne 1 ];then
        echo "failed"
else    
fi  
