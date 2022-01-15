#!/bin/bash

PWD="$(dirname $0)"
source $PWD/modules/check.sh

if [ "$1" == "" ]
then
  echo "usage: $0 [CONTAINER NAME]..."
  exit -1
fi

ctlv_set_SUDO

for CNAME in $@
do
  $SUDO docker exec ${CNAME} systemctl halt
  $SUDO docker rm -f ${CNAME}
  if [ -h /var/run/netns/${CNAME} ]
  then
    $SUDO rm /var/run/netns/${CNAME}
  fi
done
