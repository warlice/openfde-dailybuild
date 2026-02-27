#!/bin/bash


#1=mode daily version
#2=ver 2.0.4
#3=aospver 14
#4=arch arm64|arm64only|x86
#5=num 1, 2...

mode=daily
LOGPATH=/root/logs/start_deb_make_daily.log
if [ "$1" = "version" ];then
	LOGPATH=/root/logs/start_deb_make_version.log
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
	echo  "$s: $@" |tee -a $LOGPATH
}

w_log $@
aliyun configure switch --profile hangzhou 1>/dev/null 2>&1
#instance_id="i-bp1coul0juc60q4dbfbb"
instance_id=`aliyun ecs RunInstances --InstanceType ecs.c8y.2xlarge --ImageId ubuntu_22_04_arm64_20G_alibase_20251226.vhd  --SecurityGroupId sg-bp1ggu0oqgiskum7x0tw  --SystemDisk.Category cloud_essd  --SystemDisk.Size 100 --InternetChargeType PayByTraffic --InternetMaxBandwidthOut 100  --Amount 1 --RegionId cn-hangzhou --InstanceName openfde_deb_make --VSwitchId vsw-bp1pxfruajkwnoap48rtp |jq -r .InstanceIdSets.InstanceIdSet[0] `
if [[ -z "$instance_id" || "$instance_id" == "null" ]]; then
	w_log "failed: ecs create failed"
	exit 1
fi

sleep 40  # 等待实例启动
w_log "step 2: wait until ecs is running"
for i in {1..10}; do
	instanceStatus=`aliyun  ecs DescribeInstances --RegionId cn-hangzhou --InstanceName openfde_deb_make  --InstanceIds "[\"$instance_id\" ]" |jq  .Instances.Instance[0].Status`
	if [ "$instanceStatus" = '"Running"' ];then
		w_log "step 2: ecs is running"
		break	
	fi
	sleep 15  # 等待实例启动
done
instanceStatus=`aliyun  ecs DescribeInstances --RegionId cn-hangzhou --InstanceName openfde_deb_make  --InstanceIds "[\"$instance_id\" ]" |jq  .Instances.Instance[0].Status`
if [ "$instanceStatus" != '"Running"' ];then
	w_log "step 2: after 180s ecs is  still not running"
	exit 1
fi

rm -rf package_deb_shs.tgz
w_log "step 3: tar package_debs_shs.tgz"
kid=`grep key-id key.txt |awk -F " " '{print $2}' `
ksecret=`grep key-secret  key.txt |awk -F " " '{print $2}' `
cp -a wrapper_2_orig.sh wrapper_2.sh
sed -i "s/ACCESS_KEY_SECRET/$ksecret/g" wrapper_2.sh
sed -i "s/ACCESS_KEY_ID/$kid/g" wrapper_2.sh
tar -zcvpf package_debs_shs.tgz make_deb_data  wrapper_2.sh make_debs.sh .ssh/authorized_keys .ssh/id_rsa  .ssh/id_rsa.pub 1>/dev/null 2>&1

shs=`cat /root/package_debs_shs.tgz |base64`

aliyun ecs RunCommand  --Name "transfer_deb_shs" --Type "RunShellScript" --InstanceId.1 $instance_id  --RegionId cn-hangzhou  \
--CommandContent "echo '$shs' | base64 -d > /root/package_deb_shs.tgz && tar -xf /root/package_deb_shs.tgz -C /root/  && chmod +x /root/wrapper_2.sh " |jq -r '.InvokeId'
if [ $? != 0 ];then
	w_log "failed: transfer failed"
	aliyun ecs DeleteInstance --InstanceId $instance_id --Force true --RegionId cn-hangzhou
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
		aliyun ecs DeleteInstance --InstanceId $instance_id --Force true --RegionId cn-hangzhou
		exit 1
	fi
	sleep 10
done
ip=`aliyun ecs DescribeInstances --InstanceName openfde_deb_make --RegionId cn-hangzhou  --InstanceIds "[\"$instance_id\"]" |jq -r .Instances.Instance[0].PublicIpAddress.IpAddress[0]`
if [ -z "$ip" ];then
	w_log "ip not founded"
	w_log "to delete instance $instance_id"
	aliyun ecs DeleteInstance --InstanceId $instance_id --Force true --RegionId cn-hangzhou
	exit 1
fi
ssh-keygen -R $ip
#transfer and exec wrapper_img.sh in the remote ecs
if [ "$mode" = "daily" ];then
	w_log "step 5: exec wrapper_deb_mk.sh daily"
	ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null root@$ip  "setsid bash /root/wrapper_2.sh daily 1>/dev/null 2>&1 &"
	if [ $? != 0 ];then
		sleep 15
		w_log "tray ssh exec again daily"
		ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null root@$ip  "setsid bash /root/wrapper_2.sh daily 1>/dev/null 2>&1 &"
	fi
else 
	w_log "step 5 wrapper_deb_mk.sh version $2 $3 $4 $5"
	ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null root@$ip  "setsid bash /root/wrapper_2.sh  version $2 $3 $4 $5  1>/dev/null 2>&1 & "
	if [ $? != 0 ];then
		sleep 15
		w_log "tray ssh exec again version"
		ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null root@$ip  "setsid bash /root/wrapper_2.sh  version $2 $3 $4 $5  1>/dev/null 2>&1 & "
	fi
fi

if [ $? != 0 ];then
	w_log "exec remote cmd through ssh failed"
	w_log "to delete instance $instance_id"
	aliyun ecs DeleteInstance --InstanceId $instance_id --Force true --RegionId cn-hangzhou
	exit 1
fi
w_log "step end: run command success"
exit 0
