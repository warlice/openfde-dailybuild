#!/bin/bash

json=$(./list_instances.sh disk)
echo "$json" | jq -c '.Disks.Disk[]' | while read disk; do
    disk_id=$(echo "$disk" | jq -r '.DiskId')
    creation_time=$(echo "$disk" | jq -r '.CreationTime')
    
    c=`date -d "$creation_time"`
    create_ts=$(date -d "$creation_time" +%s)
    now_ts=$(date +%s)

    # 计算时间差（秒）
    diff=$((now_ts - create_ts))
    if [ $diff -le 10800 ] && [ $diff -ge 0 ]; then
    	sendEmail -xu 185457686@qq.com -xp guqbtpjnufzycbcb  -t 185457686@qq.com -s smtp.qq.com:587 -u "disk id $disk_id test crontab" -m "more than 3 hours" -f 185457686@qq.com
    	#echo "$disk_id 创建时间在12小时内"
    else
    	sendEmail -xu 185457686@qq.com -xp guqbtpjnufzycbcb  -t 185457686@qq.com -s smtp.qq.com:587 -u "disk id $disk_id more than 3hours" -m "more than 3 hours" -f 185457686@qq.com
    	#echo "$disk_id 创建时间超过12小时"
    fi
done
json=$(./list_instances.sh aosp)
echo "$json" | jq -c '.Instances.Instance[]' | while read instance; do
    instance_id=$(echo "$instance" | jq -r '.InstanceId')
    creation_time=$(echo "$instance" | jq -r '.CreationTime')
    
    c=`date -d "$creation_time"`
    create_ts=$(date -d "$creation_time" +%s)
    now_ts=$(date +%s)

    # 计算时间差（秒）
    diff=$((now_ts - create_ts))
    if [ $diff -le 10800 ] && [ $diff -ge 0 ]; then
    	sendEmail -xu 185457686@qq.com -xp guqbtpjnufzycbcb  -t 185457686@qq.com -s smtp.qq.com:587 -u "instance id $instance_id test crontab" -m "more than 3 hours" -f 185457686@qq.com
    	#echo "$disk_id 创建时间在12小时内"
    else
    	sendEmail -xu 185457686@qq.com -xp guqbtpjnufzycbcb  -t 185457686@qq.com -s smtp.qq.com:587 -u "instance id $instance_id more than 3hours" -m "more than 3 hours" -f 185457686@qq.com
    	#echo "$disk_id 创建时间超过12小时"
    fi
done

