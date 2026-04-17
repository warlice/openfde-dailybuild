#!/bin/bash

LOGPATH=/root/logs/delete_instances.log
function log(){
  s=`date "+%y%m%d_%H%M%S:"`
  echo  "$s $@" |tee -a $LOGPATH
}

log $@
if [ "$#" != 2 ];then
	echo "delete deb instanceid"
	log "args invalid exit 1"
	exit 1
fi
if [ -z "$2" ];then
	log "Error: id is empty"
	exit 1
fi
sleep 10
if [ "$1" = "deb" ];then
	aliyun configure switch --profile hangzhou >> $LOGPATH
	id=`aliyun ecs DescribeInstances --InstanceIds "[\"$2\"]" --InstanceName openfde_deb_make |jq -r .Instances.Instance[0].InstanceId`
	if [ "$id" != "$2" ];then
		log "Error: id not match $2 and $id wont delete "
		exit 1
	fi

elif [ "$1" = "aosp" ];then
	aliyun configure switch --profile default >> $LOGPATH
	id=`aliyun ecs DescribeInstances --InstanceIds "[\"$2\"]" --InstanceName openfde_aosp_make |jq -r .Instances.Instance[0].InstanceId`
	if [ "$id" != "$2" ];then
		log "Error: id not match $2 and $id wont delete "
		exit 1
	fi
elif [ "$1" = "download" ];then
	aliyun configure switch --profile default >> $LOGPATH
	id=`aliyun ecs DescribeInstances --InstanceIds "[\"$2\"]" --InstanceName openfde_aosp_download |jq -r .Instances.Instance[0].InstanceId`
	if [ "$id" != "$2" ];then
		log "Error: id not match $2 and $id wont delete "
		exit 1
	fi
else
	if [ "$1" != "disk" ];then
		log "Error: type $1 is not support"
		exit 1
	fi
	aliyun configure switch --profile default >> $LOGPATH
	id=`aliyun ecs DescribeDisks --RegionId us-east-1 --Tag.1.Key dtype  --Tag.1.Value aospdata  |jq -r .Disks.Disk[0].DiskId`
	if [ "$id" != "$2" ];then
		log "Error: id not match $2 and $id wont delete "
		exit 1
	fi
	aliyun ecs DeleteDisk --DiskId $2  --RegionId us-east-1 >> $LOGPATH
	exit 0
fi	
log "delete instance $2"
aliyun ecs DeleteInstance --InstanceId $2 --Force true >> $LOGPATH
if [ $? != 0 ];then
	for i in {1..10}; do
		log "delete instance again $2"
		aliyun ecs DeleteInstance --InstanceId $2 --Force true >> $LOGPATH
		if [ $? = 0 ];then
			break
		fi
	done
fi

