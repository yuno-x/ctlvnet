#!/bin/bash

if [ "`which docker`" == "" ]
then
  echo -n "Do you want to install docker? [y/n]: "
  read ANS
  if [ "$ANS" == "y" ]
  then
    sudo apt -y install apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
    sudo apt -y install docker-ce
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

EXISTIMAGE=$(sudo docker images $IMAGENAME | grep -v "REPOSITORY")
CNAME=$IMAGENAME

if [ "$EXISTIMAGE" != "" ]
then
  echo "Docker image \"$IMAGENAME\" already exists." >&2
  exit -1
fi

EXISTIMAGE=$(sudo docker images ubuntu | grep -v "REPOSITORY")
if [ "$EXISTIMAGE" == "" ]
then
  sudo docker pull ubuntu
fi
sudo docker run --hostname ubuntu --name ubuntu --detach ubuntu bash -c "while [ 1 ]; do sleep 600; done"
sudo docker commit ubuntu $IMAGENAME
sudo docker rm -f `sudo docker ps -qf "name=ubuntu"`


sudo docker run --hostname $CNAME --name $CNAME --detach $IMAGENAME bash -c "while [ 1 ]; do sleep 600; done"
sudo docker exec $CNAME bash -c 'echo "Asia/Tokyo" > /etc/timezone'
sudo docker exec $CNAME bash -c 'ln -s /usr/share/zoneinfo/Asia/Tokyo /etc/localtime'
sudo docker exec $CNAME bash -c 'cat << EOF >> ~/.bashrc
if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
    . /etc/bash_completion
fi
EOF'

sudo docker exec -it $CNAME apt update
sudo docker exec -it $CNAME apt-file update
sudo docker exec -it $CNAME bash -c 'yes no | apt -y install wireshark'
sudo docker exec -it $CNAME bash -c 'yes | unminimize'
sudo docker exec -it $CNAME apt -y install apt-utils tmux vim htop hexedit iproute2 iputils-ping inetutils-traceroute curl nmap telnet tcpdump apt-file w3m x11-apps git build-essential python3 openjdk-16-jdk systemd avahi-daemon avahi-utils bind9 bind9utils man openssh-server openssh-client telnetd frr apache2 php dsniff isc-dhcp-server mysql-server mysql-client
sudo docker exec $CNAME bash -c 'for FILE in `ls /usr/share/doc/frr/examples/*.sample`; do touch /etc/frr/$(basename -s .sample $FILE); done'

sudo docker exec $CNAME sed -i "s/\(^[^#]*d\)=no/\1=yes/g" /etc/frr/daemons
#sudo docker exec $CNAME sed -i "s/^\(ospfd=yes\)/\1\nospfd_instances=$(seq -s , 1 8)/g" /etc/frr/daemons
sudo docker exec $CNAME systemctl disable systemd-timesyncd
sudo docker exec $CNAME sed -i "s/#enable-reflector=no/#enable-reflector=no\nenable-reflector=yes/g" /etc/avahi/avahi-daemon.conf

sudo docker commit $CNAME $IMAGENAME
sudo docker rm -f `sudo docker ps -qf "name=$CNAME"`
