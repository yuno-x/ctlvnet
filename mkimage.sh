#!/bin/bash

if [ "$( whoami )" == "root" ]
then
  SUDO=""
else
  if ! sudo echo -n
  then
    echo "You must have permission to use sudo command." >&2
    exit -1
  fi

  SUDO=sudo
fi

if [ "$( which docker )" == "" ]
then
  echo -n "Do you want to install docker? [y/n]: "
  read ANS
  if [ "$ANS" == "y" ]
  then
    $SUDO apt -y install apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | $SUDO apt-key add -
    $SUDO add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
    $SUDO apt -y install docker-ce
  else
    echo "Install Canceled."
    exit -1
  fi
fi


if [ "$1" == "" ]
then
  echo "usage: $0 [Image Name]" >&2
  exit -1
fi
IMAGENAME=$1

if ! systemctl --no-pager > /dev/null 2>&1
then
  echo "Systemd seems not to be runnnig."

  exit -1
fi

$SUDO systemctl enable docker
EXISTIMAGE=$($SUDO docker images $IMAGENAME | grep -v "REPOSITORY")
CNAME=$IMAGENAME

if [ "$EXISTIMAGE" != "" ]
then
  echo "Docker image \"$IMAGENAME\" already exists." >&2
  exit -1
fi

EXISTIMAGE=$($SUDO docker images ubuntu | grep -v "REPOSITORY" 2> /dev/null)
if [ "$EXISTIMAGE" == "" ]
then
  $SUDO docker pull ubuntu
fi
$SUDO docker run --hostname ubuntu --name ubuntu --detach ubuntu bash -c "while [ 1 ]; do sleep 600; done"
$SUDO docker commit ubuntu $IMAGENAME
$SUDO docker rm -f `$SUDO docker ps -qf "name=ubuntu"`


$SUDO docker run --hostname $CNAME --name $CNAME --detach $IMAGENAME bash -c "while [ 1 ]; do sleep 600; done"
$SUDO docker exec $CNAME bash -c 'echo "Asia/Tokyo" > /etc/timezone'
$SUDO docker exec $CNAME bash -c 'ln -s /usr/share/zoneinfo/Asia/Tokyo /etc/localtime'
$SUDO docker exec $CNAME bash -c 'cat << EOF >> ~/.bashrc
if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
    . /etc/bash_completion
fi
EOF'

$SUDO docker exec -it $CNAME apt update
$SUDO docker exec -it $CNAME bash -c 'yes | unminimize'
$SUDO docker exec -it $CNAME bash -c 'yes no | apt -y install wireshark'
$SUDO docker exec -it $CNAME apt -y install bash-completion apt-utils tmux vim htop hexedit iproute2 iputils-ping traceroute curl nmap telnet tcpdump iptables apt-file w3m nkf x11-apps git build-essential python3 openjdk-16-jdk systemd avahi-daemon avahi-utils bind9 bind9utils man openssh-server openssh-client telnetd frr apache2 php dsniff isc-dhcp-server mysql-server mysql-client
$SUDO docker exec -it $CNAME apt-file update
$SUDO docker exec $CNAME bash -c 'for FILE in `ls /usr/share/doc/frr/examples/*.sample`; do touch /etc/frr/$(basename -s .sample $FILE); done'

$SUDO docker exec $CNAME sed -i "s/\(^[^#]*d\)=no/\1=yes/g" /etc/frr/daemons
#$SUDO docker exec $CNAME sed -i "s/^\(ospfd=yes\)/\1\nospfd_instances=$(seq -s , 1 8)/g" /etc/frr/daemons
$SUDO docker exec $CNAME systemctl disable systemd-timesyncd
$SUDO docker exec $CNAME sed -i "s/#enable-reflector=no/#enable-reflector=no\nenable-reflector=yes/g" /etc/avahi/avahi-daemon.conf

$SUDO docker commit $CNAME $IMAGENAME
$SUDO docker rm -f `$SUDO docker ps -qf "name=$CNAME"`
