#!/bin/bash

if [ "$1" = "aosp" ];then
	aliyun ecs DescribeInstances --InstanceName openfde_aosp_make --RegionId us-east-1
elif  [ "$1" = "deb" ];then
	aliyun ecs DescribeInstances --InstanceName openfde_deb_make --RegionId cn-hangzhou
elif  [ "$1" = "download" ];then
	aliyun ecs DescribeInstances --InstanceName openfde_aosp_download --RegionId us-east-1
elif  [ "$1" = "disk" ];then
	aliyun ecs DescribeDisks --RegionId us-east-1 --Tag.1.Key dtype  --Tag.1.Value aospdata
fi

