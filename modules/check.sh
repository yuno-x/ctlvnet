#!/bin/bash
[ -z $CTLV_MODF_CHECK ] && CTLV_MODF_CHECK=true || return

function prevdup()
{
  if eval [ -z '$'$1 ]
  then
    eval $1=true
    return  0
  fi

  return  1
}

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
