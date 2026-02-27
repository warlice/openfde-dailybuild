
#!/bin/bash


function trans_log_to_manager() 
{
	logbase=`cat /root/make_imgs.log |base64`
	aliyun ecs RunCommand  --RegionId cn-beijing --Name "transfer_aosp_build_log" --Type "RunShellScript" --InstanceId.1 i-2zedqszo15pm336f5kpk \
	  --CommandContent "echo '$logbase' |base64 -d  > $1" 
	return $?
}

function delete_my_self() 
{
	aliyun ecs RunCommand  --RegionId cn-beijing --Name "delete_my_self_aosp" --Type "RunShellScript" --InstanceId.1 i-2zedqszo15pm336f5kpk \
	  --CommandContent "bash /root/delete_instance.sh aosp $1" 
	return $?
}

  /bin/bash -c "$(curl -fsSL https://aliyuncli.alicdn.com/install.sh)"
  if [ $? != 0 ];then
	  echo "download aliyuncli failed"
	  exit 1
  fi
  aliyun configure set \
    --profile hangzhou \
    --region cn-hangzhou \
    --access-key-id  ACCESS_KEY_ID \
    --access-key-secret ACCESS_KEY_SECRET

  aliyun configure set \
    --profile default \
    --region us-east-1 \
    --access-key-id  ACCESS_KEY_ID \
    --access-key-secret ACCESS_KEY_SECRET

  if [ $? != 0 ];then
	  echo " configure failed"
	  exit 1
  fi
if [ "$1" = "daily" ];then
	bash make_imgs.sh $1 1>/dev/null  &
else
	bash make_imgs.sh $1 $2 $3 $4 $5 1>/dev/null &
fi
make_pid=$!
wait $make_pid
now=`date "+%y%m%d_%H%M%S"`
if [ "$1" = "daily" ];then
	logpath=/root/logs/aospmk/${now}_daily_make_imgs.log
else
	logpath=/root/logs/aospmk/${now}_version_make_imgs.log
fi

instance_id=`curl -s http://100.100.100.200/latest/meta-data/instance-id`
echo "delete instance id $instance_id" >> /root/make_imgs.log 
if [ -e /root/make1.log ];then
	tail -n 5 /root/make1.log >> /root/make_imgs.log
fi
trans_log_to_manager $logpath
if [ $? != 0 ];then
	for i in {1..10}; do
		sleep 13
		now=`date "+%y%m%d_%H%M%S"`
		echo " $now trans_log $instance_id again" >> /root/make_imgs.log 
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
		sleep 13
		delete_my_self $instance_id
		if [ $? = 0 ];then
			break
		fi
	done
fi
