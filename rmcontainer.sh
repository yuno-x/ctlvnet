#!/bin/bash

if [ "$1" == "" ]
then
  echo "usage: $0 [CONTAINER NAME]"
  exit -1
fi

CNAME=$1

sudo docker exec ${CNAME} systemctl halt
sudo docker rm -f ${CNAME}
if [ -h /var/run/netns/${CNAME} ]
then
  sudo rm /var/run/netns/${CNAME}
fi
