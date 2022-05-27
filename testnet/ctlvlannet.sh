#!/bin/bash
#set -e
cd $(dirname $0)/../

#if you set VLAN ID, VLAN ID must be between 0 and 255
VLAN1=100
VLAN2=200

function  printhelp()
{
  case $1 in
    "create")
      echo -e "usage: $0 $1 ([Image Name])" >&2
      echo -e "Create vlan network." >&2
      ;;
    "setup")
      echo -e "usage: $0 $1" >&2
      echo -e "Setup interfaces and configuration." >&2
      ;;
    "clear")
      echo -e "usage: $0 $1" >&2
      echo -e "Clear interfaces and configuration." >&2
      ;;
    "delete")
      echo -e "usage: $0 $1" >&2
      echo -e "Delete vlan network." >&2
      ;;
    *)
      echo -e "usage: $0 [Sub Command]" >&2
      echo -e "" >&2
      echo -e "[Sub Command]" >&2
      echo -e "  help [Sub Command]      Print Help about Sub Command." >&2
      echo -e "  version                 Print version and lisence information." >&2
      echo -e "  create ([Image Name])   Create vlan network." >&2
      echo -e "  setup                   Setup interfaces and configuration." >&2
      echo -e "  clear                   Clear interfaces and configuration." >&2
      echo -e "  delete                  Delete vlan network." >&2
      ;;
  esac
}

function  printversion()
{
      echo -e "$0 ver.0.91"
      echo -e "Copyright (C) 2022 Masanori Yuno (github: yuno-x)."
      echo -e "This is free software: you are free to change and redistribute it."
      echo -e "There is NO WARRANTY, to the extent permitted by law."
}

function setup_vnet()
{
  ./ctl2net.sh connect sw0 - sw1 -
  ./ctl2net.sh connect sw0 - nodeA1 192.168.$VLAN1.1/24
  ./ctl2net.sh connect sw0 - nodeA2 192.168.$VLAN1.2/24
  ./ctl2net.sh connect sw0 - nodeB1 192.168.$VLAN2.1/24
  ./ctl2net.sh connect sw0 - nodeB2 192.168.$VLAN2.2/24
  ./ctl2net.sh connect sw1 - nodeA3 192.168.$VLAN1.3/24
  ./ctl2net.sh connect sw1 - nodeA4 192.168.$VLAN1.4/24
  ./ctl2net.sh connect sw1 - nodeB3 192.168.$VLAN2.3/24
  ./ctl2net.sh connect sw1 - nodeB4 192.168.$VLAN2.4/24

   cat <<EOF | sudo docker exec -i sw0 bash
ip link add vlan$VLAN1 type bridge
ip link add vlan$VLAN2 type bridge

ip link add veth0.$VLAN1 link veth0 type vlan id $VLAN1
ip link add veth0.$VLAN2 link veth0 type vlan id $VLAN2

ip link set veth0.$VLAN1 up
ip link set veth0.$VLAN2 up

ip link set veth0.$VLAN1 master vlan$VLAN1
ip link set veth0.$VLAN2 master vlan$VLAN2

ip link set vlan$VLAN1 up
ip link set vlan$VLAN2 up

ip link set veth1 master vlan$VLAN1
ip link set veth2 master vlan$VLAN1
ip link set veth3 master vlan$VLAN2
ip link set veth4 master vlan$VLAN2
EOF

  cat <<EOF | sudo docker exec -i sw1 bash
ip link add vlan$VLAN1 type bridge
ip link add vlan$VLAN2 type bridge

ip link add veth0.$VLAN1 link veth0 type vlan id $VLAN1
ip link add veth0.$VLAN2 link veth0 type vlan id $VLAN2

ip link set veth0.$VLAN1 up
ip link set veth0.$VLAN2 up

ip link set veth0.$VLAN1 master vlan$VLAN1
ip link set veth0.$VLAN2 master vlan$VLAN2

ip link set vlan$VLAN1 up
ip link set vlan$VLAN2 up

ip link set veth1 master vlan$VLAN1
ip link set veth2 master vlan$VLAN1
ip link set veth3 master vlan$VLAN2
ip link set veth4 master vlan$VLAN2
EOF
}

function create_vnet()
{
  INAME="node"
  if [ "$1" == "" ]
  then
    INAME="$1"
  fi

  ./mkcontainer.sh $INAME nodeA1 nodeA2 nodeB1 nodeB2 sw0 sw1 nodeA3 nodeA4 nodeB3 nodeB4

	setup_vnet
}

function clear_vnet()
{
  cat <<EOF | sudo docker exec -i sw0 bash
for i in \$(seq 0 4)
do
  ip link delete veth\$i
done

ip link delete vlan$VLAN1
ip link delete vlan$VLAN2
EOF

  cat <<EOF | sudo docker exec -i sw1 bash
for i in \$(seq 0 4)
do
  ip link delete veth\$i
done

ip link delete vlan$VLAN1
ip link delete vlan$VLAN2
EOF
}

function  delete_vnet()
{
  ./rmcontainer.sh sw0 sw1 nodeA1 nodeA2 nodeA3 nodeA4 nodeB1 nodeB2 nodeB3 nodeB4
}


if [ "$1" == "" ] || [ "$1" == "help" ]
then
  printhelp $2

  exit -1
fi

SUBCMD=$1

case "$SUBCMD" in
  "create")
    create_vnet ${@:2}
    ;;
  "clear")
    clear_vnet ${@:2}
    ;;
  "setup")
    setup_vnet ${@:2}
    ;;
  "delete")
    delete_vnet ${@:2}
    ;;
  "version")
    printversion
    ;;
  *)
    printhelp

    exit -1
    ;;
esac

