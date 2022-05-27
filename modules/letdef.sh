#!/bin/bash
[ -z $CTLV_MODF_CHECK ] && CTLV_MODF_CHECK=true || return

CTLV_SYSNETSET='
$SUDO sysctl -w net.ipv4.ip_forward=1 > /dev/null
$SUDO sysctl -w net.ipv6.conf.all.forwarding=1 > /dev/null
$SUDO sysctl -w net.ipv4.tcp_l3mdev_accept=1 > /dev/null
$SUDO sysctl -w net.ipv4.udp_l3mdev_accept=1 > /dev/null
$SUDO sysctl -w net.ipv4.conf.default.rp_filter=0 > /dev/null
$SUDO sysctl -w net.ipv4.conf.all.rp_filter=0 > /dev/null
$SUDO sysctl -w net.bridge.bridge-nf-call-iptables=0 > /dev/null
$SUDO sysctl -w net.ipv6.conf.all.disable_ipv6=0 > /dev/null
$SUDO sysctl -w net.ipv6.conf.default.disable_ipv6=0 > /dev/null
'

CTLV_SYSNETGET='
$SUDO sysctl net.ipv4.ip_forward
$SUDO sysctl net.ipv6.conf.all.forwarding
$SUDO sysctl net.ipv4.tcp_l3mdev_accept
$SUDO sysctl net.ipv4.udp_l3mdev_accept
$SUDO sysctl net.ipv4.conf.default.rp_filter
$SUDO sysctl net.ipv4.conf.all.rp_filter
$SUDO sysctl net.bridge.bridge-nf-call-iptables
$SUDO sysctl net.ipv6.conf.all.disable_ipv6
$SUDO sysctl net.ipv6.conf.default.disable_ipv6
'
