#!/bin/bash

if [ "$1" == "" ]
then
  echo "usage: $0 [IMAGE NAME] [CONTAINER NAME]..."
  exit -1
fi

INAME=$1

for CNAME in ${@:2}
do
  if [ "`ip netns | grep -w ${CNAME}`" != "" ]
  then
    echo "Network netspace \"${CNAME}\" already exists." >&2
    exit -1
  fi

  sudo docker run -d --privileged --network none --hostname ${CNAME} --name ${CNAME} -v /tmp/.X11-unix/:/tmp/.X11-unix -v /sys/fs/cgroup:/sys/fs/cgroup:ro ${INAME} /usr/bin/systemd
  #sudo docker exec ${CNAME} bash -c "echo export DISPLAY=$DISPLAY >> ~/.bashrc"

  ID=`sudo docker ps -f "name=${CNAME}" --format '{{.ID}}'`

  SYSTEMD_PID=$(
  for PP in `pgrep -f ${ID}`
  do
    pgrep -P ${PP} -n systemd
  done
  )

  if [ -f /var/run/netns ]
  then
    echo "NetNS Creation Error"
    exit -1
  fi

  if [ ! -d /var/run/netns ]
  then
    sudo mkdir /var/run/netns
  fi

  sudo ln -s /proc/${SYSTEMD_PID}/ns/net /var/run/netns/${CNAME}
done
