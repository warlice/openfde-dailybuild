#!/bin/bash

function log(){
  s=`date "+%y%m%d_%H%M%S:"`
  echo  "$s $1" >> /root/download.log
}

function call_next_start_img_make() {
	invoke_id=`aliyun ecs RunCommand --RegionId cn-beijing  --Name "call_next_img_make_task" --Type "RunShellScript" --InstanceId.1 i-2zedqszo15pm336f5kpk \
	  --CommandContent "nohup bash /root/v2/call_start_img_task.sh $1 $2 $3 $4 $5 1>/dev/null 2>&1"  | jq -r '.InvokeId'` 
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
	NEEDRESTART_SUSPEND=1 apt install  -y vim git repo jq curl wget git-lfs jq
	ln -sf /usr/bin/python3 /usr/bin/python
	log "step 3: git set user name " 
	git config --global user.name openfde && git config --global user.email openfde@openfde.com
fi
mkdir aosp -p
log "step 3 mkfs vdb and mount"
mkfs.ext4 /dev/vdb
mount /dev/vdb /root/aosp
cd aosp
log "step 4: repo init " 
repo init -u https://github.com/openfde/fde-manifests -b fde_14 --depth=1
cp /root/aosp/.repo/repo/repo /usr/bin/repo
log "step 5: repo init --git-lfs "
repo init -u https://github.com/openfde/fde-manifests -b fde_14 --depth=1  --git-lfs
set +e
log  "step 6: repo sync 10 first " 
repo sync -j 10
if [ $? != 0 ];then
	for i in {1..10}; do
		log  "step 6: repo sync 8 again " 
		repo sync -j8
		if [ $? = 0 ];then
			break
		fi
		sleep 10
	done
fi
log " umount vdb"
umount /root/aosp
log "call manager to exec task aosp img making"
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
set +e
log "call start_img_make_task $1 $ver $aospver $arch $num"
call_next_start_img_make $1 $ver $aospver $arch $num
if [ $? != 0 ];then
	log "retry call start_img_task "
	call_next_start_img_make $1 $ver $aospver $arch $num
	if [ $? != 0 ];then
		log "retry call start_img_task still failed "
		exit 1
	fi
fi
exit 0

