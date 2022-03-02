#!/bin/bash
LANG=C

function printstat()
{
  MSG="$(tail -n 1 $1 | tr -d '\r' )"
  echo "$MSG" >&2
  echo "$MSG" | cut -d ' ' -f 1
}

function pingtest()
{
  if [ "$1" == "" ] #! ping $1 -c 1 -i 0.01 -q > /dev/null
  then
    exit 2
  fi

  LOG=$2
  if ! echo -n > $2
  then
    exit 3
  fi

  CSV=$3
  if ! echo -n > $3
  then
    CSV=/dev/null
  fi
  
  SUCNUM=0
  TOTALNUM=0

  ping $1 -i 0.01 -W 0.01 -q 2> $LOG &
  PINGPID=$!
  STARTTIME=$(date +%s.%N)
  sleep 1
  while { sleep 1 & } && SLEEPPID=$! && kill -SIGQUIT $PINGPID 2> /dev/null
  do
    STAT=$(printstat $LOG)
    OLDTOTALNUM=$TOTALNUM
    TOTALNUM=$(echo $STAT | cut -d '/' -f 2)

    RATE=""
    if [ $TOTALNUM != $OLDTOTALNUM ]
    then
      OLDSUCNUM=$SUCNUM
      SUCNUM=$(echo $STAT | cut -d '/' -f 1)
      RATE=$(( ( $SUCNUM - $OLDSUCNUM ) * 100 / ( $TOTALNUM - $OLDTOTALNUM ) ))
    fi
    echo "(RATE in SECCOND) $RATE %"
    TIMER=$( echo "$(date +%s.%N) - $STARTTIME" | bc )
    echo "$TIMER,$RATE" >> $CSV
    wait $SLEEPPID 2> /dev/null
  done
}


function printhelp()
{
  echo "usage: $0 [Destination] ([LOGFILE]) ([CSVFILE])" >&2
}

if [ $# == 0 ]
then
  printhelp
  exit 1
fi

LOG=a.log
if [ "$2" != "" ]
then
  LOG=$2
fi

CSV=a.csv
if [ "$3" != "" ]
then
  CSV=$3
fi

pingtest $1 $LOG $CSV
