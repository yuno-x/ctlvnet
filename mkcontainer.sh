#!/bin/bash
cd "$(dirname $0)"
source modules/check.sh
source modules/letdef.sh

function printhelp()
{
  echo -e "$0    ver.0.94"
  echo -e >&2
  echo -e "Copyright (C) 2022 Masanori Yuno (github: yuno-x)."
  echo -e "This is free software: you are free to change and redistribute it."
  echo -e "There is NO WARRANTY, to the extent permitted by law."
  echo -e >&2
  echo -e "usage: $0 [IMAGE NAME] [CONTAINER NAME](:[FLAGS])..." >&2
  echo -e >&2
  echo -e "FLAGS:" >&2
  echo -e "    n ... Connect the default network." >&2
  echo -e "    i ... Start up with /sbin/init instead of /usr/bin/systemd" >&2
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
  INITOPT="/usr/bin/systemd"
  NETOPT="--network none"

  if echo $CNAME | grep :
  then
    FLAGS="$(echo $CNAME | cut -d : -f 2 | sed 's/\(.\)/\1 /g')"
    CNAME=$(echo $CNAME | cut -d : -f 1)
    echo "Creating $CNAME..."

    for FLAG in $FLAGS
    do
      case "$FLAG" in
        "i") INITOPT="/sbin/init" ;;
        "n") NETOPT="" ;;
        *) echo "Cannot recognize option." >&2 ;;
      esac
    done
  fi

  if [ "`ip netns | grep -w ${CNAME}`" != "" ]
  then
    echo "Network netspace \"${CNAME}\" already exists." >&2
    exit -1
  fi

  $SUDO docker run -d --privileged $NETOPT --hostname ${CNAME} --name ${CNAME} -e DISPLAY="${DISPLAY}" -v /tmp/.X11-unix/:/tmp/.X11-unix -v /sys/fs/cgroup:/sys/fs/cgroup:ro ${INAME} $INITOPT

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
