#!/bin/bash
set -e

function ctlv_set_SUDO()
{
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
}

function ctlv_check_systemctl()
{
	if ! systemctl --no-pager > /dev/null 2>&1
	then
		echo "Systemd seems not to be runnnig."
		if [ "$(uname -a | grep -i Microsoft)" != "" ]
		then
			echo "If you use wsl, you should install and execute 'genie'."
		fi

		exit -1
	fi
}

function ctlv_check_commands()
{
	for CMD in "$@"
	do
		if ! which $CMD > /dev/null
		then
			echo -e "You seem not to have '$CMD' command. Exit.." >&2
			exit -1
		fi
  done
}
