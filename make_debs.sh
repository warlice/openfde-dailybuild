#!/bin/bash


function log(){
  s=`date "+%y%m%d_%H%M%S:"`
  echo  "$s $1" |tee -a /root/make_deb.log
}

touch /root/make_deb.log
log "step 1: stop unattended-upgrades" 
systemctl stop unattended-upgrades
set -e
apt update
log "step 2: install docker.io" 
NEEDRESTART_SUSPEND=1 apt install  -y  docker.io 1>/dev/null

dockerScript="run_in_docker_make_deb.sh"

mode="daily"
osspath="oss://fde-ci/daily-images/img.tgz"
if  [ "$1" = "daily" ];then
	ver=`date "+%y%m%d%H"`
	basever="14"
else
	mode="testing"
	osspath="oss://fde-ci/openfde-images/img.tgz"
	ver=$2
	basever=$3
fi

function clearWork() {
	container=$1
	image=$2
	log "stop $container" 
	docker stop $container
	log "rm $container  " 
	docker rm $container
	log "rmi $image" 
	docker rmi $image
}

function publishdeb() {
	ip="172.30.248.58"
	#$1: path
	debname=$2
	version=$3 #means noble jammy kylin uos(eagle) debian(bookworm)
	log "transfer $1 to $ip" 
	args="-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null"
	scp $args $1 root@${ip}:
	if [ $? != 0 ];then
		log "transfer $debname failed"
		exit 1
	fi
	log "publish $2" 
	ssh $args root@${ip} "./pubm.sh $debname $version $mode"
	if [ $? != 0 ];then
		log "publish $debname $version $mode failed"
		exit 1
	fi
	ssh $args root@${ip} "rm  $debname "
	ssh $args root@${ip} "./rm_pac_m.sh $version $mode"
}

function buildPublishClear() {
	mkdir works -p
	cp -a make_deb_data/* works/
	origImg=$1
	newimg=$2
	container=$3
	distribution=$4
	log "update Dockerfile" 
	sed -i "1i\FROM  $origImg" works/Dockerfile
	log "update run in docker make deb" 
	sed -i "/aospver/s/version/$ver/" works/$dockerScript
	sed -i "/aospver/s/aospver/$basever/" works/$dockerScript
	cp -a /root/img.tgz works/
	cd works
	log "build image $newimg" 
	docker build . -t $newimg
	if [ $? != 0 ];then
		echo "docker build $newimg failed"
		exit 1
	fi
	cd -
	rm -rf works

	log "run $container" 
	docker run -itd --name $container $newimg
	log "cp deb from ${container} to works" 
	mkdir debs -p
	docker cp ${container}:/root/debdir debs/
	debname=`ls debs/debdir`
	publishdeb debs/debdir/$debname $debname $distribution
	if [ $? != 0 ];then
		exit 1
	fi
	rm -rf debs
	clearWork $container $newimg
}


#pull img.tgz from oss first
log "step 3: copy img.tgz from oss/fde-ci" 
aliyun configure switch --profile us
set +e
touch /root/oss.log
USEndpoint="oss-us-east-1.aliyuncs.com"
aliyun ossutil stat -e $USEndpoint $osspath
if [ $? != 0 ];then
	log "step 3 daily-images/img.tgz is not exist"
	exit 1
fi
aliyun ossutil cp -e $USEndpoint $osspath . > /root/oss.log 2>&1
if [ $? != 0 ];then
	log "step 3 copy $osspath failed"
	exit 1
fi
aliyun configure switch --profile default
set -e
DEBIP="172.30.248.58"
OSSBUCKET=http://openfde.oss-cn-hangzhou-internal.aliyuncs.com/system_images

#****************make deb for ubuntu 24************************#
log "step 4: wget ubuntu 24.04 image" 
IMG="ubuntu_24.04_installed.img"
wget $OSSBUCKET/$IMG 1>/dev/null 2>&1
log "step 4: load ubuntu 24.04" 
docker load -i $IMG  1>/dev/null 2>&1
rm -rf $IMG

buildPublishClear "ubuntu:24.04_installed"  "ubuntu:24_work_img" ubuntu_24_work noble

#****************make deb for ubuntu 22************************#
log "step 5: wget ubuntu 22.04 image" 
IMG="ubuntu_22.04_installed.img"
wget $OSSBUCKET/$IMG 1>/dev/null 2>&1
log "step 5: load ubuntu 22.04" 
docker load -i $IMG
rm -rf $IMG

buildPublishClear "ubuntu:22.04_installed"  "ubuntu:22_work_img" ubuntu_22_work jammy

#****************make deb for kylin************************#
log "step 6: wget kylin v10 image" 
IMGTGZ="kylin_v10sp1.img.tgz"
wget $OSSBUCKET/$IMGTGZ 1>/dev/null 2>&1
tar -xf $IMGTGZ
rm -rf $IMGTGZ
IMG="kylin_v10sp1.img"
log "step 6: load kylin v10 image" 
docker load -i $IMG
rm -rf $IMG

buildPublishClear "kylin:v10sp1"  "kylin:v10sp1_work_img" kylin_v10sp1_work kylin

#****************make deb for uos************************#
log "step 7: wget uos v20 image" 
IMGTGZ="uos_v20.img.tgz"
wget $OSSBUCKET/$IMGTGZ 1>/dev/null 2>&1
tar -xf $IMGTGZ
rm -rf $IMGTGZ
IMG="uos.img"
log "step 7: load uos v20 image" 
docker load -i $IMG
rm -rf $IMG

buildPublishClear "uos:v20_installed"  "uos:v20_work_img" uos_v20_work uos
