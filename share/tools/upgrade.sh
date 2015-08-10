#!/bin/bash

WorkDir=$(cd $(dirname $BASH_SOURCE) && cd .. && pwd)
source $WorkDir/tools/func.sh

update_Worker(){
  if [ -f deploy/meta.sh ];then
    source deploy/meta.sh
  fi
  dir=bin
  fname=AlgoServerMain
  update_deploy

  ls deploy|grep -Ev "bin|meta.sh"|xargs -I '{}' cp -rf deploy/'{}' ./
  rm -f meta.sh
}

# cmd paras:
#  - ver: latest | $dstr
# var defined in .upgraderc or conf/env.sh, .upgraderc with higher priority
#  - rsync_prefix
#  - service
update_main "$@"
