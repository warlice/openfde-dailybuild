#!/bin/bash


function trans_log_to_manager() 
{
	logbase=`cat /root/make_deb.log |base64`
	aliyun ecs RunCommand  --RegionId cn-beijing --Name "transfer_aosp_build_log" --Type "RunShellScript" --InstanceId.1 i-2zedqszo15pm336f5kpk \
	  --CommandContent "echo '$logbase' |base64 -d > $1" 
	if [ $? != 0 ];then
		exit 1
	fi
}

function delete_my_self() 
{
	aliyun ecs RunCommand  --RegionId cn-beijing --Name "delete_my_self_aosp" --Type "RunShellScript" --InstanceId.1 i-2zedqszo15pm336f5kpk \
	  --CommandContent "bash /root/delete_instance.sh deb $1" 
	return $?
}

  /bin/bash -c "$(curl -fsSL https://aliyuncli.alicdn.com/install.sh)"  1>/dev/null 2>&1
  if [ $? != 0 ];then
	  echo "download aliyuncli failed"
	  exit 1
  fi
  echo "configure default"
  aliyun configure set \
    --profile default \
    --region cn-hangzhou \
    --access-key-id  ACCESS_KEY_ID \
    --access-key-secret ACCESS_KEY_SECRET
  if [ $? != 0 ];then
	  echo " configure failed"
	  exit 1
  fi
  echo "configure us"
  aliyun configure set \
    --profile us \
    --region us-east-1 \
    --access-key-id  ACCESS_KEY_ID \
    --access-key-secret ACCESS_KEY_SECRET

echo "call make_debs.sh"
if [ "$1" = "daily" ];then
	bash make_debs.sh $1 1>/dev/null 2>&1 & 
else
	bash make_debs.sh $1 $2 $3 $4 $5 1>/dev/null 2>&1 &
fi
make_pid=$!
wait $make_pid
now=`date "+%y%m%d_%H%M%S"`
instance_id=`curl -s http://100.100.100.200/latest/meta-data/instance-id`
echo "delete instance_id $instance_id" >>/root/make_deb.log
if [ "$1" = "daily" ];then
	logpath=/root/logs/debs/${now}_daily_make.log
else
	logpath=/root/logs/debs/${now}_version_make.log
fi

aliyun configure switch --profile default 
trans_log_to_manager $logpath
if [ $? != 0 ];then
	for i in {1..10}; do
		sleep 3
		now=`date "+%y%m%d_%H%M%S"`
		echo "$now trans_log $instance_id again" >> /root/make_deb.log 
		trans_log_to_manager $logpath
		if [ $? = 0 ];then
			break
		fi
	done
fi

sleep 3
delete_my_self $instance_id
if [ $? != 0 ];then
	for i in {1..10}; do
		sleep 3
		delete_my_self $instance_id
		if [ $? = 0 ];then
			break
		fi
	done
fi
