#!/bin/bash

cd $(dirname $0)
cd ../

function  printhelp()
{
  case $1 in
    "create")
      echo -e "usage: $0 $1" >&2
      echo -e "Create virtual ospf network." >&2
      ;;
    "delete")
      echo -e "usage: $0 $1" >&2
      echo -e "Delete virtual ospf network." >&2
      ;;
    *)
      echo -e "usage: $0 [Sub Command]" >&2
      echo -e "" >&2
      echo -e "[Sub Command]" >&2
      echo -e "  help [Sub Command]  Print Help about Sub Command." >&2
      echo -e "  version             Print version and lisence information." >&2
      echo -e "  setup               Setup ospf routing." >&2
      echo -e "  clear               Clear ospf routing." >&2
      echo -e "  create              Create virtual ospf network." >&2
      echo -e "  delete              Delete virtual ospf network." >&2
      ;;
  esac
}

function  printversion()
{
      echo -e "$0 ver.0.90"
      echo -e "Copyright (C) 2021 Masanori Yuno (github: yuno-x)."
      echo -e "This is free software: you are free to change and redistribute it."
      echo -e "There is NO WARRANTY, to the extent permitted by law."
}

function setuproute()
{
  cat <<EOF | sudo docker exec -i rtA0 vtysh
configure terminal
router ospf
network 192.168.100.0/24 area 0
network 100.100.10.0/24 area 0
network 100.100.20.0/24 area 0
EOF

  cat <<EOF | sudo docker exec -i rtA1 vtysh
configure terminal
router ospf
network 100.100.10.0/24 area 0
network 172.16.100.0/24 area 0
network 10.1.1.0/24 area 0
network 10.1.2.0/24 area 0
EOF

  cat <<EOF | sudo docker exec -i rtA2 vtysh
configure terminal
router ospf
network 100.100.20.0/24 area 0
network 172.16.100.0/24 area 0
network 10.2.1.0/24 area 0
network 10.2.2.0/24 area 0
EOF

  cat <<EOF | sudo docker exec -i rtB0 vtysh
configure terminal
router ospf
network 192.168.200.0/24 area 0
network 200.200.10.0/24 area 0
network 200.200.20.0/24 area 0
EOF

  cat <<EOF | sudo docker exec -i rtB1 vtysh
configure terminal
router ospf
network 200.200.10.0/24 area 0
network 172.16.200.0/24 area 0
network 10.1.1.0/24 area 0
network 10.2.1.0/24 area 0
EOF

  cat <<EOF | sudo docker exec -i rtB2 vtysh
configure terminal
router ospf
network 200.200.20.0/24 area 0
network 172.16.200.0/24 area 0
network 10.1.2.0/24 area 0
network 10.2.2.0/24 area 0
EOF
}

function clearroute()
{
  for NODE in rtA0 rtA1 rtA2 rtB0 rtB1 rtB2
  do
    echo "Clearing $NODE's routing."
    sudo docker exec -it $NODE systemctl restart frr
  done
}

function createnet()
{
  ./mkcontainer.sh node nodeA rtA0 rtA1 rtA2 rtB1 rtB2 rtB0 nodeB
  
  ./ctl2net.sh connect nodeA 192.168.100.1/24 rtA0 192.168.100.254/24
  ./ctl2net.sh connect rtA0 100.100.10.1/24 rtA1 100.100.10.2/24
  ./ctl2net.sh connect rtA0 100.100.20.1/24 rtA2 100.100.20.2/24
  ./ctl2net.sh connect rtA1 172.16.100.1/24 rtA2 172.16.100.2/24

  ./ctl2net.sh connect nodeB 192.168.200.1/24 rtB0 192.168.200.254/24
  ./ctl2net.sh connect rtB0 200.200.10.1/24 rtB1 200.200.10.2/24
  ./ctl2net.sh connect rtB0 200.200.20.1/24 rtB2 200.200.20.2/24
  ./ctl2net.sh connect rtB1 172.16.200.1/24 rtB2 172.16.200.2/24

  ./ctl2net.sh connect rtA1 10.1.1.100/24 rtB1 10.1.1.200/24
  ./ctl2net.sh connect rtA2 10.2.2.100/24 rtB2 10.2.2.200/24
  ./ctl2net.sh connect rtA1 10.1.2.100/24 rtB2 10.1.2.200/24
  ./ctl2net.sh connect rtA2 10.2.1.100/24 rtB1 10.1.1.200/24

  sudo docker exec -it nodeA ip route add default via 192.168.100.254
  sudo docker exec -it nodeB ip route add default via 192.168.200.254

  setuproute
}

function  deletenet()
{
  ./rmcontainer.sh nodeA rtA0 rtA1 rtA2 rtB1 rtB2 rtB0 nodeB
}


if [ "$1" == "" ] || [ "$1" == "help" ]
then
  printhelp $2

  exit -1
fi

SUBCMD=$1

case "$SUBCMD" in
  "setup")
    setuproute
    ;;
  "clear")
    clearroute
    ;;
  "delete")
    deletenet
    ;;
  "create")
    createnet
    ;;
  "version")
    printversion
    ;;
  *)
    printhelp

    exit -1
    ;;
esac

