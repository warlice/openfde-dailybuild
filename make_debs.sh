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
if  [ "$1" = "daily" ];then
	ver=`date "+%y%m%d%H"`
	basever="14"
	ARCH="arm64"
	VERNum="1"
	ImgPre=daily-images
else
	mode="testing"
	ImgPre=openfde-images
	ver=$2
	basever=$3
	ARCH=$4
	VERNum=$5
fi
if [ "$ARCH" = "arm64" ];then
	AN_IMG=img.tgz
else
	AN_IMG=img64only.tgz
fi
osspath="oss://fde-ci/$ImgPre/$AN_IMG"

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
	sed -i "s/verNum/$VERNum/" works/$dockerScript
	sed -i "s/arch/$ARCH/" works/$dockerScript
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
	log "step 3 $osspath is not exist"
	exit 1
fi
aliyun ossutil cp -e $USEndpoint $osspath . > /root/oss.log 2>&1
if [ $? != 0 ];then
	log "step 3 copy $osspath failed"
	exit 1
fi
if [ "$AN_IMG" = "img64only.tgz" ];then
	mv $AN_IMG img.tgz
fi	
aliyun configure switch --profile default
set -e
OSSBUCKET=http://openfde.oss-cn-hangzhou-internal.aliyuncs.com/system_images

imgFileList="ubuntu_24.04_installed.img ubuntu_22.04_installed.img deepin_beige.img"
imgNameList="ubuntu:24.04_installed ubuntu:22.04_installed deepin:beige_work"
newimgList="ubuntu:24_work_img ubuntu:22_work_img deepin:beige_work_img"
containerList="ubuntu_24_work ubuntu_22_work deepin_beige_work"
versionList="noble jammy beige"

# transfer to arrays
IMGFILES=($imgFileList)
IMGS=($imgNameList)
NEW_IMGS=($newimgList)
CONTAINERS=($containerList)
VERSIONS=($versionList)

for i in "${!IMGS[@]}"; do
	IMGFILE="${IMGFILES[$i]}"
	IMG="${IMGS[$i]}"
	NEW_IMG="${NEW_IMGS[$i]}"
	CONTAINER="${CONTAINERS[$i]}"
	VERSION="${VERSIONS[$i]}"
	if [ "$ARCH" != "arm64" ];then
		if [ "$VERSIONS" = "beige" ];then
			log "only makes deb on ubuntus for non-arm64 archs"
			exit 0
		fi
	fi
	log "wget $IMGFILE" 
	wget $OSSBUCKET/$IMGFILE 1>/dev/null 2>&1

	log "load $IMGFILE"
	docker load -i $IMGFILE 1>/dev/null 2>&1
	rm -rf $IMGFILE

	buildPublishClear $IMG "$NEW_IMG" "$CONTAINER" "$VERSION"
done
#****************make deb for kylin************************#
log "wget kylin v10 image" 
IMGTGZ="kylin_v10sp1.img.tgz"
wget $OSSBUCKET/$IMGTGZ 1>/dev/null 2>&1
tar -xf $IMGTGZ
rm -rf $IMGTGZ
IMG="kylin_v10sp1.img"
log "load kylin v10 image" 
docker load -i $IMG
rm -rf $IMG

buildPublishClear "kylin:v10sp1"  "kylin:v10sp1_work_img" kylin_v10sp1_work kylin

#****************make deb for uos************************#
log "wget uos v20 image" 
IMGTGZ="uos_v20.img.tgz"
wget $OSSBUCKET/$IMGTGZ 1>/dev/null 2>&1
tar -xf $IMGTGZ
rm -rf $IMGTGZ
IMG="uos.img"
log "load uos v20 image" 
docker load -i $IMG
rm -rf $IMG

buildPublishClear "uos:v20_installed"  "uos:v20_work_img" uos_v20_work uos

