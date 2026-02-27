#!/bin/bash

#call next in daemon mode
s=`date "+%y%m%d_%H%M%S:"`
echo "$s $@" >> /root/logs/call_start_make_deb_task.log
./2start_package_deb.sh $@ &
exit 0
