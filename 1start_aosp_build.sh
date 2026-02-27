#!/bin/bash


function usage() 
{
	echo "start.sh mode version aospver arch num"
	echo "example: start.sh version  2.0.6  14|11 arm64only|x86|arm64 1|2"
	echo "example: start.sh daily {date} {14} {arm64} {1}"
}

mode=daily
LOGPATH=/root/logs/start_img_make_daily.log
if [ "$1" = "version" ];then
	LOGPATH=/root/logs/start_img_make_version.log
	mode=version
	if [ -z "$2" ];then
		echo "please input the version like 2.0.6"
		usage
		exit 1
	fi
	if [ -z "$3" ];then
		echo "please input the asopver like 14"
		usage
		exit 1
	fi
	if [ -z "$4" ];then
		echo "please input the arch like arm64|arm64only|x86"
		usage
		exit 1
	fi
	if [ -z "$5" ];then
		echo "please input the num like 1  or 2 or 3 or ..."
		usage
		exit 1
	fi
fi
mkdir -p /root/logs
touch $LOGPATH 
function w_log()
{
	s=`date "+%y%m%d_%H%M%S"`
	echo  "$s: $1" |tee -a $LOGPATH
}

w_log $@
aliyun configure switch --profile default 1>/dev/null 2>&1
w_log "step 1: create ecs instance"
#instance_id="i-0xi16uf7r4syux4z894e"
if [ -z "$instance_id" ];then
	instance_id=`aliyun ecs RunInstances --RegionId us-east-1 --InstanceType ecs.c9i.8xlarge --ImageId ubuntu_22_04_x64_20G_alibase_20230907.vhd --SecurityGroupId sg-0xi22iuffog8ylfh0or5 \
	--VSwitchId vsw-0xi3vuydn6xui661xeiwu  --SystemDisk.Category cloud_essd  --SystemDisk.Size 350  --SystemDisk.PerformanceLevel PL1  \
	--InternetChargeType PayByTraffic --InternetMaxBandwidthOut 100 --Amount 1 --InstanceName openfde_aosp_make |jq -r .InstanceIdSets.InstanceIdSet[0] `
fi

if [[ -z "$instance_id" || "$instance_id" == "null" ]]; then
	w_log "failed: ecs create failed"
	exit 1
fi
sleep 30  # 等待实例启动
w_log "step 2: wait until ecs is running"
for i in {1..10}; do
	sleep 15  # 等待实例启动
	instanceStatus=`aliyun  ecs DescribeInstances --InstanceIds "[\"$instance_id\"]" --RegionId us-east-1 --InstanceName openfde_aosp_make |jq  .Instances.Instance[0].Status`
	if [ "$instanceStatus" = '"Running"' ];then
		w_log "step 2: ecs is running"
		break	
	fi
done
instanceStatus=`aliyun  ecs DescribeInstances --InstanceIds "[\"$instance_id\"]" --RegionId us-east-1 --InstanceName openfde_aosp_make |jq  .Instances.Instance[0].Status`
if [ "$instanceStatus" != '"Running"' ];then
	w_log "step 2: after 180s ecs is  still not running"
	exit 1
fi

rm -rf build_aosp_shs.tgz
w_log "step 3: tar build_aosp_shs.tgz"
kid=`grep key-id key.txt |awk -F " " '{print $2}' `
ksecret=`grep key-secret  key.txt |awk -F " " '{print $2}' `
cp -a wrapper_img_orig.sh wrapper_img.sh
sed -i "s/ACCESS_KEY_SECRET/$ksecret/g" wrapper_img.sh
sed -i "s/ACCESS_KEY_ID/$kid/g" wrapper_img.sh
tar -zcvpf build_aosp_shs.tgz wrapper_img.sh make_imgs.sh .ssh/authorized_keys 1>/dev/null 2>&1


shs=`cat /root/build_aosp_shs.tgz |base64`
w_log "step 4: transferr build_aosp_shs.tgz"
invoke_id=`aliyun ecs RunCommand  --Name "transfer_id" --Type "RunShellScript" --InstanceId.1 $instance_id  --RegionId us-east-1 \
--CommandContent "echo '$shs' | base64 -d > /root/build_aosp_shs.tgz && tar -xf /root/build_aosp_shs.tgz -C /root/ && chmod +x /root/wrapper_img.sh" |jq -r '.InvokeId'`
if [[ -z "$invoke_id" || "$invoke_id" == "null" ]]; then
	w_log "invoke id not found or exec command failed, exit"
	aliyun ecs DeleteInstance --InstanceId $instance_id --Force true --RegionId us-east-1
	exit 1
fi

for i in {1..10}; do
	result=`aliyun ecs DescribeInvocationResults  --InvokeId "$invoke_id"`
	status=$(echo "$result" | jq -r '.Invocation.InvocationResults.InvocationResult[0].InvokeRecordStatus')
	output=$(echo "$result" | jq -r '.Invocation.InvocationResults.InvocationResult[0].Output')
	invocationStatus=$(echo "$result" | jq -r '.Invocation.InvocationResults.InvocationResult[0].InvocationStatus')

	w_log "current status: $status"
	if [ "$status" = "Finished" ]; then
		if [ "$invocationStatus" = "Success" ]; then
			w_log "transfer file success"
			break
		fi
	elif [ "$status" = "Failed" ]; then
		w_log "transfer file failed "
		w_log "to delete instance $instance_id"
		aliyun ecs DeleteInstance --InstanceId $instance_id --Force true --RegionId us-east-1
		exit 1
	fi
	sleep 10
done

ip=`aliyun ecs DescribeInstances --InstanceName openfde_aosp_make --RegionId us-east-1  --InstanceIds "[\"$instance_id\"]" |jq -r .Instances.Instance[0].PublicIpAddress.IpAddress[0]`
if [ -z "$ip" ];then
	w_log "ip not founded"
	w_log "to delete instance $instance_id"
	aliyun ecs DeleteInstance --InstanceId $instance_id --Force true --RegionId us-east-1
	exit 1
fi
ssh-keygen -R $ip
if [ "$mode" = "daily" ];then
	ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null root@$ip  "setsid bash /root/wrapper_img.sh daily 1>/dev/null 2>&1 &"
	if [ $? != 0 ];then
		sleep 15
		ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null root@$ip  "setsid bash /root/wrapper_img.sh daily 1>/dev/null 2>&1 &"
	fi
else
	ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null root@$ip  "setsid bash /root/wrapper_img.sh version $2 $3 $4 $5 1>/dev/null 2>&1 &"
	if [ $? != 0 ];then
		sleep 15
		ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null root@$ip  "setsid bash /root/wrapper_img.sh version $2 $3 $4 $5 1>/dev/null 2>&1 &"
	fi
fi
if [ $? != 0 ];then
	w_log "exec remote cmd through ssh failed"
	w_log "to delete instance $instance_id"
	aliyun ecs DeleteInstance --InstanceId $instance_id --Force true --RegionId us-east-1
	exit 1
fi
w_log "step end: run command success"
exit 0



