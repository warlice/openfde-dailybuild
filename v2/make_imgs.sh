#!/bin/bash


LOGPATH=/root/make_imgs.log
function log(){
  s=`date "+%y%m%d_%H%M%S:"`
  echo  "$s $1" >> $LOGPATH
}



function call_next_start_deb_make() {
	invoke_id=`aliyun ecs RunCommand --RegionId cn-beijing  --Name "call_next_deb_make_task" --Type "RunShellScript" --InstanceId.1 i-2zedqszo15pm336f5kpk \
	  --CommandContent "nohup bash /root/v2/call_start_deb_task.sh $1 $2 $3 $4 $5 1>/dev/null 2>&1"  | jq -r '.InvokeId'` 
	if [ $? != 0 ];then
		return 1
	fi
	sleep 10
	for i in {1..10}; do
	    result=`aliyun ecs DescribeInvocationResults --RegionId cn-beijing  --InvokeId "$invoke_id"`
	    status=$(echo "$result" | jq -r '.Invocation.InvocationResults.InvocationResult[0].InvokeRecordStatus')
	    invocationStatus=$(echo "$result" | jq -r '.Invocation.InvocationResults.InvocationResult[0].InvocationStatus')
	    log "invocation current status: $status"
	    if [ "$status" = "Finished" ]; then
	      log "invocation current status: $status"
	      if [ "$invocationStatus" = "Success" ]; then
			 return 0
	      else
			 return 1
	      fi
	    elif [ "$status" = "Failed" ]; then
		log "end: exec start_deb_task failed "
		return 1
	    fi
	    sleep 10
	done
}

log "step 1: stop_unattended-upgrades" 
systemctl stop unattended-upgrades
set -e

if [ ! -e "/root/aosp" ];then
	log "step 2: install dependens " 
	apt update
	NEEDRESTART_SUSPEND=1 apt install  -y vim git libssl-dev gcc-arm-linux-gnueabi build-essential libncurses5-dev bzip2 make gcc g++ grep bc curl bison flex openssl lzop ccache unzip zlib1g-dev file ca-certificates wget cmake texinfo xz-utils libelf-dev zip libgmp-dev libncurses-dev g++ gawk m4 cpio binutils-dev ninja-build u-boot-tools zstd clang libbz2-1.0 libsqlite3-dev libreadline-dev tk-dev libgdbm-dev libdb5.3 libpcap-dev libexpat1-dev liblzma-dev libffi-dev libc6-dev automake libtool libc++-dev libc++abi-dev libgtest-dev golang-go libgles2-mesa-dev libpulse-dev libxml2-dev llvm llvm-dev python3 lld crossbuild-essential-arm64 meson glslang-tools python3-mako curl repo wget git-lfs jq
	ln -sf /usr/bin/python3 /usr/bin/python
	log "step 3: git set user name " 
	git config --global user.name openfde && git config --global user.email openfde@openfde.com
fi

if [ "$1" = "version" ];then
	ver=$2
	aospver=$3
	arch=$4
	num=$5
else
	ver=`date "+%y%m%d%H"`
	aospver=14
	arch=arm64
	num=1
fi
mkdir aosp -p
log "mount /dev/nvme1n1 aosp " 
mount /dev/nvme1n1 aosp
cd aosp

log "step 7: source envsetup.sh " 
source build/envsetup.sh  
log "step 8: syncFdeApk " 
set +e
syncFdeApk 
if [ $? != 0 ];then
	for i in {1..10}; do
		log  "step 8: syncFdeApk  $i again " 
		source build/envsetup.sh  
		syncFdeApk 
		if [ $? = 0 ];then
			break
		fi
		sleep 10
	done
fi
set -e
source build/envsetup.sh  
if [ $arch = "arm64" ];then
	log "step 9: breakfast fde_x100_arm64 user " 
	breakfast fde_x100_arm64 user >>$LOGPATH
else
	log "step 9: breakfast fde_arm64_only user " 
	breakfast fde_arm64_only user >>$LOGPATH
fi
log "step 10: make -j26 "
set +e 
make -j26 1>>/root/make1.log 2>&1
if [ $? != 0 ];then
	#give a second chance to download all the code
	sleep 30
	log  "step 10: make 24 second " 
	make -j24 
	if [ $? != 0 ];then
		sleep 20
		for i in {1..5}; do
			log  "step 10: try make 18 for 5 times " 
			make -j18
			if [ $? = 0 ];then
				break
			fi
			sleep 20
		done
		for i in {1..5}; do
			log  "step 10: try make 12 for 5 times " 
			make -j12
			if [ $? = 0 ];then
				break
			fi
			sleep 10
		done
	fi
fi
cd /root
if [ ! -e make_deb ];then
	for i in {1..10}; do
		log "step 11: clone make_deb again in 10 times"
		git clone https://github.com/openfde/make_deb 
		if [  -e make_deb ];then
			break
		fi
		sleep 10
	done
fi
set -e
cd make_deb
log  "step 12: copy system.img and vendor.img to make_deb "
if [ $arch = "arm64" ];then
	out="/root/aosp/out/target/product/fde_arm64"
else
	out="/root/aosp/out/target/product/fde_arm64_only"
fi
cp -a "$out"/system.img system.img
cp -a "$out"/vendor.img vendor.img
log "step 14: packapk.sh -y "
bash packapk.sh  -y
log "step 15: tar -zcvpf img.tgz "
tar -cvpf - /usr/share/waydroid-extra |xz -T0 > img.tgz
dst_dir="daily-images"
if [ "$1" != "daily" ];then
	dst_dir="openfde-images"
fi
if [ "$arch" = "arm64" ];then
	dstimg=img.tgz
else
	dstimg=img64only.tgz
fi
log "step 16: oss upload img.tgz to $dst_dir successfully" 
aliyun ossutil -e oss-us-east-1-internal.aliyuncs.com cp -f img.tgz  oss://fde-ci/"$dst_dir"/$dstimg

log "step 17: call manager to exec deb make"
set +e
log "step 18: call start_deb_task $1 $ver $aospver $arch $num"
call_next_start_deb_make $1 $ver $aospver $arch $num 
if [ $? != 0 ];then
	log "step 19: retry call start_deb_task "
	call_next_start_deb_make $1 $ver $aospver $arch $num 
	if [ $? != 0 ];then
		log "step 20: retry call start_deb_task still failed "
		exit 1
	fi
fi

umount /root/aosp
exit 0

