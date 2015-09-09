#!/bin/bash

dstr=$(date +%Y%m%d_%H%M%S)

# update_main <ver>
update_main(){
  ver="$1"
  if [ -z "$ver" ];then
    echo "Usage: $0 <latest|version>"
    exit 1
  fi

  if [ -z "$WorkDir" ];then
    echo "WorkDir is undefined"
    exit 1
  fi
  if [ $(type -t update_Worker) != "function" ];then
    echo "update is undefined"
    exit 1
  fi
  cd $WorkDir

  log_info "ver=$ver"
  if [ -f conf/env.sh ];then
    source conf/env.sh
  fi
  if [ -f .envrc ];then
    source .envrc
  fi

  if [ "$ver" == "latest" ];then
    if [ -z "$rsync_src" ];then
      log_warn "rsync_src=$rsync_src"
      exit 1
    fi
    if ! update_rsync;then
      log_warn "update_rsync failed"
      exit 1
    fi
    if isUpdateChange;then
      log_warn "conf/env.sh tools/{func.sh,upgrade.sh} changed. try to rerun"
      cp -rf deploy/{tools,conf} ./
      source $0
    fi
    rm -f deploy/meta.sh
    if ! update_Worker;then
      log_warn "update_Worker failed"
      exit 1
    fi
    if ! update_save; then
      log_warn "update_save failed"
      exit 1
    fi
    log_info "upgrade to latest success"
    exit 0
  else
    if [ ! -d deployHist/$ver ];then
      log_warn "deploy $ver not found"
      exit 1
    fi
    mkdir -p deploy
    cp -rf deployHist/$ver/* deploy/
    if isUpdateChange;then
      log_warn "conf/env.sh tools/{func.sh,upgrade.sh} changed. try to rerun"
      cp -rf deploy/{tools,conf} ./
      source $0
    fi
    if ! update_Worker;then
      log_warn "update_Worker failed"
      exit 1
    fi
    log_info "rollback to hist $ver success"
    exit 0
  fi
}
isUpdateChange(){
  if is_diff deploy/conf/env.sh conf/env.sh;then
    log_info "env.sh change"
    return 0
  fi
  if is_diff deploy/tools/func.sh tools/func.sh;then
    log_info "func.sh change"
    return 0
  fi
  if is_diff deploy/tools/upgrade.sh tools/upgrade.sh;then
    log_info "upgrade.sh change"
    return 0
  fi
  return 1
}
#input: dir fname
update_deploy(){
  if [ -z "$version" ];then
    version=$dstr
  fi
  if [ -f deploy/$dir/$fname ] && is_diff $dir/$fname deploy/$dir/$fname ;then
    logex 2 "[INFO]" "update $fname -> pool/$fname.$version"
    mkdir -p $dir/pool
    cp deploy/$dir/$fname $dir/pool/$fname.$version
    cd $dir
    ln -sf pool/$fname.$version $fname
    cd - >&/dev/null
    ls $dir/pool/$fname.*|sort -r|awk '{if(NR>10) print $0}' |xargs rm -f
  fi
}

update_rsync(){
  if [ -z "$rsync_src" ];then
    logex 2 "[WARN]" "rsync failed. svr:$rsync_src"
    return 1
  fi

  rsync -ar --delete $rsync_src/ deploy
  if [ $? -ne 0 ];then
    logex 2 "[WARN]" "rsync failed. svr:$rsync_src"
    return 1
  fi

  return 0
}

update_save(){
  if [ -z "$version" ];then
    version=$dstr
  fi
  metaFile=deployHist/$version/meta.sh
  rm -rf deployHist/$version
  mkdir -p deployHist/$version
  cp -rf deploy deployHist/$version/
  ls deployHist/|sort -r|awk '{if(NR>10) print $0}' |xargs -I '{}' rm -rf deployHist/'{}'
  echo "dstr=$dstr" >$metaFile
  echo "version=$version" >$metaFile
}

get_ipList(){
  local ip=$(ifconfig |grep -o "inet addr:[0-9.]*"|cut -d ":" -f 2|grep -v "^127")
  echo $ip
}
get_svrid(){
  local ip=$(get_ipList)

  id=$(awk -v ip="$ip" -v WorkDir="$WorkDir" 'BEGIN{
     nf = split(ip,arr);
     for(i=1;i<=nf;i++){
       dict[arr[i]] = 1;
     }
     id_ipMatch=id_fullMatch="";
   }{
     dirExist=0;
     dirMatch=0;
     ipMatch=0;
     if($1 ~ /#/ || NF<2) next;
     for(i=2;i<=NF;i++){
       if($i ~ /dir=/){
         dirExist=1;
         split($i,dir_name,"=");
         if(WorkDir ~ dir_name[2]){
            dirMatch=1;
         }
       }
       else{
         if($i in dict){
           ipMatch=1;
         } else {
           for(ip in dict){
             if(index(ip,$i)==1){
               ipMatch=1
               break
             }
           }
         }
       }
     }
     if((ipMatch==1) && (dirExist==0)){
       id_ipMatch=$1;
     }
     if((ipMatch==1) && (dirMatch==1)){
       id_fullMatch=$1;
     }
   }END{
     if(id_fullMatch != ""){
       print id_fullMatch;
     }else if(id_ipMatch != ""){
       print id_ipMatch;
     }
  }' $1)
  shard=${id%_*}
  replica=${id#*_}
  return 0
}

Wait(){
  while ! wait ;do
    ((i++))
    log_info $i
  done
}

get_workroot(){
  echo $(cd $(dirname $BASH_SOURCE) && cd .. && pwd)
  return 0
}

abs_path(){
  eval local dir="$1"
  local fakeadd=0
  if [ -d "$dir" ] || [ $(echo "${dir}"|grep -E "/\.\.$|/\.$|/$|^\.\.$|^\.$" -c) -gt 0 ];then
    dir="$dir/file"
    fakeadd=1
  fi
  dir=`dirname $dir`
  dir=$(mkdir -p $dir && cd $dir>&/dev/null && pwd)
  if [ $fakeadd -eq 0 ];then
    dir=$dir/$(basename $1)
  fi
  echo $dir
  return 0
}

lines(){
  if [[ -f "$1" ]];then
    cat "$1" |wc -l
  else
    echo 0
  fi
  return 0
}
sum(){
  local col=2
  if [[ $# -ge 2 ]];then
    col=$2
  fi

  if [[ -f "$1" ]];then
    awk -v col=$col '{if(NF>=col)sum+=$col;}END{print sum}' $1
  else
    echo 0
  fi
  return 0
}
get_filesize(){
  declare -i size=`[ -f "$1" ] && ls -s --block-size=1 "$1"|awk -F " " '{print $1;}'`
  echo $size
  return 0
}

echo_subpids(){
  local pids=""
  for pid in $@;do
    pids="$pids $(pstree -p $pid|grep -Eo '([0-9]+)')"
  done
  echo $pids
}

get_subpids(){
  pids=""
  for pid in $@;do 
    pids="$pids $(pstree -p $pid|grep -Eo '([0-9]+)')"
  done
  pids=$(echo $pids)
}
get_pids(){
  pids=""
  _pids=$(ps axu|grep "$PsName"| grep -v grep |awk '{print $2}')
  if [ "$ign_subpids" == 1 ];then
    pids=$(echo $_pids)
    return 0
  fi
  for pid in $_pids;do 
    pids="$pids $(pstree -p $pid|grep -Eo '([0-9]+)')"
  done
  pids=$(echo $pids)
}

isRunning(){
  get_pids
  if [ -z "$pids" ];then
    return 1
  fi
  return 0
}

ctlhelp(){
  echo "Usage: $0 <start|stop|restart>"
  return 0
}

ctlstart(){
  if [ -z "$ctlstartcmd" ];then
    ctlstartcmd=$PsName
  fi
  if isRunning;then
    logex 3 "[INFO]" "already running, quit"
    return 0
  fi
  mkdir -p $WorkDir/log
  local fname=$(basename ${PsName%.*})
  echoex 3 "ctlstartcmd='$ctlstartcmd'" >>$WorkDir/log/run.$fname.log
  $ctlstartcmd >>$WorkDir/log/run.$fname.log 2>>$WorkDir/log/run.$fname.err </dev/null &

  sleep 2
  if isRunning; then
    logex 3 "[INFO]" "start successfully"
    return 0
  else
    logex 3 "[INFO]" "start failed"
    return 1
  fi
}

ctlstop(){
  if [ -z "$ctlstopcmd" ];then
    ctlstopcmd="kill -s USR1"
  fi
  waitSeconds=0
  while isRunning;do
    if [ $waitSeconds -gt 30 ];then
      logex 3 "[INFO]" "stop failed"
      return 1
    elif [ $waitSeconds -gt 20 ];then
      logex 3 "[INFO]" "gracefully stop failed. try to force stop"
      kill -9 $pids
    else
      if [ $waitSeconds -gt 0 ];then
        logex 3 "[INFO]" "still running, try to stop again. pids=$pids"
      fi
      eval $ctlstopcmd $pids
    fi
    sleep 1
    ((waitSeconds++))
  done
  logex 3 "[INFO]" "stop successfully"
  return 0
}

ctlmain(){
  if [ -n "$WorkDir" ];then
    cd $WorkDir
  fi
  if [ "$1" == "start" ];then
    ctlstart
  elif [ "$1" == "stop" ];then
    ctlstop
  elif [ "$1" == "restart" ];then
    ctlstop && ctlstart
  else
    ctlhelp
    exit 1
  fi
}

sig_usr1(){
  stop_flag=1
}
sigsub_usr1(){
  sig_usr1
  ((stopretry_cnt++))
  if [ "$stopretry_cnt" -gt 5 ] && [ -n "$subpid" ];then
    kill -9 $subpid
  fi
}

Sleep(){
  sleep $1
  return 0
  if [ -z "$1" ];then
    sleep 1
    return 0
  fi
  if expr "$1" "<=" 1 >&/dev/null;then
    sleep $1
    return 0
  fi
  for((i=1;i<$1 && stop_flag==0;i++)){
    sleep 1
  }
}

init_log(){
  if [[ "$debug" -eq 1 ]];then
    g_LogFile=""
    return 0
  fi
  local fname
  if [ $# -ge 1 ];then
    LogDir=`abs_path $1`
  fi
  if [ $# -ge 2 ];then
    fname="$2"
  else
    fname=${0##*/}
  fi
  mkdir -p $LogDir
  g_LogFile=$LogDir/$fname.log
  g_ErrFile=$LogDir/$fname.err
  declare -i filesize=`get_filesize "$g_LogFile"`
  if [ $filesize -gt $((1000*1024*1024)) ];then
    >$g_LogFile
  fi
  filesize=`get_filesize "$g_ErrFile"`
  if [ $filesize -gt $((1000*1024*1024)) ];then
    >$g_LogFile.err
  fi
  exec 1>>$g_LogFile  2>>$g_ErrFile
  set -x
  return 0
}

log(){
  #read -r SUB_PID _ < /proc/self/stat
  SUB_PID=`sh -c 'echo $PPID'`
  if [ -n "$g_LogFile" ];then
    declare -i filesize=`get_filesize "$g_LogFile"`
    if [ $filesize -gt $((1000*1024*1024)) ];then
      >$g_LogFile
    fi
    echo -e `date "+%Y-%m-%d %H:%M:%S"`" $SUB_PID - $@" >>$g_LogFile
  else
    echo -e `date "+%Y-%m-%d %H:%M:%S"`" $SUB_PID - $@"  >&2
  fi
}
echoex(){
  local lv
  lv="$1"
  shift
  if [ $lv -ge ${#BASH_SOURCE[@]} ];then
    lv=${#BASH_SOURCE[@]}-1
  fi
  SUB_PID=`sh -c 'echo $PPID'`
  local envinfo
  envinfo="(${BASH_SOURCE[$lv]##*/}:${BASH_LINENO[$((lv-1))]},${FUNCNAME[$lv]})"
  echo -e `date "+%Y-%m-%d %H:%M:%S"`" $SUB_PID - ${envinfo} $@"
}
#logex <level> <info>
logex(){
  local lv
  lv="$1"
  shift
  severity="$1"
  if [ $lv -ge ${#BASH_SOURCE[@]} ];then
    lv=${#BASH_SOURCE[@]}-1
  fi
  SUB_PID=`sh -c 'echo $PPID'`
  local envinfo
  envinfo="(${BASH_SOURCE[$lv]##*/}:${BASH_LINENO[$((lv-1))]},${FUNCNAME[$lv]})"
  if [ -n "$g_LogFile" ];then
    if [ "$severity" != "[INFO]" ];then
      declare -i filesize=`get_filesize "$g_ErrFile"`
      if [ $filesize -gt $((1000*1024*1024)) ];then
        >$g_ErrFile
      fi
      echo -e `date "+%Y-%m-%d %H:%M:%S"`" $SUB_PID - ${envinfo} $@" >>$g_ErrFile
    fi
    declare -i filesize=`get_filesize "$g_LogFile"`
    if [ $filesize -gt $((1000*1024*1024)) ];then
      >$g_LogFile
    fi
    echo -e `date "+%Y-%m-%d %H:%M:%S"`" $SUB_PID - ${envinfo} $@" >>$g_LogFile
  else
    if [ "$severity" != "[INFO]" ];then
      echo -e `date "+%Y-%m-%d %H:%M:%S"`" $SUB_PID - ${envinfo} $@" >&2
    else
      echo -e `date "+%Y-%m-%d %H:%M:%S"`" $SUB_PID - ${envinfo} $@"
    fi
  fi
}
log_info(){
  logex 2 "[INFO]" "$@"
  return $?
}
log_warn(){
  logex 2 "[WARN]" "$@"
  return $?
}
log_fatal(){
  logex 2 "[fatal]" "$@"
  return $?
}
get_ppid(){
  read -r _tmp0 _tmp1 _tmp2 PPID_CURR _tmp4 </proc/self/stat
  return 0
}

#is_diff <file1> <file2>
is_diff(){
  if [ ! -f "$1" ] || [ ! -f "$2" ];then
    return 0;
  fi
  echo "`md5sum $1 |awk -F " " '{print $1;}'`  $2" |md5sum -c >&/dev/null
  if [ $? -eq 0 ];then
    return 1
  else
    return 0
  fi
}

##! @RETURN: 0 => all success; 1 => error occur
check_pipe_status() {
  echo "${PIPESTATUS[*]}" | awk '{ for (i = 1; i <= NF; i++) { if ($i != 0) { exit 1; } } }'
  return $?
}

queryip(){
  if [[ -z "$1" ]];then
    return 0;
  fi
  local isip=`echo "$1"|grep -oE "[0-9]+\.[0-9]+.[0-9]+.[0-9]+$"`
  if [ -n "$isip" ];then
    echo $isip
    return 0
  fi

  host "$1" |tail -1|grep -oE "[0-9]+\.[0-9]+.[0-9]+.[0-9]+$"
  return 0
}

#md5str <string>
md5str(){
  python -c "import hashlib; print hashlib.md5('$1').hexdigest()"
}

#cat | line_md5 
line_md5(){
  if ! python -c "import hashlib,sys;" >&/dev/null;then
    log_warn "try to Run python failed"
    return 1
  fi

  cmd=$(
  echo "import hashlib,sys"
  echo "for line in sys.stdin:"
  echo "  line = line.rstrip();"
  echo "  md5str = hashlib.md5(line).hexdigest();"
  echo "  print '%s\t%s' % (md5str,line);"
  )
  python -c "$cmd"
  return 0
}

#del_hist <dir> <filepattern> <maxNum> <minNum>
del_hist(){
  local f minNum maxNum;
  if [ ! -d "$1" ];then
    return 0;
  fi
  if [[ -n "$3" ]];then
    maxNum=$3
  else
    maxNum=10
  fi
  if [[ -n "$4" ]];then
    minNum=$4
  else
    minNum=$((maxNum/2))
  fi
  if [[ `ls -t "$1"|grep "$2"|awk -v num=$maxNum '{if(NR>num)print $0}'|wc -l` -gt 0 ]];then
    ls -t "$1"|grep "$2"|awk -v num=$minNum '{if(NR>num)print $0}'|
    while read f; do
      log "del $1/$f"
      rm -f $1/$f
    done
  fi
  return 0
}

java_hash_code(){
  local id id_length hash ch
  id="$1"
  id_length=`expr length "$id"`
  hash=0
  for ((i = 0; i < id_length; i++)); do 
    ch=$(printf %d "'${id:i:1}") 
    hash=$(((hash << 5) - hash + ch)) 
  done
  echo $hash
  return 0
}
#hive_hash <string> <string> ...
hive_hash(){
  local i array array_len hash code;
  array=("$@");
  array_len=${#array[@]};
  hash=0
  for((i=0;i<array_len;i++)){
    code=`java_hash_code "${array[$i]}"`
    hash=$((hash*31 + code)) 
  }
  hash=$((hash & 0x7FFFFFFF))
  echo $hash
  return 0
}

hive_pmod(){
  declare -i m=$1 n=$2

  if [[ $# -ne 2 ]] || [[ $n -eq 0 ]];then
    return 1
  fi
  echo $(( ((m%n)+n)%n ))
  return 0
}

#hive_part <str> Num
hive_bucket(){
  declare -i n=$2
  if [[ $# -ne 2 ]] || [[ $n -eq 0 ]];then
    return 1
  fi
  echo $(hive_pmod $(hive_hash "$1") $n)
  return 0
}
retry(){
  local i=0
  if [ -z "$retry_wait" ];then
    retry_wait=10
  fi
  if [ -z "$retry_max" ];then
    retry_max=3
  fi
  for((i=0;i<=retry_max;i++)){
    "$@"
    ret=$?
    if [ $ret -eq 0 ];then
      return 0
    fi
    logex 2 "[INFO]" "ret=$ret retry=$i cmd='$@'"
    sleep $retry_wait
  }
  return 1
}
# charset [gb18030(default)]
charset(){
  locale |awk -F "." -v default="$1" '{if(NF>1){print $NF;exit 0;}}END{if(length(default)>0)print default}'
}

#ftpurl <file>
ftpurl(){
  if [[ ! -f "$1" ]] && [[ ! -d "$1" ]];then
    return 1
  fi

  echo "ftp://$(hostname)$(abs_path $1)"
  return 0
}
#is_running <specStr> <waitSecond> <$1>
is_running(){
  g_PidFile="$(basename ${BASH_SOURCE[1]%.sh})_${FUNCNAME[1]}"
  if [[ -n "$1" ]];then
    g_PidFile="${g_PidFile}_$1"
  fi
  g_PidFile=${g_PidFile}.pid
  declare -i waitSec=$2
  if [[ $waitSec -lt 1 ]];then
    waitSec=1
  fi
  local dir
  dir=`get_workroot`/data/run
  mkdir -p $dir
  declare -i pid=`[ -f "$dir/$g_PidFile" ] && cat $dir/$g_PidFile` 
  declare -i cnt=0
  declare -i self=$$
  while [[ $pid -gt 1 ]] && kill -0 $pid >&/dev/null; do
    if [[ $self -eq $pid ]];then
      return 1
    fi
    if [[ $cnt -ge $waitSec ]];then
      g_PidFile=""
      return 0
    fi
    sleep 1
    ((cnt++))
  done
  echo $$ >$dir/$g_PidFile
  return 1
}
list2schema(){
  echo "$1"|awk -F "[[:blank:],;'\"]"  '{
     for(i=1;i<=NF;i++){
   if(length($i)==0){
       continue;
   }
   if(cnt==0){
       printf(" `%s` string\n",$i);
   }else{
       printf(",`%s` string\n",$i);
   }
   cnt++;
     }
  }'
  return 0
}
list2fields(){
  echo "$1"|awk -F "[[:blank:],;'\"]"  '{
     for(i=1;i<=NF;i++){
   if(length($i)==0){
       continue;
   }
   if(cnt==0){
       printf("`%s`",$i);
   }else{
       printf(",`%s`",$i);
   }
   cnt++;
     }
  }'
  return 0
}
list2var(){
  echo "$1"|awk -F "[[:blank:],;'\"]"  '{
     for(i=1;i<=NF;i++){
   if(length($i)==0){
       continue;
   }
   if(cnt==0){
       printf("\"%s\"",$i);
   }else{
       printf(",\"%s\"",$i);
   }
   cnt++;
     }
  }'
  return 0
}
abs_day(){
  echo $(($(date +%s) / 86400-16000))
  return 0
}
daemon(){
  if [[ -n ${BASH_SOURCE[1]} ]];then
    nohup sh ${BASH_SOURCE[1]} "$@" </dev/null >& nohup.out &
  else
    nohup sh $WORK_ROOT/bin/run.sh "$@" </dev/null >& nohup.out &
  fi
  return 0
}

#logrun <cmd> ...
logrun(){
  local runspec=${BASH_SOURCE[1]##*/}
  runspec=${runspec%.*}
  local cmd=${1}
  if [[ -z "$cmd" ]];then
    logex 2 "[FATAL]" "cmd is empty"
    return 2
  fi
  init_log $WORK_ROOT/log "${runspec}_${cmd}"
  shift
  $cmd "$@"
  ret=$?
  set +x
  return $ret
}
warnrun(){
  local cmd=$1
  shift
  $cmd "$@"
  if [[ $? -ne 0 ]];then
    title="fail to run '$cmd $@'"
    if [[ -n "$g_LogFile" ]] && [[ -f "$g_LogFile" ]];then
      body=`tail -n 20 $g_LogFile`
    else
      body="$title"
    fi  
    send_mail_msg -t 1 -s "${title}$ComSubject" -p "$body"
    send_gsm_msg -t 1 -s "[${title}]$ComGSMSubject"
    return 1
  else
    return 0
  fi  
}

usage(){
  echo "Usage: $0 <ty> ... "
  for((i=0;i<g_usage_off;i++)){
    echo "  ${g_usage_arr[$i]}"
  }
}

main(){
  g_cmd=$1
  shift

  ty=`type -t "$g_cmd"`
  if [ -n "$ty" ];then
    "$g_cmd" "$@"
    ret=$?
  else
    if [[ -n "$g_cmd" ]];then
      echo "ty:'$g_cmd' Not Defined" >&2
    fi
    usage
    ret=0
  fi

  if [ $ret -eq 2 ];then
    usage
  elif [[ $ret -gt 2 ]];then
    log_fatal "ty=$ty ret=$?"
  fi
  exit $ret
}
ssh_run(){
  if [ -z "$g_svrlist" ];then
    log_fatal "g_svrlist is empty"
    return 1
  fi 
  for svr in $g_svrlist; do 
    echo "svr=$svr"
    /usr/bin/ssh $svr "$@"
    echo "================================"
    echo "" 
  done
  return 0
}
_app_func_sh=$(cd $(dirname $BASH_SOURCE) && pwd)/app_func.sh
if [ -f "$_app_func_sh" ];then
  source "$_app_func_sh"
fi
