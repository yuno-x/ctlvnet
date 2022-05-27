#!/bin/bash
cd "$(dirname $0)"
source modules/check.sh
source modules/letdef.sh

function printsubhelp()
{
  echo -e "$CMD    ver.0.94"
  echo -e >&2
  echo -e "Copyright (C) 2022 Masanori Yuno (github: yuno-x)."
  echo -e "This is free software: you are free to change and redistribute it."
  echo -e "There is NO WARRANTY, to the extent permitted by law."
  echo -e >&2
  echo -e "usage: $CMD [IMAGE NAME] [CONTAINER NAME](:[FLAGS])..." >&2
  echo -e >&2
  echo -e "FLAGS:" >&2
  echo -e "    n ... Connect the default network." >&2
  echo -e "    b ... Run /bin/bash instead of /sbin/init." >&2
}

function ctlv_mod_mkcontainer()
{
  if [ "$1" == "" ]
  then
    printsubhelp

    exit -1
  fi

  ctlv_check_systemctl
  ctlv_set_SUDO

  ulimit -Sn 65536
  ulimit -Hn 65536

  INAME=$1

  for CNAME in ${@:2}
  do
    NETOPT="--network none"
    INITCMD="/sbin/init"

    if echo $CNAME | grep : > /dev/null
    then
      FLAGS="$(echo $CNAME | cut -d : -f 2 | sed 's/\(.\)/\1 /g')"
      CNAME=$(echo $CNAME | cut -d : -f 1)
      echo "Creating $CNAME..."

      for FLAG in $FLAGS
      do
        case "$FLAG" in
          "n") NETOPT="" ;;
          "b") NETOPT="/bin/bash" ;;
          *) echo "Cannot recognize option." >&2 ;;
        esac
      done
    fi

    if [ "`ip netns | grep -w ${CNAME}`" != "" ]
    then
      echo "Network netspace \"${CNAME}\" already exists." >&2
      exit -1
    fi
    
    $SUDO docker run -d --privileged $NETOPT --hostname ${CNAME} --name ${CNAME} --cgroupns host --cgroup-parent docker.slice  -e DISPLAY -e QT_X11_NO_MITSHM=1 -v /tmp/.X11-unix/:/tmp/.X11-unix -v /sys/fs/cgroup:/sys/fs/cgroup:rw ${INAME} ${INITCMD}

    SUDO="$SUDO" $SUDO docker exec ${CNAME} bash -c "$CTLV_SYSNETSET"

    ID=`$SUDO docker ps -f "name=${CNAME}" --format '{{.ID}}'`

    SYSTEMD_PID=$($SUDO docker inspect ${ID} --format '{{.State.Pid}}')

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
}

if [ -z "$SUBCMD" ]
then
  CMD=$0
  ctlv_mod_mkcontainer $@
fi
