#!/bin/bash
#requires libvirt, libguestfs-tools, rsync, cdrkit(genisoimage)

RESET='\033[0m' 
BLACK='\033[0;30m'
RED='\033[0;31m' 
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m' 
PURPLE='\033[0;35m' 
CYAN='\033[0;36m'  
WHITE='\033[0;37m'

VM_RAM=2048
VM_CPU=1
IMAGEDIR="$PWD/images"
DATADIR="$PWD/disks"
VM_IMAGE="$IMAGEDIR/base.qcow2"
VM_NETWORK="bridge=virbr0,model=virtio"
DEBUG=0

if [[ ! -f config ]]; then
  echo "config file not found. using defaults..."
else
  source config
fi

if [[ $DEBUG == 1 ]]; then
  DEBUG="--debug"
else
  DEBUG=""
fi

while getopts h:i:r:c: option
do
  case "${option}"
    in
    h) VM_HOSTNAME=${OPTARG};;
    i) VM_IMAGE=${OPTARG};;
    r) VM_RAM=${OPTARG};;
    c) VM_CPU=${OPTARG};;
  esac
done

[ ! -d "$IMAGEDIR" ] && \
  mkdir -p $IMAGEDIR && echo -e "${RED}No images found! exiting...$RESET" && exit 1
[ ! -d "$DATADIR" ] && \
  mkdir -p $DATADIR

echo "local-hostname: $VM_HOSTNAME" > meta-data
echo "instance-id: iid-$RANDOM-$VM_HOSTNAME" >> meta-data

echo -e "${YELLOW}Generated cloud-init.iso"
while read line; do
  echo "- $line"
done < meta-data

[[ -f $IMAGEDIR/cloud-init.iso ]] && \
    mv $IMAGEDIR/cloud-init.iso $IMAGEDIR/.cloud-init.iso.bak
[[ ! -f user-data ]] && \
  echo -e "$RED ERROR: can't find user-data file.$RESET" && exit 1
[[ ! -f meta-data ]] && \
  echo -e "$RED ERROR: Can't find meta-data file.$RESET" && exit 1
genisoimage -output $IMAGEDIR/cloud-init.iso -volid cidata -J -R user-data meta-data &> .install.log && rm meta-data


echo -e "${YELLOW}Creating qcow2 image... $DATADIR/$VM_HOSTNAME.qcow2 \n"
if [ -f $DATADIR/$VM_HOSTNAME.qcow2 ]; then
	while true; do
    echo -e "${RED}Image $DATADIR/$VM_HOSTNAME.qcow2 already exists."
    echo "It may be in use by another host."
    read -p "Delete it and attempt to destroy host? (y/n)" yn
			case $yn in
					yes|y) 
            echo -e "$GREEN"
            sudo ./virt-destroy.sh $VM_HOSTNAME;
            rm $DATADIR/$VM_HOSTNAME.qcow2;
            break;;
          *) break;;
			esac
	done
fi
echo -e "$RESET"

sudo rsync -azh --progress $VM_IMAGE $DATADIR/$VM_HOSTNAME.qcow2 && \
  sudo chown qemu:qemu $DATADIR/$VM_HOSTNAME.qcow2 || exit 1
echo -e "${YELLOW}Provisioning host...$RESET"
sudo virt-install \
  --name $VM_HOSTNAME \
  --memory=$VM_RAM \
  --cpu host \
  --vcpus=cores=$VM_CPU \
  --network=$VM_NETWORK \
  --autostart \
  --os-type=linux \
  --os-variant=generic \
  --import \
  --graphics vnc \
  --noautoconsole \
  --disk=path=$DATADIR/$VM_HOSTNAME.qcow2,format=qcow2,bus=virtio \
  --disk=path=$IMAGEDIR/cloud-init.iso,device=cdrom $DEBUG &> .install.log || exit 1

	while true; do
    echo -e "$YELLOW"
    read -p "Enter console? (y/n)" yn
    echo -e "$RESET"
			case $yn in
					yes|y)
            sudo virsh console $VM_HOSTNAME;
            break;;
          *) break;;
			esac
  done
exit 0
