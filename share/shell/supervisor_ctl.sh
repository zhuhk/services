#! /bin/bash
CurDir=$(cd $(dirname $BASH_SOURCE) && pwd)
WorkDir=$(cd $CurDir/.. && pwd)
source $WorkDir/tools/func.sh

PsName=$WorkDir/tools/supervisor.sh
chmod +x $PsName
ctlhelp() {
  echo "usage: $0 <start | stop | restart | start-all | stop-all | restart-all | stop-flag>"
  exit 1
}
stopsub(){
  source $WorkDir/conf/supervisor.conf
  for((i=0;i<cnt;i++)){
    ctl=${g_ctl[$i]}
    log_info "try to run $ctl"
    $ctl stop
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
  ctlstart
elif [ "$1" == "stop-all" ];then
  >$WorkDir/supervisor.stop
  ctlstop
  stopsub
elif [ "$1" == "restart-all" ];then
  rm -f $WorkDir/supervisor.stop
  ctlstop
  stopsub
  ctlstart
elif [ "$1" == "stop-flag" ];then
  >$WorkDir/supervisor.stop
else
  ctlhelp
fi
