#!/bin/bash

if [ "$1" = "aosp" ];then
	aliyun ecs DescribeInstances --InstanceName openfde_aosp_make --RegionId us-east-1
else
	aliyun ecs DescribeInstances --InstanceName openfde_deb_make --RegionId cn-hangzhou
fi

