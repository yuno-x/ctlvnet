#!/bin/bash

function  printhelp()
{
  case $1 in
    "setup")
      echo -e "usage: $0 $1 [Bridge Name] ([Node Name] [IP Address])..." >&2
      echo -e "" >&2
      echo -e "[Bridge Name] ... Virtual bridge made by ip link command." >&2
      echo -e "[Node Name]   ... Virtual node made by ip netns command." >&2
      echo -e "[IP Address]  ... IP address with prefix. For example, 192.168.0.11/24." >&2
      echo -e "                  If \"-\" is written in this place, IP address will be not set." >&2
      ;;
    "create")
      echo -e "usage: $0 $1 [Bridge Name] ([Node Name])..." >&2
      echo -e "" >&2
      echo -e "[Bridge Name] ... Virtual bridge made by ip link command." >&2
      echo -e "[Node Name]   ... Virtual node made by ip netns command." >&2
      ;;
    "connect")
      echo -e "usage: $0 $1 [Node or Bridge Name] [IP Address] [Node or Bridge Name] [IP Address]" >&2
      echo -e "" >&2
      echo -e "[Node or Bridge Name]  ... Virtual node (or bridge) made by ip netns (or ip link) command." >&2
      echo -e "[IP Address]           ... IP address with prefix. For example, 192.168.0.11/24." >&2
      echo -e "                           If \"-\" is written in this place, IP address will be not set." >&2
      ;;
    "delete")
      echo -e "usage: $0 $1 [Node or Bridge Name]..." >&2
      echo -e "" >&2
      echo -e "[Node or Bridge Name]  ... Virtual node (or bridge) made by ip netns (or ip link) command." >&2
      ;;
    *)
      echo -e "usage: $0 [Sub Command]" >&2
      echo -e "" >&2
      echo -e "[Sub Command]" >&2
      echo -e "  help [Sub Command]  Print Help about Sub Command." >&2
      echo -e "  version             Print version and lisence information." >&2
      echo -e "  setup               Create bridge and some nodes. Furthermore, set IP address to Node's Interface." >&2
      echo -e "  create              Create bridge and some nodes." >&2
      echo -e "  connect             Connect 2 nodes (or bridges). Furthermore, set IP address to Node's Interface." >&2
      echo -e "  delete              Delete some nodes and bridges." >&2
      echo -e "" >&2
      echo -e "For example:" >&2
      echo -e "  $0 setup br0 node0 172.18.0.10/24 node1 172.18.0.11/24 node2 172.18.0.12/24" >&2
      ;;
  esac
}


function  printversion()
{
      echo -e "$0 ver.0.92"
      echo -e "Copyright (C) 2021 Masanori Yuno (github: yuno-x)."
      echo -e "This is free software: you are free to change and redistribute it."
      echo -e "There is NO WARRANTY, to the extent permitted by law."
}

function  create_node()
{
  if ! sudo ip link > /dev/null 2>&1
  then
    echo -e "You seem not to have enough permission or commands. Exit.." >&2

    exit -1
  fi

#  sudo sysctl -w net.ipv4.ip_forward=1 > /dev/null
#  sudo sysctl -w net.bridge.bridge-nf-call-iptables=0 > /dev/null

  BR=$1
  sudo ip link add $BR type bridge

  i=0
  for NODE in ${@:2}
  do
    sudo ip link add c_veno0 type veth peer name ${BR}_veth$i
    if [ "`ip netns | grep -w $NODE`" == "" ]
    then
      sudo ip netns add $NODE
    fi
    sudo ip link set ${BR}_veth$i master $BR
    sudo ip link set c_veno0 netns $NODE
    sudo ip link set ${BR}_veth$i up
    sudo ip netns exec $NODE ip link set c_veno0 name veth0
    sudo ip netns exec $NODE ip link set veth0 up

    i=$(( $i + 1 ))
  done

  sudo ip link set $BR up
}

function  setup_node()
{
  if ! sudo ip link > /dev/null 2>&1
  then
    echo -e "You seem not to have enough permission or commands. Exit.." >&2

    exit -1
  fi

#  sudo sysctl -w net.ipv4.ip_forward=1 > /dev/null
#  sudo sysctl -w net.bridge.bridge-nf-call-iptables=0 > /dev/null

  BR=$1
  sudo ip link add $BR type bridge

  i=0
  n=2
  while [ $n -lt $# ]
  do
    NODE=${@:$n:1}
    ADDR=${@:$n+1:1}
    
    IFNUM=`sudo ip netns exec $NODE ls /sys/class/net | sed -n "s/veth\([0-9]*\)/\1/gp" | sort -n | tail -n 1`
    if [ "$IFNUM" == "" ]
    then
      NEWIFNUM=0
    else
      NEWIFNUM=$(( $IFNUM + 1 ))
    fi

    sudo ip link add c_veno0 type veth peer name ${BR}_veth$i
    if [ "`ip netns | grep -w $NODE`" == "" ]
    then
      sudo ip netns add $NODE
    fi
    sudo ip link set ${BR}_veth$i master $BR
    sudo ip link set c_veno0 netns $NODE
    sudo ip link set ${BR}_veth$i up
    sudo ip netns exec $NODE ip link set c_veno0 name veth${NEWIFNUM}
    if [ "$ADDR" != "-" ]
    then
      sudo ip netns exec $NODE ip address add $ADDR dev veth${NEWIFNUM}
    fi
    sudo ip netns exec $NODE ip link set veth${NEWIFNUM} up

    i=$(( $i + 1 ))
    n=$(( $n + 2 ))
  done

  sudo ip link set $BR up
}

function  delete_node()
{
  if ! sudo ip link > /dev/null 2>&1
  then
    echo -e "You seem not to have enough permission or commands. Exit.." >&2

    exit -1
  fi

  for NODE in $@
  do
    if [ -d /sys/class/net/$NODE ]
    then
      BR=$NODE
      for BRIF in `ip link show master $BR type veth | sed -n "s/.*[ \t]\([^ \t]*\)@[^ \t]*:.*/\1/gp"`
      do
        sudo ip link delete $BRIF
      done
      sudo ip link delete $BR

    elif [ "`ip netns | grep -w $NODE`" != "" ]
    then
      sudo ip netns delete $NODE
    else
      echo -e "$NODE does not exist as node or bridge." >&2
    fi
  done
}

function  connect_node()
{
  if [ $# != 4 ]
  then
    printhelp connect

    exit -1
  fi

  if ! sudo ip link > /dev/null 2>&1
  then
    echo -e "You seem not to have enough permission or commands. Exit.." >&2

    exit -1
  fi

#  sudo sysctl -w net.ipv4.ip_forward=1 > /dev/null
#  sudo sysctl -w net.bridge.bridge-nf-call-iptables=0 > /dev/null

  n=1
  while [ $n -lt $# ]
  do
    NODE=${@:$n:1}
    ADDR=${@:$n+1:1}

    if [ -d /sys/class/net/$NODE ]
    then
      BR=$NODE

      IFNUM=`ls /sys/class/net/ | sed -n "s/${BR}_veth\([0-9]*\)/\1/gp" | sort -n | tail -n 1`
      if [ "$IFNUM" == "" ]
      then
        NEWIFNUM=0
      else
        NEWIFNUM=$(( $IFNUM + 1 ))
      fi

      if [ -d /sys/class/net/c_veno0 ]
      then
        sudo ip link set c_veno0 name ${BR}_veth${NEWIFNUM}
      else
        sudo ip link add c_veno0 type veth peer ${BR}_veth${NEWIFNUM}
      fi

      sudo ip link set ${BR}_veth${NEWIFNUM} master $BR

      if [ "$ADDR" != "-" ]
      then
        sudo ip address add $ADDR dev ${BR}_veth${NEWIFNUM}
      fi

      sudo ip link set ${BR}_veth${NEWIFNUM} up

    elif [ "`ip netns | grep -w $NODE`" != "" ]
    then
      IFNUM=`sudo ip netns exec $NODE ls /sys/class/net | sed -n "s/veth\([0-9]*\)/\1/gp" | sort -n | tail -n 1`
      if [ "$IFNUM" == "" ]
      then
        NEWIFNUM=0
      else
        NEWIFNUM=$(( $IFNUM + 1 ))
      fi

      if [ -d /sys/class/net/c_veno0 ]
      then
        sudo ip link set c_veno0 netns $NODE
        sudo ip netns exec $NODE ip link set c_veno0 name veth${NEWIFNUM}
      else
        sudo ip link add c_veno0 type veth peer c_venp0
        sudo ip link set c_venp0 netns $NODE
        sudo ip netns exec $NODE ip link set c_venp0 name veth${NEWIFNUM}
      fi


      if [ "$ADDR" != "-" ]
      then
        sudo ip netns exec $NODE ip address add $ADDR dev veth${NEWIFNUM}
      fi

      sudo ip netns exec $NODE ip link set veth${NEWIFNUM} up

    elif [ "$NODE" == "-" ]
    then
      IFNUM=`ls /sys/class/net/ | sed -n "s/veth\([0-9]*\)/\1/gp" | sort -n | tail -n 1`
      if [ "$IFNUM" == "" ]
      then
        NEWIFNUM=0
      else
        NEWIFNUM=$(( $IFNUM + 1 ))
      fi

      if [ -d /sys/class/net/c_veno0 ]
      then
        sudo ip link set c_veno0 name veth${NEWIFNUM}
      else
        sudo ip link add c_veno0 type veth peer veth${NEWIFNUM}
      fi

      if [ "$ADDR" != "-" ]
      then
        sudo ip address add $ADDR dev veth${NEWIFNUM}
      fi

      sudo ip link set veth${NEWIFNUM} up

    else
      echo -e "$NODE does not exist as node or bridge." >&2
    fi

    n=$(( $n + 2 ))
  done
}


if [ "$1" == "" ] || [ "$1" == "help" ]
then
  printhelp $2

  exit -1
fi


SUBCMD=$1

case "$SUBCMD" in
  "create")
    if [ "$2" == "" ]
    then
      printhelp $1

      exit -1
    fi

    create_node ${@:2}
    ;;
  "delete")
    if [ "$2" == "" ]
    then
      printhelp $1

      exit -1
    fi

    delete_node ${@:2}
    ;;
  "setup")
    if [ "$2" == "" ]
    then
      printhelp $1

      exit -1
    fi

    setup_node ${@:2}
    ;;
  "connect")
    if [ "$2" == "" ]
    then
      printhelp $1

      exit -1
    fi

    connect_node ${@:2}
    ;;
  "version")
    printversion
    ;;
  *)
    printhelp

    exit -1
    ;;
esac
