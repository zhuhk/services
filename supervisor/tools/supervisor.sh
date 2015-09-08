#!/bin/bash

WorkDir=$(cd -P $(dirname $BASH_SOURCE) && cd .. && pwd)
coreDumpDir=""
source $WorkDir/tools/func.sh
cnt=0
g_autocmd_cnt=0
stop_flag=0
trap "sig_usr1" SIGUSR1

cd $WorkDir
while [ $stop_flag -eq 0 ]; do
  source $WorkDir/conf/supervisor.conf

  if [ -f $WorkDir/supervisor.stop ];then
    rcnt=0
  else
    rcnt=$cnt
  fi
  for((i=0; i<rcnt; i++)){
    svr="${g_svr[$i]}"
    ctl=${g_ctl[$i]}
    if [ $(ps aux|grep -E "$svr"|grep -v grep -c) -eq 0 ];then
      echo "$svr down, try to restart it. time:$(date +%Y%m%d_%T)"
      if $ctl restart;then
        log_info "$svr auto restart succesfully."
      else
        log_warn "$svr auto restart failed."
      fi
    fi
  }
  Sleep 5
  if [ -n "$coreDumpDir" ] && [ -d $coreDumpdir ];then
    ls -t $coreDumpDir 2>/dev/null|awk '{if(NR>20) print $0;}' |
    while read f;do
      log_info "del $f"
      rm -f $coreDumpDir/$f
    done
  fi
  for f in $(ls $WorkDir/log/run.*.log);do
    declare -i fsize=$(get_filesize "$f")
    if [ "$fsize" -gt $((800*1024*1024)) ];then
      >$f
      log_info "truncate $f"
    fi
  done
  for((i=0;i<g_autoTruncCnt;i++)){
    dir=${g_autoTrunc[$i]}
    for f in $(ls $dir);do
      declare -i fsize=$(get_filesize "$f")
      if [ "$fsize" -gt $((800*1024*1024)) ];then
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
