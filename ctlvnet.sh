#!/bin/bash
cd "$(dirname $0)"
source modules/check.sh

function	printhelp()
{
  CMD="$0"
  SUBCMD="$1"
  if [ "$SUBCMD" != "" ]
  then
    CMD="$CMD $SUBCMD"
  fi

  case $1 in
    "install")
      source mkimage.sh
      printsubhelp
      ;;
    "create")
      source mkcontainer.sh
      printsubhelp
      ;;
    *)
      echo $CMD
      ;;
  esac
}


function  ctlvnet_exec()
{
  if [ "$1" == "" ]
  then
    printhelp $SUBCMD

    exit -1
  fi

	ctlv_set_SUDO
	if [ "$2" == "" ]
	then
		$SUDO docker exec -it $1 bash
	else
		$SUDO docker exec -it $@
  fi
}

function  ctlvnet_list()
{
  ctlv_set_SUDO
  $SUDO docker images
}


function  ctlvnet_save()
{
  if [ "$1" == "" ]
  then
    printhelp $SUBCMD

    exit -1
  fi

  ctlv_set_SUDO
  INAME=$($SUDO docker ps -f "name=$1" --format '{{.Image}}')
  $SUDO docker commit $1 $INAME
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
			ctlvnet_exec ${@:2}
			;;
		"save")
			ctlvnet_save ${@:2}
			;;
		"list")
			ctlvnet_list ${@:2}
			;;
		"install")
      source mkimage.sh
      ctlv_mod_install ${@:2}
			;;
    "create")
      source mkcontainer.sh
      ctlv_mod_mkcontainer ${@:2}
      ;;
    "delete")
      source rmcontainer.sh
      ctlv_mod_rmcontainer ${@:2}
      ;;
		*)
			printhelp

			exit -1
			;;
	esac
}

CMD="$0"
SUBCMD="$1"
if [ "$SUBCMD" != "" ]
then
  CMD="$CMD $SUBCMD"
fi

ctlvnet_main $@
