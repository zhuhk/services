#!/bin/bash

usage(){
  echo "Usage: $0 <start|stop|restart>"
  return 0

}
if [ $# -eq 0 ];then
  usage
  exit 0
fi

SHELL_DIR=$(cd $(dirname $BASH_SOURCE) && pwd)
WORK_DIR=$(cd $SHELL_DIR/.. && pwd)
source $WORK_DIR/tools/func.sh
cd $WORK_DIR

REDIS_SERVER_BIN=$WORK_DIR/bin/redis-server
REDIS_CLI_BIN=$WORK_DIR/bin/redis-cli

getRedisPort(){
  if [ -f conf/redis.conf ];then
    grep -v "^#" conf/redis.conf|grep port|awk '{print $2}'
  else
    echo "6379"
  fi
}

isRunning(){
  port=$(getRedisPort)
  if [ $(ps axu|grep redis-server |grep -v grep |grep ":$port" -c) -gt 0 ];then
    return 0
  else
    return 1
  fi
}

start(){
  if isRunning;then
    echo "already running, don't start"
    return 1
  fi
  if [ -f conf/redis.conf ];then
    sed -e "s#^dir\s\+/.*#dir $WORK_DIR/data#"  \
        -e "s#^pidfile\s\+/.*#pidfile $WORK_DIR/run/redis.pid#" \
      conf/redis.conf >tmp_redis.conf
  fi
  mkdir -p run log conf
  if is_diff tmp_redis.conf conf/redis.conf;then
    mv tmp_redis.conf conf/redis.conf
  else
    rm -f tmp_redis.conf
  fi
  $REDIS_SERVER_BIN $WORK_DIR/conf/redis.conf >&log/run.redis.log </dev/null &
  sleep 1
  if isRunning;then
    echo "start successfully"
    return 0
  fi
  echo "start fail"
  return 2
}

stop(){ 
  port=$(getRedisPort)
  $REDIS_CLI_BIN -p $port shutdown
  waitCnt=0
  while  [ $waitCnt -lt 10 ]; do
    if isRunning;then
      echo "still running, wait 1s, waitCnt=$waitCnt"
      sleep 1
    fi
    echo "stop successfully"
    return 0
  done
  return 1
}

if [ "$1" == "start" ];then
  start
elif [ "$1" == "stop" ];then
  stop
elif [ "$1" == "restart" ];then
  stop && start
fi
