#!/bin/bash

#call next in daemon mode
s=`date "+%y%m%d_%H%M%S:"`
echo "$s $@" >> /root/logs/call_start_make_img_task.log
./2start_aosp_build.sh $@ &
exit 0
