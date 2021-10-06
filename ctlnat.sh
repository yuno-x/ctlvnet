#!/bin/bash

function  printhelp()
{
  echo -e "usage: $0 [Sub Command] [External Interface] [Internal Interface]" >&2
}

function  set_nat()
{
  NIP=`ip route | grep -w $2 | sed "s/^\([^ \t]*\).*/\1/g"`

  INRULE=`sudo iptables -nvL FORWARD --line-number | grep "ACCEPT[ \t]*all[ \t]*--[ \t]*$1[ \t]*\*[ \t]*0\.0\.0\.0/0[ \t]*0\.0\.0\.0/0[ \t]*state RELATED,ESTABLISHED" | cut -d ' ' -f 1`
  if [ "$INRULE" == "" ]
  then
    sudo iptables -A FORWARD -m state --state ESTABLISHED,RELATED -i $1 -j ACCEPT
  fi

  OUTRULE=`sudo iptables -nvL FORWARD --line-number | grep "ACCEPT[ \t]*all[ \t]*--[ \t]*\*[ \t]*$1[ \t]*0\.0\.0\.0/0[ \t]*0\.0\.0\.0/0" | cut -d ' ' -f 1`
  if [ "$OUTRULE" == "" ]
  then
    sudo iptables -A FORWARD -o $1 -j ACCEPT
  fi

  MQRULE=`sudo iptables -t nat -nvL POSTROUTING --line-number | grep "MASQUERADE[ \t]*all[ \t]*--[ \t]*\*[ \t]*$1[ \t]*$NIP[ \t]*0\.0\.0\.0/0" | cut -d ' ' -f 1`
  if [ "$MQRULE" == "" ]
  then
#    sudo iptables -t nat -A POSTROUTING -o $1 -s $NIP -j MASQUERADE
    sudo iptables -t nat -A POSTROUTING -s $NIP -j MASQUERADE
  fi
}

function  unset_nat()
{
  NIP=`ip route | grep -w $2 | sed "s/^\([^ \t]*\).*/\1/g"`

  INRULE=`sudo iptables -nvL FORWARD --line-number | grep "ACCEPT[ \t]*all[ \t]*--[ \t]*$1[ \t]*\*[ \t]*0\.0\.0\.0/0[ \t]*0\.0\.0\.0/0[ \t]*state RELATED,ESTABLISHED" | cut -d ' ' -f 1 | tac`
  for N in $INRULE
  do
    sudo iptables -D FORWARD $N
  done

  OUTRULE=`sudo iptables -nvL FORWARD --line-number | grep "ACCEPT[ \t]*all[ \t]*--[ \t]*\*[ \t]*$1[ \t]*0\.0\.0\.0/0[ \t]*0\.0\.0\.0/0" | cut -d ' ' -f 1 | tac`
  for N in $OUTRULE
  do
    sudo iptables -D FORWARD $N
  done

#  MQRULE=`sudo iptables -t nat -nvL POSTROUTING --line-number | grep "MASQUERADE[ \t]*all[ \t]*--[ \t]*\*[ \t]*$1[ \t]*$NIP[ \t]*0\.0\.0\.0/0" | cut -d ' ' -f 1 | tac`
  MQRULE=`sudo iptables -t nat -nvL POSTROUTING --line-number | grep "MASQUERADE[ \t]*all[ \t]*--[ \t]*\*[ \t]*\*[ \t]*$NIP[ \t]*0\.0\.0\.0/0" | cut -d ' ' -f 1 | tac`
  for N in $MQRULE
  do
    sudo iptables -t nat -D POSTROUTING $N
  done
}


if [ $# != 3 ]
then
  printhelp

  exit -1
fi

case $1 in
  "set")
    set_nat ${@:2}
    ;;
  "unset")
    unset_nat ${@:2}
    ;;
esac
