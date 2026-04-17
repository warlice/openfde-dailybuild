#!/bin/bash

#call next in daemon mode
s=`date "+%y%m%d_%H%M%S:"`
disk_id=$6
LOGPATH=/root/logs/call_start_make_img_task.log
echo "$s $@" >> $LOGPATH
/root/v2/2start_aosp_build.sh $@ &
callpid=$!
wait $callpid
ret=$?
if [ $ret != 0 ];then
	echo "2start_aosp_build.sh failed need to delete disk" >> $LOGPATH
	/root/v2/delete_instance.sh disk $disk_id >> $LOGPATH
fi
exit 0
