#!/bin/bash


LOGPATH=/root/logs/exec_start_aosp_build.log
/root/v2/2start_aosp_build.sh $@ &
disk_id=$6
callpid=$!
wait $callpid
ret=$?
if [ $ret != 0 ];then
	echo "2start_aosp_build.sh failed need to delete disk" >> $LOGPATH
	/root/v2/delete_instance.sh disk $disk_id >> $LOGPATH
fi
