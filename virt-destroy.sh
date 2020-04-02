#!/bin/bash

DATADIR="$PWD/disks"

if [[ ! -f config ]]; then
  echo "config file not found. using defaults..."
else
  source config
fi

virsh destroy $1 && virsh undefine $1 && \
  rm $DATADIR/$1.qcow2
