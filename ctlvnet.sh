#!/bin/bash
cd "$(dirname $0)"
source modules/check.sh

function ctlvnet_install()
{
  ctlv_mod_install $@
}


function  ctlvnet_exec()
{
	ctlv_set_SUDO
	if [ "$2" == "" ]
	then
		$SUDO docker exec -it $1 bash
	else
		$SUDO docker exec -it $@
  fi
}


function	printhelp()
{
  SUBCMD=$1
  case $1 in
    "install")
      source mkimage.sh
      printsubhelp
      ;;
  esac
}


function  ctlvnet_main()
{
	if [ "$1" == "" ] || [ "$1" == "help" ]
	then
		printhelp $2

		exit -1
	fi

	SUBCMD=$1

	case "$SUBCMD" in
		"exec")
			if [ "$2" == "" ]
			then
				printhelp $SUBCMD

				exit -1
			fi

			ctlvnet_exec ${@:2}
			;;
		"install")
      source mkimage.sh
      ctlvnet_install ${@:2}
			;;
		*)
			printhelp

			exit -1
			;;
	esac
}

ctlvnet_main $@
