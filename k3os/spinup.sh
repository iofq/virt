#!/bin/bash

K3OS=k3os$RANDOM
VERSION="v0.10.0"
VM_DISK_PATH=/mnt/nfs/virt/disks/

kernel_args="\
  k3os.mode=install \
  k3os.fallback_mode=install \
  k3os.install.silent=true \
  init_cmd=\"cp /.base/k3os_conf.yaml /config.yaml\" \
  k3os.install.config_url=/config.yaml \
  k3os.install.iso_url=\"https://github.com/rancher/k3os/releases/download/$VERSION/k3os-amd64.iso\" \
  k3os.install.device=/dev/vda \
  k3os.hostname=$K3OS \
  k3os.install.debug=true \
  k3os.debug=true \
  "

(( $EUID != 0 )) && echo "Please run as root..." && exit 1

[[ -f base/k3os-amd64.iso ]] || \
  curl -L -o base/k3os-amd64.iso https://github.com/rancher/k3os/releases/download/$VERSION/k3os-amd64.iso
[[ -f base/k3os-vmlinuz-amd64 ]] || \
  curl -L -o base/k3os-vmlinuz-amd64 https://github.com/rancher/k3os/releases/download/$VERSION/k3os-vmlinuz-amd64
# [[ -f base/k3os-initrd-amd64 ]] || \
  curl -L -o base/k3os-initrd-amd64 https://github.com/rancher/k3os/releases/download/$VERSION/k3os-initrd-amd64

unset VERSION
virt-install \
  --name $K3OS \
  --ram 2048 \
  --vcpus 1 \
  --os-type linux \
  --os-variant ubuntu20.04 \
  --graphics vnc \
  --network bridge=br0,model=virtio \
  --disk path=$VM_DISK_PATH/$K3OS.qcow2,size=4,device=disk \
  --disk path=base/k3os-amd64.iso,device=cdrom \
  --install kernel=base/k3os-vmlinuz-amd64,initrd=base/k3os-initrd-amd64 \
  --initrd-inject src/k3os_conf.yaml \
  --extra-args "${kernel_args}" \
  --autostart

