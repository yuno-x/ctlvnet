#!/bin/bash

if [ "$1" == "" ]
then
  echo "usage: $0 [CONTAINER NAME]..."
  exit -1
fi

if [ "$( whoami )" == "root" ]
then
  SUDO=""
else
  if ! sudo echo -n
  then
    echo "You must have permission to use sudo command." >&2
    exit -1
  fi

  SUDO=sudo
fi

for CNAME in $@
do
  $SUDO docker exec ${CNAME} systemctl halt
  $SUDO docker rm -f ${CNAME}
  if [ -h /var/run/netns/${CNAME} ]
  then
    $SUDO rm /var/run/netns/${CNAME}
  fi
done
