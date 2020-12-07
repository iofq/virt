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

VM_HOSTNAME=""
VM_RAM=2048
VM_CPU=1
VM_DISK_SIZE="16G"
IMAGEDIR="$PWD/images"
DATADIR="$PWD/disks"
VM_IMAGE="$IMAGEDIR/base.qcow2"
VM_NETWORK="bridge=virbr0,model=virtio"
DEBUG=0
VM_DELETE=0 #1 for delete, 2 for delete with data

usage() {
  echo "usage: ./virt-install.sh -h hostname -i image.qcow2 -m mB(RAM) -c #CPUs -s disk size (16G format)" 1>&2
  echo "-h hostname -d -- delete a virtual machine, keeping the virtual disk" 1>&2
  echo "-h hostname -D -- delete a virtual machine, also deleting the virtual disk" 1>&2
  exit 1
}

destroy() {
[[ $VM_HOSTNAME != "" ]] && \
  virsh destroy $VM_HOSTNAME && \
  virsh undefine $VM_HOSTNAME
}

delete() {
  rm $DATADIR/$VM_HOSTNAME.qcow2
  rm $IMAGEDIR/.$VM_HOSTNAME-cloud-init.iso
}

if [[ ! -f config ]]; then
  echo "config file not found. using defaults..."
else
  source config
fi

if (( $DEBUG == 1 )); then
  DEBUG="--debug"
else
  DEBUG=""
fi

while getopts h:i:m:c:s:dD option
do
  case "${option}"
    in
    h) VM_HOSTNAME=${OPTARG};;
    i) VM_IMAGE=${OPTARG};;
    m) VM_RAM=${OPTARG};;
    c) VM_CPU=${OPTARG};;
    s) VM_DISK_SIZE=${OPTARG};;
    d) VM_DELETE=1;;
    D) VM_DELETE=2;;

    *) usage;;
  esac
done

#expand VM_IMAGE path
VM_IMAGE=$(realpath $VM_IMAGE)

case $VM_DELETE in
    0);;
    1) destroy && exit 0;;
    2) destroy && delete; exit 0;;
    *) exit 1;;
esac

[ ! -d "$IMAGEDIR" ] && \
  mkdir -p $IMAGEDIR && echo -e "${RED}No images found! exiting...$RESET" && exit 1
[ ! -d "$DATADIR" ] && \
  mkdir -p $DATADIR

echo "local-hostname: $VM_HOSTNAME" > meta-data
echo "instance-id: iid-$RANDOM-$VM_HOSTNAME" >> meta-data

while read line; do
  echo "- $line"
done < meta-data

[[ ! -f user-data ]] && \
  echo -e "$RED ERROR: can't find user-data file.$RESET" && exit 1
[[ ! -f meta-data ]] && \
  echo -e "$RED ERROR: Can't find meta-data file.$RESET" && exit 1
genisoimage -output $IMAGEDIR/.$VM_HOSTNAME-cloud-init.iso -volid cidata -J -R user-data meta-data &> .install.log && rm meta-data

echo -e "${YELLOW}Generated cloud-init.iso"

echo -e "${YELLOW}Creating qcow2 image... $DATADIR/$VM_HOSTNAME.qcow2 \n"

if [ -f $DATADIR/$VM_HOSTNAME.qcow2 ]; then
	while true; do
    echo -e "${RED}Image $DATADIR/$VM_HOSTNAME.qcow2 already exists."
    echo "It may be in use by another host."
    read -p "Delete it and attempt to destroy host? (y/n)" yn
			case $yn in
					yes|y) 
            echo -e "$GREEN"
            destroy && delete;
            break;;
          *) break;;
			esac
	done
fi
echo -e "$RESET"

sudo qemu-img create -f qcow2 -F qcow2 -b $VM_IMAGE $DATADIR/$VM_HOSTNAME.qcow2 $VM_DISK_SIZE && \
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
  --disk=path=$IMAGEDIR/.$VM_HOSTNAME-cloud-init.iso,device=cdrom $DEBUG &> .install.log || exit 1

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
