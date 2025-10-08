#!/usr/bin/bash

CONNECTION=$1
ACTION=$2

if [[ "$ACTION" == "on" ]]; then
	nmcli connection modify "$CONNECTION" ipv4.ignore-auto-dns yes
	nmcli connection modify "$CONNECTION" ipv4.dns "94.140.14.14 94.140.15.15"
	nmcli connection modify "$CONNECTION" ipv6.ignore-auto-dns yes
	nmcli connection modify "$CONNECTION" ipv6.dns "2a10:50c0::ad1:ff 2a10:50c0::ad2:ff"
	nmcli connection down "$CONNECTION" && nmcli connection up "$CONNECTION"
elif [[ "$ACTION" == "off" ]]; then
	nmcli connection modify "$CONNECTION" ipv4.ignore-auto-dns no
	nmcli connection modify "$CONNECTION" ipv6.ignore-auto-dns no
	nmcli connection down "$CONNECTION" && nmcli connection up "$CONNECTION"
fi
