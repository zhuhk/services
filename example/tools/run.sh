#!/bin/bash

WorkDir=$(cd $(dirname $BASH_SOURCE) && cd .. && pwd)
source $WorkDir/tools/func.sh

stop_flag=0
trap "sig_usr1" SIGUSR1

while [ $stop_flag -eq 0 ];do
  Sleep 100
done

