#!/bin/bash
#set -e
cd $(dirname $0)/../

function  printhelp()
{
  case $1 in
    "create")
      echo -e "usage: $0 $1 ([Image Name])" >&2
      echo -e "Create vlan network." >&2
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

function create_vnet()
{
  INAME="node"
  if [ "$1" == "" ]
  then
    INAME="$1"
  fi

#if you set VLAN ID, VLAN ID must be between 0 and 255
  VLAN1=100
  VLAN2=200

  ./mkcontainer.sh $INAME nodeA1 nodeA2 nodeB1 nodeB2 sw0 sw1 nodeA3 nodeA4 nodeB3 nodeB4
  ./ctl2net.sh connect sw0 - sw1 -
  ./ctl2net.sh connect sw0 - nodeA1 -
  ./ctl2net.sh connect sw0 - nodeA2 -
  ./ctl2net.sh connect sw0 - nodeB1 -
  ./ctl2net.sh connect sw0 - nodeB2 -
  ./ctl2net.sh connect sw1 - nodeA3 -
  ./ctl2net.sh connect sw1 - nodeA4 -
  ./ctl2net.sh connect sw1 - nodeB3 -
  ./ctl2net.sh connect sw1 - nodeB4 -
  
  cat <<EOF | sudo docker exec -i sw0 bash
ip link add br0 type bridge
for i in \$(seq 0 4); do ip link set veth\$i master br0; done
ip link set br0 up
EOF

  cat <<EOF | sudo docker exec -i sw1 bash
ip link add br0 type bridge
for i in \$(seq 0 4); do ip link set veth\$i master br0; done
ip link set br0 up
EOF

for i in $(seq 1 4)
do
  cat <<EOF | sudo docker exec -i nodeA$i bash
ip link add veth0.$VLAN1 link veth0 type vlan id $VLAN1
ip link set veth0.$VLAN1 up
ip address add 192.168.$VLAN1.$i/24 dev veth0.$VLAN1
EOF
done

for i in $(seq 1 4)
do
  cat <<EOF | sudo docker exec -i nodeB$i bash
ip link add veth0.$VLAN2 link veth0 type vlan id $VLAN2
ip link set veth0.$VLAN2 up
ip address add 192.168.$VLAN2.$i/24 dev veth0.$VLAN2
EOF
done
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
  "delete")
    delete_vnet ${@:2}
    ;;
  "create")
    create_vnet ${@:2}
    ;;
  "version")
    printversion
    ;;
  *)
    printhelp

    exit -1
    ;;
esac

