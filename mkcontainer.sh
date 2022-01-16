#!/bin/bash
cd "$(dirname $0)"
source modules/check.sh
source modules/letdef.sh

function printhelp()
{
  echo "usage: $0 [IMAGE NAME] [CONTAINER NAME]..." >&2
  echo >&2
  echo "If you add a character '@' at last of container name, its container is also connected to default docker network." >&2
}

if [ "$1" == "" ]
then
  printhelp

  exit -1
fi

ctlv_check_systemctl
ctlv_set_SUDO

INAME=$1

for CNAME in ${@:2}
do
  echo "Creating $CNAME..."
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

  SUDO="$SUDO" $SUDO docker exec ${CNAME} bash -c "$CTLV_SYSNETSET"

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
