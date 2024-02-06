#!/bin/bash
#
RESET='\033[0m' 
BLACK='\033[0;30m'
RED='\033[0;31m' 
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m' 
PURPLE='\033[0;35m' 
CYAN='\033[0;36m'  
WHITE='\033[0;37m'


usage() {
  echo "usage: ./virt-install.sh -h hostname -i image.qcow2 -m mB(RAM) -c #CPUs -s disk size (16G format)" 1>&2
  echo "./virt-install.sh -f ~/virt-install.conf -u user-data.txt -h hostname -i image.qcow2" 1>&2
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

mkConf() {
cat << EOF > $CONFIG
    #!/bin/bash
    #defaults
    VM_RAM=512 #in Mb
    VM_CPU=1
    VM_DISK_SIZE="8G"
    IMAGEDIR="/var/lib/libvirt/images"
    DATADIR="/var/lib/libvirt/disks"
    VM_IMAGE="$IMAGEDIR/base.qcow2" #default image to clone when none is specified
    VM_NETWORK="bridge=br0,model=virtio" #args for --network= command, defaults to virbr0
    DEBUG=0 #set to 1 for virt-install verbose output
EOF
}

# Defaults
CONFIG="/etc/virt-install.conf"
DEBUG=0
VM_DELETE=0

while getopts h:f:u:i:m:c:s:dDv option
do
  case "${option}"
    in
    h) VM_HOSTNAME=${OPTARG};;
    f) CONFIG=${OPTARG};;
    u) USERDATA=${OPTARG};;
    i) VM_IMAGE=${OPTARG};;
    m) VM_RAM=${OPTARG};;
    c) VM_CPU=${OPTARG};;
    s) VM_DISK_SIZE=${OPTARG};;
    d) VM_DELETE=1;;
    D) VM_DELETE=2;;
    v) DEBUG=1;;

    *) usage;;
  esac
done

if (( $DEBUG == 1 )); then
  DEBUG="--debug"
else
  DEBUG=""
fi

if [[ ! -f $CONFIG ]]; then
  echo "config file not found. creating defaults at ${CONFIG}..."
  mkConf
else
  source $CONFIG
fi

#expand VM_IMAGE path
VM_IMAGE=$(realpath $VM_IMAGE)

case $VM_DELETE in
    0);;
    1) destroy && exit 0;;
    2) destroy && delete; exit 0;;
    *) exit 1;;
esac

[ ! -d "$DATADIR" ] && \
  mkdir -p $DATADIR

METADATA_FILE="/tmp/virt-metadata-$(date)"

echo "local-hostname: $VM_HOSTNAME" > "$METADATA_FILE"
echo "instance-id: iid-$RANDOM-$VM_HOSTNAME" >> "$METADATA_FILE"

while read line; do
  echo "- $line"
done < "$METADATA_FILE"

[[ -n $USERDATA ]] && [[ ! -f $USERDATA ]] && \
  echo -e "$RED ERROR: can't find specified user-data file ${USERDATA}.$RESET" && exit 1
[[ ! -f $METADATA_FILE ]] && \
  echo -e "$RED ERROR: Can't find meta-data file.$RESET" && exit 1
genisoimage -output "$IMAGEDIR/.$VM_HOSTNAME-cloud-init.iso" -volid cidata -J -R "$USERDATA" "$METADATA_FILE" && rm "$METADATA_FILE"

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

qemu-img create -f qcow2 -F qcow2 -b $VM_IMAGE $DATADIR/$VM_HOSTNAME.qcow2 $VM_DISK_SIZE && \
  chown qemu:qemu $DATADIR/$VM_HOSTNAME.qcow2 || exit 1

echo -e "${YELLOW}Provisioning host...$RESET"
virt-install \
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
  --disk=path=$IMAGEDIR/.$VM_HOSTNAME-cloud-init.iso,device=cdrom $DEBUG || exit 1

	while true; do
    echo -e "$YELLOW"
    read -p "Enter console? (y/n)" yn
    echo -e "$RESET"
			case $yn in
					yes|y)
            virsh console $VM_HOSTNAME;
            break;;
          *) break;;
			esac
  done
exit 0
