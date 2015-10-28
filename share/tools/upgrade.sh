#!/bin/bash

WorkDir=$(cd -P $(dirname $BASH_SOURCE) && cd .. && pwd)
source $WorkDir/tools/func.sh

update_Worker(){
  if [ -f deploy/meta.sh ];then
    source deploy/meta.sh
  fi
  dir=bin
  fname=AlgoServerMain
  update_deploy

  # 1. 首先更新so,然后在更新对其有依赖的workflow_config
  # 2. 直接覆盖so文件，当文件名没有变化时，再次执行dlopen
  #    则调用其中的任何函数都会出core
  #    使用soft link则没有问题
  dir=so
  for fname in $(ls deploy/so);do
    update_deploy
  done

  # 更新剩余其它文件，包括workflow_config
  ls deploy|grep -Ev "^bin|meta.sh|so$"|xargs -I '{}' cp -rf deploy/'{}' ./
  rm -f meta.sh
}

# cmd paras:
#  - ver: latest | $dstr
# vars defined in conf/env.sh or .envrc:
#  - rsync_src
update_main "$@"
