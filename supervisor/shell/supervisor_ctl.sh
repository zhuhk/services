#! /bin/bash
CurDir=$(cd -P $(dirname $BASH_SOURCE) && pwd)
WorkDir=$(cd $CurDir/.. && pwd)
source $WorkDir/tools/func.sh

cd $WorkDir

PsName=$WorkDir/tools/supervisor.sh
ctlhelp() {
  echo "usage: $0 <start | stop | restart | start-all | stop-all | restart-all | stop-flag>"
  exit 1
}

procsub(){
  source $WorkDir/conf/supervisor.conf
  for((i=0;i<cnt;i++)){
    ctl=${g_ctl[$i]}
    log_info "try to run $ctl"

    if [ "$(basename $ctl)" == supervisor_ctl.sh ];then
      $ctl ${1}-all
    else
      $ctl ${1}
    fi
  }
}
ctlstartcmd=$PsName

if [ "$1" == "start" ];then
  ctlstart
elif [ "$1" == "stop" ];then
  ctlstop
elif [ "$1" == "restart" ];then
  ctlstop && ctlstart
elif [ "$1" == "start-all" ];then
  rm -f $WorkDir/supervisor.stop
  procsub start
  ctlstart
elif [ "$1" == "stop-all" ];then
  >$WorkDir/supervisor.stop
  ctlstop
  procsub stop
elif [ "$1" == "restart-all" ];then
  rm -f $WorkDir/supervisor.stop
  ctlstop
  procsub stop
  procsub start
  ctlstart
elif [ "$1" == "stop-flag" ];then
  >$WorkDir/supervisor.stop
else
  ctlhelp
fi
