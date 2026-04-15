#!/bin/bash

if [ "$1" = "aosp" ];then
	aliyun ecs DescribeInstances --InstanceName openfde_aosp_make --RegionId us-east-1
elif  [ "$1" = "deb" ];then
	aliyun ecs DescribeInstances --InstanceName openfde_deb_make --RegionId cn-hangzhou
elif  [ "$1" = "download" ];then
	aliyun ecs DescribeInstances --InstanceName openfde_aosp_download --RegionId us-east-1
elif  [ "$1" = "disk" ];then
	if [ "$2" = "using" ];then
		aliyun ecs DescribeDisks --RegionId us-east-1  --Status In_use
	else
		aliyun ecs DescribeDisks --RegionId us-east-1  --Status Available
	fi
fi

