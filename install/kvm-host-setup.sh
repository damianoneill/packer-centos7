#!/bin/bash
# ---------------------------------------------------------------------------
# kvm-host-setup.sh - to configure a server as a kvm host

# Copyright 2016, Damian ONeill <doneill@juniper.net>
# All rights reserved.

# Usage: kvm-host-setup.sh [-h|--help] [-n] [-k] [-d]

# Revision history:
# 2016-08-17 Initial version.
# ---------------------------------------------------------------------------

PROGNAME=${0##*/}
VERSION="0.1"

# best guess at values
STATIC_IP=`hostname -I | cut -d ' ' -f1`
NIN=eth0
GATEWAY_IP=`ip route | awk '/default/ { print $3 }'`
DNS_IP=
DNS_DOMAIN=
NETMASK="255.255.255.0"
HOSTNAME=`hostname -f`

clean_up() { # Perform pre-exit housekeeping
  return
}

error_exit() {
  echo -e "${PROGNAME}: ${1:-"Unknown Error"}" >&2
  clean_up
  exit 1
}

graceful_exit() {
  clean_up
  exit
}

signal_exit() { # Handle trapped signals
  case $1 in
    INT)
      error_exit "Program interrupted by user" ;;
    TERM)
      echo -e "\n$PROGNAME: Program terminated" >&2
      graceful_exit ;;
    *)
      error_exit "$PROGNAME: Terminating on unknown signal" ;;
  esac
}

usage() {
  echo -e "Usage: $PROGNAME [-h|--help] [-n] [-k] [-d]"
}

help_message() {
  cat <<- _EOF_
  $PROGNAME ver. $VERSION
  To configure a server as a kvm host

  $(usage)

  Options:
  -h, --help  Display this help message and exit.
  -n  to configure the network settings
  -k  to install the kvm software
  -d  to check dns (requires bind-utils installed)

  NOTE: You must be the superuser to run this script.

_EOF_
  return
}

valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

collect_network_values()
{

	read -e -i "$HOSTNAME" -p "Enter the name for your host: " input
  HOSTNAME="${input:-$HOSTNAME}"
  read -e -i "$STATIC_IP" -p "Enter the ip address for your host: " input
  STATIC_IP="${input:-$STATIC_IP}"
  if ! valid_ip $STATIC_IP; then echo "invalid ip: $STATIC_IP, exiting" && exit 1; fi
	read -e -i "$NETMASK" -p "Enter the netmask for your network: " input
	NETMASK="${input:-$NETMASK}"

	read -e -i "$GATEWAY_IP" -p "Enter the IP of your gateway: " input
	GATEWAY_IP="${input:-$GATEWAY_IP}"
	if ! valid_ip $GATEWAY_IP; then echo "invalid ip: $GATEWAY_IP, exiting" && exit 1; fi

	read -e -i "$DNS_IP" -p "Enter the IP of your DNS server: " input
	DNS_IP="${input:-$DNS_IP}"
	if ! valid_ip $DNS_IP; then echo "invalid ip: $DNS_IP, exiting" && exit 1; fi
	read -e -i "$DNS_DOMAIN" -p "Enter the domain: " input
	DNS_DOMAIN="${input:-$DNS_DOMAIN}"

	read -e -i "$NIN" -p "Enter the network interface name of your connection (for e.g. enp0s25, eth0, etc.): " input
  NIN="${input:-$NIN}"

}

ask() {
    local prompt default REPLY
    while true; do
        if [ "${2:-}" = "Y" ]; then
            prompt="Y/n"
            default=Y
        elif [ "${2:-}" = "N" ]; then
            prompt="y/N"
            default=N
        else
            prompt="y/n"
            default=
        fi

        echo -n "$1 [$prompt] "

        read REPLY </dev/tty

        if [ -z "$REPLY" ]; then
            REPLY=$default
        fi


        case "$REPLY" in
            Y*|y*) return 0 ;;
            N*|n*) return 1 ;;
        esac

    done
}


write_interface_files()
{

	if ask "Write the config files?"; then
		cp /etc/sysconfig/network-scripts/ifcfg-$NIN /etc/sysconfig/network-scripts/ifcfg-$NIN.`date --iso-8601=seconds`

cat << EOF > /etc/sysconfig/network-scripts/ifcfg-$NIN
DEVICE=$NIN
ONBOOT=yes
BOOTPROTO=none
TYPE=Ethernet
IPV6INIT=no
USERCTL=no
BRIDGE=br0
NM_CONTROLLED=no
EOF

cat << EOFBR > /etc/sysconfig/network-scripts/ifcfg-br0
DEVICE=br0
TYPE=Bridge
DELAY=0
NM_CONTROLLED=no
BOOTPROTO=none
GATEWAY=$GATEWAY_IP
IPADDR=$STATIC_IP
NETMASK=$NETMASK
PEERDNS=yes
IPV6INIT=no
DNS1=$DNS_IP
DOMAIN=$DNS_DOMAIN
ONBOOT=yes
EOFBR

		echo "Two files updated: "
		echo " "
		echo "  /etc/sysconfig/network-scripts/ifcfg-$NIN"
		echo "  /etc/sysconfig/network-scripts/ifcfg-br0"
		echo " "
		echo "net.ipv4.ip_forward = 1" | tee /etc/sysctl.d/99-ipforward.conf > /dev/null 2>&1
		sysctl -p /etc/sysctl.d/99-ipforward.conf > /dev/null 2>&1

    hostnamectl set-hostname $HOSTNAME.$DOMAIN > /dev/null 2>&1

  fi
}


network_settings() {
	echo -e "Configuring a Linux Bridge and the working interface"
	if [ -x "$(command -v brctl)" ]; then
		collect_network_values
		write_interface_files
		if ask "Restart networking?"; then
			systemctl restart network.service
		fi
	else
		error_exit "brctl is missing, run yum install bridge-utils"
  fi
}

check_dns() {
	if [ -x "$(command -v host)" ]; then
		reverseDNS=$(host 8.8.8.8)
		if [ $? != 0 ]; then
		  error_exit "Reverse DNS [FAILED]"
		fi

	  nslookup=$(nslookup google.com)
		if [ "$nslookup" = ";; connection timed out; no servers could be reached" ]; then
			error_exit "nslookup [FAILED]"
	  fi
	else
		error_exit "host command not available, run yum install bind-utils"
  fi
	echo "DNS working ok"
}

kvm_install() {
	echo -e "Installing the KVM software"
	yum -y install qemu-kvm qemu-img net-tools bridge-utils
  yum -y install libvirt virt-install libvirt-client libguestfs-tools virt-top
  systemctl enable libvirtd && systemctl start libvirtd
}

# Trap signals
trap "signal_exit TERM" TERM HUP
trap "signal_exit INT"  INT

# Check for root UID
if [[ $(id -u) != 0 ]]; then
  error_exit "You must be the superuser to run this script."
fi

# Parse command-line
while [[ -n $1 ]]; do
  case $1 in
    -h | --help)
      help_message; graceful_exit ;;
    -n)
      network_settings ;;
		-d)
			check_dns ;;
    -k)
      kvm_install ;;
    -* | --*)
      usage
      error_exit "Unknown option $1" ;;
    *)
      echo "Argument $1 to process..." ;;
  esac
  shift
done

# Main logic

graceful_exit
