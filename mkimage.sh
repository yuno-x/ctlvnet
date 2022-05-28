#!/bin/bash
cd "$(dirname $0)"

function printsubhelp()
{
  echo "usage: $CMD [Image Name]" >&2
}

function ctlv_mod_not_installed_sw()
{
  local INSTALL_PACKAGE=""
  ctlv_set_SUDO
  for PACKAGE in ${@:2}
  do
    if ! $SUDO docker exec -it $1 apt list $PACKAGE | grep -F '[Installed]' > /dev/null
    then
      INSTALL_PACKAGE="$INSTALL_PACKAGE $PACKAGE"
    fi
  done

  echo $INSTALL_PACKAGE
}

function ctlv_mod_update_sw()
{
  :
}

function ctlv_mod_install()
{
  source modules/check.sh
  ctlv_set_SUDO

  if [ "$( which docker )" == "" ]
  then
    read -p "Do you want to install docker? [y/N]: " ANS
    if [ "$ANS" == "y" ]
    then
      ctlv_check_systemctl

      if ! apt-add-repository --list | grep download.docker.com > /dev/null
      then
        $SUDO apt -y install apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | $SUDO apt-key add -
        $SUDO add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
      fi

      $SUDO apt -y install docker-ce
      $SUDO bash -c 'cat <<EOF > /etc/docker/daemon.json
{
  "storage-driver": "vfs"
}
EOF'
      $SUDO systemctl enable docker
      $SUDO systemctl start docker
    else
      echo "Install Canceled."
      exit -1
    fi
  fi


  if [ "$1" == "" ]
  then
    printsubhelp

    exit -1
  fi
  IMAGENAME=$1

  echo "Installing would take about 15-20min."

  REQUIRED_PACKAGE="bash-completion apt-utils expect tmux vim htop iproute2 iputils-ping iputils-arping iperf3 traceroute curl nmap telnet netcat tcpdump iptables nftables apt-file lsof w3m git python3 systemd avahi-daemon avahi-utils bind9 bind9utils bind9-dnsutils man openssh-server openssh-client telnetd frr apache2 dsniff isc-dhcp-server isc-dhcp-client network-manager"
  SUGGESTED_PACKAGE="wireshark ncat hexedit nkf x11-apps build-essential php mysql-server mysql-client openjdk-18-jdk"
  cat <<EOF
Following packages are required (must be installed to a designated image):
  $REQUIRED_PACKAGE

Following packages are suggested (can be installed to a designated image):
  $SUGGESTED_PACKAGE

EOF

  INSTALL_PACKAGE="$REQUIRED_PACKAGE"
  read -p "Do you want to install each suggested package to a desinated image? [Y/n/i] ('i': interact eachly): " ANS
  if [ "$ANS" == "n" ]
  then
    :
  elif [ "$ANS" == "i" ]
  then
    for PACKAGE in $SUGGESTED_PACKAGE
    do
      read -p "Do you want to install '$PACKAGE' to desinated image? [Y/n]: " ANS
      if [ "$ANS" != "n" ]
      then
        INSTALL_PACKAGE="$INSTALL_PACKAGE $PACKAGE"
      fi
    done
  else
    INSTALL_PACKAGE="$INSTALL_PACKAGE $SUGGESTED_PACKAGE"
  fi

  ctlv_check_systemctl

  $SUDO systemctl restart docker
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

  if echo $INSTALL_PACKAGE | grep -w "wireshark" > /dev/null
  then
    INSTALL_PACKAGE="$(echo $INSTALL_PACKAGE | sed 's/ wireshark[^ ]*//g')"
    $SUDO docker exec -it $CNAME bash -c 'yes no | apt -y install wireshark'
  fi

  $SUDO docker exec -it $CNAME apt -y install $INSTALL_PACKAGE
  $SUDO docker exec -it $CNAME apt -yd install isc-dhcp-relay

  $SUDO docker exec -it $CNAME apt-file update
  $SUDO docker exec $CNAME bash -c 'for FILE in /usr/share/doc/frr/examples/*.sample; do touch /etc/frr/$(basename -s .sample $FILE); done'

  $SUDO docker exec $CNAME sed -i "s/\(^[^#]*d\)=no/\1=yes/g" /etc/frr/daemons
  $SUDO docker exec $CNAME systemctl disable systemd-timesyncd

  $SUDO docker exec $CNAME bash -c 'cat << EOF >> /etc/NetworkManager/NetworkManager.conf

[keyfile]
unmanaged-devices=

[device-all]
match-device=interface-name:*
managed=true
EOF'

#  $SUDO docker exec $CNAME systemctl disable systemd-logind
  $SUDO docker exec $CNAME systemctl disable getty@.service
  $SUDO docker exec $CNAME systemctl disable NetworkManager
  $SUDO docker exec $CNAME systemctl enable nftables
  $SUDO docker exec $CNAME sed -i "s/#enable-reflector=no/#enable-reflector=no\nenable-reflector=yes/g" /etc/avahi/avahi-daemon.conf

  $SUDO docker commit $CNAME $IMAGENAME
  $SUDO docker rm -f `$SUDO docker ps -qf "name=$CNAME"`
}

if [ -z "$SUBCMD" ]
then
  CMD=$0
  ctlv_mod_install $@
fi
