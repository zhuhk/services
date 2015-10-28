#!/bin/bash

WorkDir=$(cd -P $(dirname $BASH_SOURCE) && cd .. && pwd)
coreDumpDir=""
source $WorkDir/tools/func.sh
cnt=0
g_autocmd_cnt=0

# don't use sig_init, because supervisor.sh should be robostest
stop_flag=0
trap "sig_usr1" SIGUSR1

cd $WorkDir
mkdir -p log run
runCnt=0
while [ $stop_flag -eq 0 ]; do
  source $WorkDir/conf/supervisor.conf
  now=$(date +%s)

  if [ -f $WorkDir/supervisor.stop ];then
    rcnt=0
  else
    rcnt=$cnt
  fi
  for((i=0; i<rcnt; i++)){
    svr="${g_svr[$i]}"
    ctl=${g_ctl[$i]}
    minRestartDelay=${g_minRestartDelay[$i]:-0}
    if [ $(ps aux|grep -E "$svr"|grep -v grep -c) -eq 0 ];then
      if [ $minRestartDelay -gt 0 ];then
        afterLastFail=$((now-${lastFail[$i]:-0}))
        if [ $afterLastFail -lt $minRestartDelay ];then
          log_info "$svr down, but need to delay. minRestartDelay=$minRestartDelay afterLastFail=$afterLastFail"
          continue
        fi
        lastFail[$i]=$now
      fi
      log_info "$svr down, try to restart it"
      if $ctl restart;then
        log_info "$svr auto restart succesfully."
      else
        log_warn "$svr auto restart failed."
      fi
    fi
  }
  sleep ${checkInterval:-5}
  ((runCnt++))
  if [ $((runCnt%12)) -ne 11 ];then
    continue
  fi

  find ./run -name "lock.*.sh" -mmin +1 |xargs rm -rf
  if [ -n "$coreDumpDir" ] && [ -d $coreDumpdir ];then
    ls -t $coreDumpDir 2>/dev/null|grep -iE "core\.*"|awk '{if(NR>20) print $0;}' |
    while read f;do
      log_info "del $f"
      rm -f $coreDumpDir/$f
    done
  else
    find ./ -name "core.*" | grep -E "/core.[0-9]+$"|awk '{if(NR>5) print $0}' |xargs rm -f
  fi
  for f in $(ls $WorkDir/log/run.*.{log,err} 2>/dev/null);do
    declare -i fsize=$(get_filesize "$f")
    if [ "$fsize" -gt ${maxFileSize:-$((800*1024*1024))} ];then
      >$f
      log_info "truncate $f"
    fi
  done
  for((i=0;i<g_autoTruncCnt;i++)){
    dir=${g_autoTrunc[$i]}
    for f in $(ls $dir);do
      declare -i fsize=$(get_filesize "$f")
      if [ "$fsize" -gt ${maxFileSize:-$((800*1024*1024))} ];then
        >$f
        log_info "truncate $f"
      fi
    done
  }
  for((i=0;i<g_autocmd_cnt;i++)){
    cmd="${g_autocmds[$i]}"
    eval $cmd
  }
done
