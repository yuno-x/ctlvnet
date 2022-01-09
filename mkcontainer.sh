#!/bin/bash

if [ "$1" == "" ]
then
  echo "usage: $0 [IMAGE NAME] [CONTAINER NAME]..."
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

NETSET="
$SUDO sysctl -w net.ipv4.ip_forward=1 > /dev/null
$SUDO sysctl -w net.ipv6.conf.all.forwarding=1 > /dev/null
$SUDO sysctl -w net.ipv4.tcp_l3mdev_accept=1 > /dev/null
$SUDO sysctl -w net.ipv4.udp_l3mdev_accept=1 > /dev/null
$SUDO sysctl -w net.ipv4.conf.default.rp_filter=0 > /dev/null
$SUDO sysctl -w net.ipv4.conf.all.rp_filter=0 > /dev/null
$SUDO sysctl -w net.bridge.bridge-nf-call-iptables=0 > /dev/null
"

SUDO="$SUDO" bash -c '$NETSET'

INAME=$1

for CNAME in ${@:2}
do
  NETFLAG=false
  if echo $CNAME | grep "@$" > /dev/null
  then
    NETFLAG=true
    CNAME=$( echo $CNAME | sed s/@$//g )
  fi

  if [ "`ip netns | grep -w ${CNAME}`" != "" ]
  then
    echo "Network netspace \"${CNAME}\" already exists." >&2
    exit -1
  fi

  if $NETFLAG
  then
    $SUDO docker run -d --privileged --hostname ${CNAME} --name ${CNAME} -e DISPLAY=${DISPLAY} -v /tmp/.X11-unix/:/tmp/.X11-unix -v /sys/fs/cgroup:/sys/fs/cgroup:ro ${INAME} /usr/bin/systemd
  else
    $SUDO docker run -d --privileged --network none --hostname ${CNAME} --name ${CNAME} -e DISPLAY=${DISPLAY} -v /tmp/.X11-unix/:/tmp/.X11-unix -v /sys/fs/cgroup:/sys/fs/cgroup:ro ${INAME} /usr/bin/systemd
  fi

  SUDO="$SUDO" $SUDO docker exec ${CNAME} bash -c '$NETSET'

  ID=`$SUDO docker ps -f "name=${CNAME}" --format '{{.ID}}'`

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
    $SUDO mkdir /var/run/netns
  fi

  $SUDO ln -s /proc/${SYSTEMD_PID}/ns/net /var/run/netns/${CNAME}
done
