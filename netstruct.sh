#!/bin/bash
cd "$(dirname $0)"
source modules/check.sh

function  devinfo()
{
  ctlv_set_SUDO

  ISBR=$(grep -w "DEVTYPE=bridge" /sys/class/net/$1/uevent)
  if [ "$ISBR" == "" ]
  then
    TYPE="Interface"
  else
    TYPE="bridge"
  fi
  
  IPADDRS=$(ip address show $1 | sed -n "s/.*inet \([0-9]\+.[0-9]\+.[0-9]\+.[0-9]\+\/[0-9]\+\).*/\1/gp")
  if [ "$IPADDRS" == "" ]
  then
    IPADDRS="-"
  fi

  MADDR=$(ip address show $1 | sed -n "s/.*link\/[^ ]* \([0-9a-f].:[0-9a-f].:[0-9a-f].:[0-9a-f].:[0-9a-f].:[0-9a-f].\).*/\1/gp")
  if [ "$MADDR" == "" ]
  then
    MADDR="-"
  fi

  echo -e "################  $1  ################"
  echo -e "[Info]"
  echo -e "TYPE: $TYPE"
  for IPADDR in $IPADDRS
  do
    echo -e "IPADDR: $IPADDR"
  done
  echo -e "MADDR: $MADDR"

  declare -A NSIPADDR
  for NS in $(ip netns list)
  do
    NSIPADDR["$NS"]="$($SUDO ip netns exec $NS ip address)"
  done

  DEVDEVOUTPUT=""
  CONOUTPUT=""
  DEVIDX=1
  for DEVDIRS in `readlink /sys/class/net/$1/lower_*`
  do
    DEV=$(basename $DEVDIRS)
    DEVOUTPUT="${DEVOUTPUT}$DEVIDX: $DEV\n"

    IPADDRS=$(ip address show $DEV | sed -n "s/.*inet \([0-9]\+.[0-9]\+.[0-9]\+.[0-9]\+\/[0-9]\+\).*/\1/gp")
    if [ "$IPADDRS" == "" ]
    then
      IPADDRS="-"
    fi

    MADDR=$(ip address show $DEV | sed -n "s/.*link\/[^ ]* \([0-9a-f].:[0-9a-f].:[0-9a-f].:[0-9a-f].:[0-9a-f].:[0-9a-f].\).*/\1/gp")
    if [ "$MADDR" == "" ]
    then
      MADDR="-"
    fi

    DEVOUTPUT="$DEVOUTPUT    ("
    for IPADDR in $IPADDRS
    do
      DEVOUTPUT="${DEVOUTPUT}IPADDR: $IPADDR, "
    done
    DEVOUTPUT="${DEVOUTPUT}MADDR: $MADDR)\n"

    LINK=$(cat /sys/class/net/$DEV/iflink)
    if [ "$(cat /sys/class/net/$DEV/ifindex)" != "$LINK" ]
    then
      LINKDEV=$(ip address | sed -n "s/^$LINK: \([^@:]*\).*/\1/gp" )
      if [ "$LINKDEV" != "" ]
      then
        IPADDRS=$(ip address show $LINKDEV | sed -n "s/.*inet \([0-9]\+.[0-9]\+.[0-9]\+.[0-9]\+\/[0-9]\+\).*/\1/gp")
        if [ "$IPADDRS" == "" ]
        then
          IPADDRS="-"
        fi

        MADDR=$(ip address show $LINKDEV | sed -n "s/.*link\/[^ ]* \([0-9a-f].:[0-9a-f].:[0-9a-f].:[0-9a-f].:[0-9a-f].:[0-9a-f].\).*/\1/gp")
        if [ "$MADDR" == "" ]
        then
          MADDR="-"
        fi

        MASTERDIR="$(readlink /sys/class/net/$LINKDEV/master)"
        if [ "$MASTERDIR" == "" ]
        then
          CONOUTPUT="${CONOUTPUT}$DEVIDX: -\n"
        else
          MASTER=$(basename $MASTERDIR)
          CONOUTPUT="${CONOUTPUT}$DEVIDX: $MASTER\n"
        fi

        CONOUTPUT="$CONOUTPUT    (DEV: $LINKDEV, "
        for IPADDR in $IPADDRS
        do
          CONOUTPUT="${CONOUTPUT}IPADDR: $IPADDR, "
        done
        CONOUTPUT="${CONOUTPUT}MADDR: $MADDR)\n"
      else
        for NS in $(ip netns list)
        do
          LINKDEV=$(echo "${NSIPADDR["$NS"]}" | sed -n "s/^$LINK: \([^@:]*\).*/\1/gp" )
          if [ "$LINKDEV" != "" ]
          then
            IPADDRS=$($SUDO ip netns exec $NS ip address show $LINKDEV | sed -n "s/.*inet \([0-9]\+.[0-9]\+.[0-9]\+.[0-9]\+\/[0-9]\+\).*/\1/gp")
            if [ "$IPADDRS" == "" ]
            then
              IPADDRS="-"
            fi

            MADDR=$($SUDO ip netns exec $NS ip address show $LINKDEV | sed -n "s/.*link\/[^ ]* \([0-9a-f].:[0-9a-f].:[0-9a-f].:[0-9a-f].:[0-9a-f].:[0-9a-f].\).*/\1/gp")
            if [ "$MADDR" == "" ]
            then
              MADDR="-"
            fi

            CONOUTPUT="${CONOUTPUT}$DEVIDX: $NS\n"
            CONOUTPUT="$CONOUTPUT    (DEV: $LINKDEV, "
            for IPADDR in $IPADDRS
            do
              CONOUTPUT="${CONOUTPUT}IPADDR: $IPADDR, "
            done
            CONOUTPUT="${CONOUTPUT}MADDR: $MADDR)\n"

            break
          fi
        done
      fi
    fi

    DEVIDX=$(( $DEVIDX + 1 ))
  done

  if [ "$DEVOUTPUT" != "" ]
  then
    echo -en "\n[Device Name]\n$DEVOUTPUT"
  fi

  if [ "$CONOUTPUT" != "" ]
  then
    echo -en "\n[Connecting]\n$CONOUTPUT"
  fi
}


function  nodeinfo()
{
  ctlv_set_SUDO

  echo -e "################  $1  ################"
  echo -e "[Info]"
  echo -e "TYPE: NODE"

  declare -A NSIPADDR
  for NS in $(ip netns list)
  do
    NSIPADDR["$NS"]="$($SUDO ip netns exec $NS ip address)"
  done

  DEVDEVOUTPUT=""
  CONOUTPUT=""
  DEVIDX=1
  for DEVDIRS in $($SUDO ip netns exec $1 ls /sys/class/net/)
  do
    DEV=$(basename $DEVDIRS)
    DEVOUTPUT="${DEVOUTPUT}$DEVIDX: $DEV\n"

    IPADDRS=$($SUDO ip netns exec $1 ip address show $DEV | sed -n "s/.*inet \([0-9]\+.[0-9]\+.[0-9]\+.[0-9]\+\/[0-9]\+\).*/\1/gp")
    if [ "$IPADDRS" == "" ]
    then
      IPADDRS="-"
    fi

    MADDR=$($SUDO ip netns exec $1 ip address show $DEV | sed -n "s/.*link\/[^ ]* \([0-9a-f].:[0-9a-f].:[0-9a-f].:[0-9a-f].:[0-9a-f].:[0-9a-f].\).*/\1/gp")
    if [ "$MADDR" == "" ]
    then
      MADDR="-"
    fi

    DEVOUTPUT="$DEVOUTPUT    ("
    for IPADDR in $IPADDRS
    do
      DEVOUTPUT="${DEVOUTPUT}IPADDR: $IPADDR, "
    done
    DEVOUTPUT="${DEVOUTPUT}MADDR: $MADDR)\n"

    LINK=$($SUDO ip netns exec $1 cat /sys/class/net/$DEV/iflink)
    if [ "$($SUDO ip netns exec $1 cat /sys/class/net/$DEV/ifindex)" != "$LINK" ]
    then
      LINKDEV=$(ip address | sed -n "s/^$LINK: \([^@:]*\).*/\1/gp" )
      if [ "$LINKDEV" != "" ]
      then
        IPADDRS=$(ip address show $LINKDEV | sed -n "s/.*inet \([0-9]\+.[0-9]\+.[0-9]\+.[0-9]\+\/[0-9]\+\).*/\1/gp")
        if [ "$IPADDRS" == "" ]
        then
          IPADDRS="-"
        fi

        MADDR=$(ip address show $LINKDEV | sed -n "s/.*link\/[^ ]* \([0-9a-f].:[0-9a-f].:[0-9a-f].:[0-9a-f].:[0-9a-f].:[0-9a-f].\).*/\1/gp")
        if [ "$MADDR" == "" ]
        then
          MADDR="-"
        fi

        MASTERDIR="$(readlink /sys/class/net/$LINKDEV/master)"
        if [ "$MASTERDIR" == "" ]
        then
          CONOUTPUT="${CONOUTPUT}$DEVIDX: -\n"
        else
          MASTER=$(basename $MASTERDIR)
          CONOUTPUT="${CONOUTPUT}$DEVIDX: $MASTER\n"
        fi

        CONOUTPUT="$CONOUTPUT    (DEV: $LINKDEV, "
        for IPADDR in $IPADDRS
        do
          CONOUTPUT="${CONOUTPUT}IPADDR: $IPADDR, "
        done
        CONOUTPUT="${CONOUTPUT}MADDR: $MADDR)\n"
      else
        for NS in $(ip netns list)
        do
          LINKDEV=$(echo "${NSIPADDR["$NS"]}" | sed -n "s/^$LINK: \([^@:]*\).*/\1/gp" )
          if [ "$LINKDEV" != "" ]
          then
            IPADDRS=$($SUDO ip netns exec $NS ip address show $LINKDEV | sed -n "s/.*inet \([0-9]\+.[0-9]\+.[0-9]\+.[0-9]\+\/[0-9]\+\).*/\1/gp")
            if [ "$IPADDRS" == "" ]
            then
              IPADDRS="-"
            fi

            MADDR=$($SUDO ip netns exec $NS ip address show $LINKDEV | sed -n "s/.*link\/[^ ]* \([0-9a-f].:[0-9a-f].:[0-9a-f].:[0-9a-f].:[0-9a-f].:[0-9a-f].\).*/\1/gp")
            if [ "$MADDR" == "" ]
            then
              MADDR="-"
            fi

            CONOUTPUT="${CONOUTPUT}$DEVIDX: $NS\n"
            CONOUTPUT="$CONOUTPUT    (DEV: $LINKDEV, "
            for IPADDR in $IPADDRS
            do
              CONOUTPUT="${CONOUTPUT}IPADDR: $IPADDR, "
            done
            CONOUTPUT="${CONOUTPUT}MADDR: $MADDR)\n"

            break
          fi
        done
      fi
    fi

    DEVIDX=$(( $DEVIDX + 1 ))
  done

  if [ "$DEVOUTPUT" != "" ]
  then
    echo -en "\n[Device Name]\n$DEVOUTPUT"
  fi

  if [ "$CONOUTPUT" != "" ]
  then
    echo -en "\n[Connecting]\n$CONOUTPUT"
  fi
}

if [ "$1" == "" ]
then
  echo "usage: $0 [Node or Bridge Name]" >&2
  
  exit -1
fi

if [ -d /sys/class/net/$1 ]
then
  devinfo  $1
elif [ "$(ip netns list | grep -w $1)" != "" ]
then
  nodeinfo $1
else
  echo "$1 does not exist as node or bridge." >&2
fi
