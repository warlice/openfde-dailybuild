#!/bin/bash

function log(){
  s=`date "+%y%m%d_%H%M%S:"`
  echo  "$s $1" |tee -a /root/logs/delete_instances.log
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
	aliyun configure switch --profile hangzhou >> logs/delete_instances.log
	id=`aliyun ecs DescribeInstances --InstanceIds "[\"$2\"]" --InstanceName openfde_deb_make |jq -r .Instances.Instance[0].InstanceId`
	if [ "$id" != "$2" ];then
		log "Error: id not match $2 and $id wont delete "
		exit 1
	fi

else
	aliyun configure switch --profile default >> logs/delete_instances.log
	id=`aliyun ecs DescribeInstances --InstanceIds "[\"$2\"]" --InstanceName openfde_aosp_make |jq -r .Instances.Instance[0].InstanceId`
	if [ "$id" != "$2" ];then
		log "Error: id not match $2 and $id wont delete "
		exit 1
	fi

fi	
log "delete instance $2"
aliyun ecs DeleteInstance --InstanceId $2 --Force true >> logs/delete_instances.log
if [ $? != 0 ];then
	for i in {1..10}; do
		log "delete instance again $2"
		aliyun ecs DeleteInstance --InstanceId $2 --Force true >> logs/delete_instances.log
		if [ $? = 0 ];then
			break
		fi
	done
fi

