#!/bin/bash

cd $(dirname $0)
cd ../

function  printhelp()
{
  case $1 in
    "create")
      echo -e "usage: $0 $1" >&2
      echo -e "Create virtual bgp and ospf network." >&2
      ;;
    "delete")
      echo -e "usage: $0 $1" >&2
      echo -e "Delete virtual bgp and ospf network." >&2
      ;;
    *)
      echo -e "usage: $0 [Sub Command]" >&2
      echo -e "" >&2
      echo -e "[Sub Command]" >&2
      echo -e "  help [Sub Command]  Print Help about Sub Command." >&2
      echo -e "  version             Print version and lisence information." >&2
      echo -e "  create              Create virtual bgp and ospf network." >&2
      echo -e "  delete              Delete virtual bgp and ospf network." >&2
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

function create_ripnet()
{
  ./mkcontainer.sh node rt0 rt1 rt2 rt3 rt4 nodeA1 nodeA2 nodeA3 nodeB1 nodeB2 nodeC1 nodeC2 nodeD1 nodeD2
  ./ctl2net.sh setup brA nodeA1 172.18.1.1/24 nodeA2 172.18.1.2/24 nodeA3 172.18.1.3/24 rt0 172.18.1.254/24
  ./ctl2net.sh setup brB nodeB1 172.18.2.1/24 nodeB2 172.18.2.2/24 rt0 172.18.2.254/24
  ./ctl2net.sh setup brC nodeC1 10.0.3.1/24 nodeC2 10.0.3.2/24 rt3 10.0.3.254/24
  ./ctl2net.sh setup brD nodeD1 192.168.4.1/24 nodeD2 192.168.4.2/24 rt4 192.168.4.254/24
  ./ctl2net.sh connect rt0 100.100.100.1/24 rt1 100.100.100.2/24
  ./ctl2net.sh connect rt1 110.110.110.1/24 rt2 110.110.110.2/24
  ./ctl2net.sh connect rt2 120.120.120.1/24 rt3 120.120.120.2/24
  ./ctl2net.sh connect rt2 130.130.130.1/24 rt4 130.130.130.2/24

  cat <<EOF | sudo docker exec -i rt0 vtysh
configure terminal
router bgp 100
neighbor 100.100.100.2 remote-as 200
network 172.18.1.0 mask 255.255.255.0
network 172.18.2.0 mask 255.255.255.0
EOF

  cat <<EOF | sudo docker exec -i rt1 vtysh
configure terminal
router bgp 200
neighbor 100.100.100.1 remote-as 100
neighbor 110.110.110.2 remote-as 300
EOF

  cat <<EOF | sudo docker exec -i rt2 vtysh
configure terminal
router bgp 300
neighbor 110.110.110.1 remote-as 200
network 10.0.3.0 mask 255.255.255.0
network 192.168.4.0 mask 255.255.255.0
router ospf
redistribute bgp
network 120.120.120.0/24 area 0
network 130.130.130.0/24 area 0
EOF

  cat <<EOF | sudo docker exec -i rt3 vtysh
configure terminal
router ospf
network 120.120.120.0/24 area 0
network 10.0.3.0/24 area 0
EOF

  cat <<EOF | sudo docker exec -i rt4 vtysh
configure terminal
router ospf
network 130.130.130.0/24 area 0
network 192.168.4.0/24 area 0
EOF

  for NODE in nodeA1 nodeA2 nodeA3; do sudo docker exec -it $NODE ip route add default via 172.18.1.254; done
  for NODE in nodeB1 nodeB2; do sudo docker exec -it $NODE ip route add default via 172.18.2.254; done
  for NODE in nodeC1 nodeC2; do sudo docker exec -it $NODE ip route add default via 10.0.3.254; done
  for NODE in nodeD1 nodeD2; do sudo docker exec -it $NODE ip route add default via 192.168.4.254; done
}

function  delete_ripnet()
{
  ./rmcontainer.sh rt0 rt1 rt2 rt3 rt4 nodeA1 nodeA2 nodeA3 nodeB1 nodeB2 nodeC1 nodeC2 nodeD1 nodeD2
  ./ctl2net.sh delete brA brB brC brD
}


if [ "$1" == "" ] || [ "$1" == "help" ]
then
  printhelp $2

  exit -1
fi

SUBCMD=$1

case "$SUBCMD" in
  "delete")
    delete_ripnet ${@:2}
    ;;
  "create")
    create_ripnet ${@:2}
    ;;
  "version")
    printversion
    ;;
  *)
    printhelp

    exit -1
    ;;
esac
