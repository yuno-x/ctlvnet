#!/bin/bash
cd "$(dirname $0)"
source $PWD/modules/check.sh

function ctlv_mod_rmcontainer()
{

  if [ "$1" == "" ]
  then
    echo "usage: $0 [CONTAINER NAME]..."
    exit -1
  fi

  ctlv_set_SUDO

  for CNAME in $@
  do
    $SUDO docker exec ${CNAME} systemctl halt > /dev/null 2>&1
    $SUDO docker rm -f ${CNAME}
    if [ -h /var/run/netns/${CNAME} ]
    then
      $SUDO rm /var/run/netns/${CNAME}
    fi
  done
}

if [ -z "$SUBCMD" ]
then
  CMD=$0
  ctlv_mod_rmcontainer $@
fi
