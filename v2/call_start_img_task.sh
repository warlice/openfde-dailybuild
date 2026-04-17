#!/bin/bash

#call next in daemon mode
s=`date "+%y%m%d_%H%M%S:"`
LOGPATH=/root/logs/call_start_make_img_task.log
echo "$s $@" >> $LOGPATH
/root/v2/exec_start_aosp_build.sh $@ &
exit 0
